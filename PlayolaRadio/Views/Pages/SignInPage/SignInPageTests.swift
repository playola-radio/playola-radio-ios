//
//  SignInPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/22/25.
//

import Alamofire
import AuthenticationServices
import ConcurrencyExtras
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct SignInPageTests {
  @Test
  func testSignInWithAppleCorrectlyAddsScopeToTheAppleSignInRequest() async {
    let request = ASAuthorizationAppleIDRequest(coder: NSCoder())!
    let model = SignInPageModel()
    model.signInWithAppleButtonTapped(request: request)
    #expect(request.requestedScopes == [.email, .fullName])
  }

  @Test
  func testSignInWithAppleTracksSignInStartedEvent() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    await confirmation("Apple sign-in started event tracked") { confirm in
      let model = withDependencies {
        $0.analytics.track = { event in
          capturedEvents.withValue { $0.append(event) }
          if case .signInStarted(let method) = event, method == .apple {
            confirm()
          }
        }
      } operation: {
        SignInPageModel()
      }

      let request = ASAuthorizationAppleIDRequest(coder: NSCoder())!
      model.signInWithAppleButtonTapped(request: request)

      // Yield to let the spawned Task run the analytics callback.
      while !capturedEvents.value.contains(where: {
        if case .signInStarted(let method) = $0 { return method == .apple }
        return false
      }) {
        await Task.yield()
      }
    }

    let hasSignInStartedEvent = capturedEvents.value.contains { event in
      if case .signInStarted(let method) = event {
        return method == .apple
      }
      return false
    }

    #expect(hasSignInStartedEvent, "Should track signInStarted event for Apple")
  }

  @Test
  func testSignInWithGoogleTracksSignInStartedEvent() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let model = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.errorReporting.reportMessage = { _, _ in }
    } operation: {
      SignInPageModel()
    }
    // Avoid invoking the real Google SDK in tests by short-circuiting on no key window.
    model.keyWindowProvider = { nil }

    await model.signInWithGoogleButtonTapped()

    let hasSignInStartedEvent = capturedEvents.value.contains { event in
      if case .signInStarted(let method) = event {
        return method == .google
      }
      return false
    }

    #expect(hasSignInStartedEvent, "Should track signInStarted event for Google")
  }

  // MARK: - signInWithAppleCompleted() Error Reporting Tests

  @Test
  func testSignInWithAppleCompletedReportsErrorOnAuthorizationFailure() async {
    let reportedErrors = LockIsolated<[(Error, [String: String])]>([])

    let model = withDependencies {
      $0.errorReporting.reportErrorWithContext = { error, tags, _, _ in
        reportedErrors.withValue { $0.append((error, tags)) }
      }
    } operation: {
      SignInPageModel()
    }

    let genericError = NSError(domain: "test.domain", code: 42, userInfo: nil)
    await model.signInWithAppleCompleted(result: .failure(genericError))

    #expect(reportedErrors.value.count == 1, "Should call reportError exactly once")
    let tags = reportedErrors.value.first?.1 ?? [:]
    #expect(tags["auth_method"] == "apple")
  }

  @Test
  func testSignInWithAppleCompletedDoesNotReportErrorOnUserCancel() async {
    let reportedErrors = LockIsolated<[(Error, [String: String])]>([])

    let model = withDependencies {
      $0.errorReporting.reportErrorWithContext = { error, tags, _, _ in
        reportedErrors.withValue { $0.append((error, tags)) }
      }
    } operation: {
      SignInPageModel()
    }

    let cancelError = ASAuthorizationError(.canceled)
    await model.signInWithAppleCompleted(result: .failure(cancelError))

    #expect(
      reportedErrors.value.isEmpty,
      "Should not report ASAuthorizationError.canceled (user cancellations are not bugs)")
  }

  // MARK: - presentedAlert Tests

  @Test
  func testSignInWithAppleCompletedPresentsAlertOnAuthorizationFailure() async {
    let model = withDependencies {
      $0.errorReporting.reportErrorWithContext = { _, _, _, _ in }
    } operation: {
      SignInPageModel()
    }

    let genericError = NSError(domain: "test.domain", code: 42, userInfo: nil)
    await model.signInWithAppleCompleted(result: .failure(genericError))

    #expect(model.presentedAlert == .signInError)
  }

  @Test
  func testSignInWithAppleCompletedDoesNotPresentAlertOnUserCancel() async {
    let model = withDependencies {
      $0.errorReporting.reportErrorWithContext = { _, _, _, _ in }
    } operation: {
      SignInPageModel()
    }

    let cancelError = ASAuthorizationError(.canceled)
    await model.signInWithAppleCompleted(result: .failure(cancelError))

    #expect(model.presentedAlert == nil)
  }

  @Test
  func testSignInWithGooglePresentsAlertWhenNoKeyWindow() async {
    let model = withDependencies {
      $0.errorReporting.reportMessage = { _, _ in }
      $0.analytics.track = { _ in }
    } operation: {
      SignInPageModel()
    }
    model.keyWindowProvider = { nil }

    await model.signInWithGoogleButtonTapped()

    #expect(model.presentedAlert == .signInError)
  }

  // MARK: - handleSignInAPIFailure Routing Tests

  @Test
  func testHandleSignInAPIFailureShowsNetworkAlertOnAppleSSLError() async {
    let model = withDependencies {
      $0.errorReporting.reportErrorWithContext = { _, _, _, _ in }
      $0.analytics.track = { _ in }
    } operation: {
      SignInPageModel()
    }

    let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorSecureConnectionFailed)
    let afError = AFError.sessionTaskFailed(error: underlying)

    await model.handleSignInAPIFailure(afError, authMethod: .apple, step: "api_call")

    #expect(model.presentedAlert == .signInNetworkError)
    #expect(model.presentedAlert != .signInError)
  }

  @Test
  func testHandleSignInAPIFailureShowsGenericAlertOnAppleUnknownError() async {
    let model = withDependencies {
      $0.errorReporting.reportErrorWithContext = { _, _, _, _ in }
      $0.analytics.track = { _ in }
    } operation: {
      SignInPageModel()
    }

    let genericError = NSError(domain: "com.example.unknown", code: 42)

    await model.handleSignInAPIFailure(genericError, authMethod: .apple, step: "api_call")

    #expect(model.presentedAlert == .signInError)
    #expect(model.presentedAlert?.title == "Sign-In Failed")
  }

  @Test
  func testHandleSignInAPIFailureShowsNetworkAlertOnGoogleSSLError() async {
    let model = withDependencies {
      $0.errorReporting.reportErrorWithContext = { _, _, _, _ in }
      $0.analytics.track = { _ in }
    } operation: {
      SignInPageModel()
    }

    let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorSecureConnectionFailed)
    let afError = AFError.sessionTaskFailed(error: underlying)

    await model.handleSignInAPIFailure(afError, authMethod: .google, step: "google_sign_in_flow")

    #expect(model.presentedAlert == .signInNetworkError)
  }

  @Test
  func testHandleSignInAPIFailureShowsGenericAlertOnGoogleUnknownError() async {
    let model = withDependencies {
      $0.errorReporting.reportErrorWithContext = { _, _, _, _ in }
      $0.analytics.track = { _ in }
    } operation: {
      SignInPageModel()
    }

    let genericError = NSError(domain: "com.google.GIDSignIn", code: -4)

    await model.handleSignInAPIFailure(
      genericError, authMethod: .google, step: "google_sign_in_flow")

    #expect(model.presentedAlert == .signInError)
    #expect(model.presentedAlert?.title == "Sign-In Failed")
  }

  // MARK: - Sign-in Error Reporting Context Tests

  @Test
  func testSignInErrorReportIncludesNSErrorDomainAndCode() {
    let error = NSError(domain: "com.google.GIDSignIn", code: -4)

    let report = SignInErrorReport(
      error: error,
      authMethod: .google,
      step: "google_sign_in_flow")

    #expect(report.tags["auth_method"] == "google")
    #expect(report.tags["sign_in_step"] == "google_sign_in_flow")
    #expect(report.tags["error_domain"] == "com.google.GIDSignIn")
    #expect(report.tags["error_code"] == "-4")
    #expect(report.contextKey == "sign_in")
  }

  // MARK: - SignInNetworkErrorClassifier Tests

  @Test
  func testClassifierMatchesSecureConnectionFailed() {
    let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorSecureConnectionFailed)
    #expect(SignInNetworkErrorClassifier.isNetworkError(error))
    #expect(SignInNetworkErrorClassifier.isSecureConnectionFailed(error))
  }

  @Test
  func testClassifierMatchesNotConnectedToInternet() {
    let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
    #expect(SignInNetworkErrorClassifier.isNetworkError(error))
    #expect(!SignInNetworkErrorClassifier.isSecureConnectionFailed(error))
  }

  @Test
  func testClassifierMatchesTimedOutCannotConnectAndConnectionLost() {
    for code in [
      NSURLErrorTimedOut, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost,
    ] {
      let error = NSError(domain: NSURLErrorDomain, code: code)
      #expect(
        SignInNetworkErrorClassifier.isNetworkError(error),
        "Expected code \(code) to classify as network error")
    }
  }

  @Test
  func testClassifierRejectsUnrelatedDomain() {
    let error = NSError(domain: "com.example.other", code: NSURLErrorSecureConnectionFailed)
    #expect(!SignInNetworkErrorClassifier.isNetworkError(error))
    #expect(!SignInNetworkErrorClassifier.isSecureConnectionFailed(error))
  }

  @Test
  func testClassifierRejectsNSURLDomainWithUnrelatedCode() {
    let error = NSError(domain: NSURLErrorDomain, code: -9999)
    #expect(!SignInNetworkErrorClassifier.isNetworkError(error))
  }

  @Test
  func testClassifierUnwrapsAFErrorSessionTaskFailed() {
    let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorSecureConnectionFailed)
    let afError = AFError.sessionTaskFailed(error: underlying)
    #expect(SignInNetworkErrorClassifier.isNetworkError(afError))
    #expect(SignInNetworkErrorClassifier.isSecureConnectionFailed(afError))
  }

  @Test
  func testClassifierUnwrapsSignInAPIErrorWrappingAFError() {
    let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorSecureConnectionFailed)
    let afError = AFError.sessionTaskFailed(error: underlying)
    let signInError = SignInAPIError(
      authMethod: .apple,
      endpointPath: "/v1/auth/apple/mobile/signup",
      statusCode: nil,
      responseBody: nil,
      underlyingError: afError)
    #expect(SignInNetworkErrorClassifier.isNetworkError(signInError))
    #expect(SignInNetworkErrorClassifier.isSecureConnectionFailed(signInError))
  }

  @Test
  func testClassifierRejectsSignInAPIErrorWrappingNonNetworkError() {
    let signInError = SignInAPIError(
      authMethod: .google,
      endpointPath: "/v1/auth/google/signin",
      statusCode: 500,
      responseBody: nil,
      underlyingError: NSError(domain: "decode", code: 7))
    #expect(!SignInNetworkErrorClassifier.isNetworkError(signInError))
    #expect(!SignInNetworkErrorClassifier.isSecureConnectionFailed(signInError))
  }

  @Test
  func testSignInErrorReportIncludesHTTPContextAndRedactsTokens() {
    let responseBody = #"{"playolaToken":"secret-jwt","message":"unexpected shape"}"#
    let error = SignInAPIError(
      authMethod: .apple,
      endpointPath: "/v1/auth/apple/mobile/signup",
      statusCode: 200,
      responseBody: responseBody,
      underlyingError: NSError(domain: "decode", code: 7))

    let report = SignInErrorReport(error: error, authMethod: .apple, step: "api_call")

    #expect(report.tags["auth_method"] == "apple")
    #expect(report.tags["sign_in_step"] == "api_call")
    #expect(report.tags["http_status_code"] == "200")
    #expect(report.context["endpoint_path"] == "/v1/auth/apple/mobile/signup")
    #expect(
      report.context["response_body_bytes"] == "\(responseBody.lengthOfBytes(using: .utf8))")
    #expect(report.context["response_body_top_level_keys"] == "message,playolaToken")
    #expect(
      report.context["response_body"]?.contains(#""playolaToken":"[REDACTED]""#) ?? false)
    #expect(
      report.context["response_body"]?.contains(#""message":"unexpected shape""#) ?? false)
    #expect(!(report.context["response_body"]?.contains("secret-jwt") ?? true))
  }
}
