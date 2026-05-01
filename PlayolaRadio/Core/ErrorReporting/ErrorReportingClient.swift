//
//  ErrorReportingClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/23/26.
//

import Alamofire
import Dependencies
import DependenciesMacros
import Foundation

#if canImport(Sentry)
  import Sentry
#endif

// MARK: - Error Reporting Client Dependency

@DependencyClient
struct ErrorReportingClient: Sendable {
  /// Report an Error to the crash/error reporting backend (Sentry).
  /// Tags are attached to the event for filtering in the Sentry UI.
  var reportError: @Sendable (_ error: Error, _ tags: [String: String]) async -> Void

  /// Report an Error with tags and contextual data to the crash/error reporting backend (Sentry).
  var reportErrorWithContext:
    @Sendable (
      _ error: Error, _ tags: [String: String], _ contextKey: String, _ context: [String: String]
    ) async -> Void

  /// Report a message (non-Error situation) to the crash/error reporting backend.
  /// Tags are attached to the event for filtering in the Sentry UI.
  var reportMessage: @Sendable (_ message: String, _ tags: [String: String]) async -> Void
}

// MARK: - Dependency Registration

extension ErrorReportingClient: TestDependencyKey {
  static let testValue = ErrorReportingClient.noop
}

extension DependencyValues {
  var errorReporting: ErrorReportingClient {
    get { self[ErrorReportingClient.self] }
    set { self[ErrorReportingClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension ErrorReportingClient: DependencyKey {
  static let liveValue = Self(
    reportError: { error, tags in
      #if canImport(Sentry)
        SentrySDK.capture(error: error) { scope in
          for (key, value) in tags {
            scope.setTag(value: value, key: key)
          }
        }
      #endif
    },
    reportErrorWithContext: { error, tags, contextKey, context in
      #if canImport(Sentry)
        SentrySDK.capture(error: error) { scope in
          for (key, value) in tags {
            scope.setTag(value: value, key: key)
          }
          if !context.isEmpty {
            scope.setContext(value: context, key: contextKey)
          }
        }
      #endif
    },
    reportMessage: { message, tags in
      #if canImport(Sentry)
        SentrySDK.capture(message: message) { scope in
          for (key, value) in tags {
            scope.setTag(value: value, key: key)
          }
        }
      #endif
    }
  )
}

// MARK: - Test Implementation

extension ErrorReportingClient {
  static let noop = Self(
    reportError: { _, _ in },
    reportErrorWithContext: { _, _, _, _ in },
    reportMessage: { _, _ in }
  )
}

struct SignInAPIError: Error, LocalizedError {
  let authMethod: AuthMethod
  let endpointPath: String
  let statusCode: Int?
  let responseBody: String?
  let underlyingError: Error

  var errorDescription: String? {
    var description = "Sign-in API exchange failed for \(authMethod.rawValue)"
    if let statusCode {
      description += " with HTTP \(statusCode)"
    }
    description += ": \(underlyingError.localizedDescription)"
    return description
  }
}

enum SignInNetworkErrorClassifier {
  static let networkErrorCodes: Set<Int> = [
    NSURLErrorSecureConnectionFailed,
    NSURLErrorNotConnectedToInternet,
    NSURLErrorTimedOut,
    NSURLErrorCannotConnectToHost,
    NSURLErrorNetworkConnectionLost,
  ]

  static func isNetworkError(_ error: Error) -> Bool {
    nsURLErrorCodes(in: error).contains { networkErrorCodes.contains($0) }
  }

  static func isSecureConnectionFailed(_ error: Error) -> Bool {
    nsURLErrorCodes(in: error).contains(NSURLErrorSecureConnectionFailed)
  }

  private static func nsURLErrorCodes(in error: Error) -> [Int] {
    walkErrors(error).compactMap { $0.domain == NSURLErrorDomain ? $0.code : nil }
  }

  private static func walkErrors(_ error: Error) -> [NSError] {
    var collected: [NSError] = []
    var queue: [Error] = [error]
    var iterations = 0
    while !queue.isEmpty, iterations < 16 {
      let next = queue.removeFirst()
      iterations += 1
      let ns = next as NSError
      collected.append(ns)
      if let afError = next as? AFError, let underlying = afError.underlyingError {
        queue.append(underlying)
      }
      if let signInError = next as? SignInAPIError {
        queue.append(signInError.underlyingError)
      }
      if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
        queue.append(underlying)
      }
      queue.append(contentsOf: ns.underlyingErrors)
    }
    return collected
  }
}

struct SignInErrorReport {
  let contextKey = "sign_in"
  let tags: [String: String]
  let context: [String: String]

  init(error: Error, authMethod: AuthMethod, step: String) {
    var tags = [
      "auth_method": authMethod.rawValue,
      "sign_in_step": step,
    ]
    var context: [String: String] = [:]

    let errorForDomain = (error as? SignInAPIError)?.underlyingError ?? error
    let nsError = errorForDomain as NSError
    tags["error_domain"] = nsError.domain
    tags["error_code"] = "\(nsError.code)"

    if let apiError = error as? SignInAPIError {
      tags["endpoint_path"] = apiError.endpointPath
      if let statusCode = apiError.statusCode {
        tags["http_status_code"] = "\(statusCode)"
      }
      context["endpoint_path"] = apiError.endpointPath
      if let responseBody = apiError.responseBody {
        context["response_body"] = Self.redactedResponseBody(responseBody)
        context["response_body_bytes"] = "\(responseBody.lengthOfBytes(using: .utf8))"
        if let keys = Self.topLevelJSONKeys(responseBody), !keys.isEmpty {
          context["response_body_top_level_keys"] = keys.joined(separator: ",")
        }
      }
    }

    self.tags = tags
    self.context = context
  }

  private static func redactedResponseBody(_ responseBody: String) -> String {
    guard let data = responseBody.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data)
    else {
      return responseBody
    }

    let redacted = redactSensitiveValues(in: json)
    guard JSONSerialization.isValidJSONObject(redacted),
      let redactedData = try? JSONSerialization.data(
        withJSONObject: redacted, options: [.sortedKeys]),
      let redactedString = String(data: redactedData, encoding: .utf8)
    else {
      return responseBody
    }
    return redactedString
  }

  private static func redactSensitiveValues(in value: Any) -> Any {
    if let dictionary = value as? [String: Any] {
      return dictionary.reduce(into: [String: Any]()) { result, item in
        if shouldRedact(key: item.key) {
          result[item.key] = "[REDACTED]"
        } else {
          result[item.key] = redactSensitiveValues(in: item.value)
        }
      }
    }

    if let array = value as? [Any] {
      return array.map { redactSensitiveValues(in: $0) }
    }

    return value
  }

  private static func shouldRedact(key: String) -> Bool {
    let normalizedKey = key.lowercased()
    return normalizedKey.contains("token")
      || normalizedKey == "authcode"
      || normalizedKey == "authorizationcode"
  }

  private static func topLevelJSONKeys(_ responseBody: String) -> [String]? {
    guard let data = responseBody.data(using: .utf8),
      let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    return dictionary.keys.sorted()
  }
}
