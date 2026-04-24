//
//  ErrorReportingClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/23/26.
//

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
    reportMessage: { _, _ in }
  )
}
