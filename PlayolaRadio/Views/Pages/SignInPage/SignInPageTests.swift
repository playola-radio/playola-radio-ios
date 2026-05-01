//
//  SignInPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/22/25.
//

import AuthenticationServices
import Dependencies
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class SignInPageTests: XCTestCase {
  func testSignInWithApple_CorrectlyAddsScopeToTheAppleSignInRequest() async {
    let request = ASAuthorizationAppleIDRequest(coder: NSCoder())!
    let model = SignInPageModel()
    model.signInWithAppleButtonTapped(request: request)
    XCTAssertEqual(request.requestedScopes, [.email, .fullName])
  }

  func testSignInWithApple_TracksSignInStartedEvent() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let expectation = XCTestExpectation(description: "Analytics event tracked")

    let model = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
        if case .signInStarted(let method) = event, method == .apple {
          expectation.fulfill()
        }
      }
    } operation: {
      SignInPageModel()
    }

    let request = ASAuthorizationAppleIDRequest(coder: NSCoder())!
    model.signInWithAppleButtonTapped(request: request)

    await fulfillment(of: [expectation], timeout: 1.0)

    let hasSignInStartedEvent = capturedEvents.value.contains { event in
      if case .signInStarted(let method) = event {
        return method == .apple
      }
      return false
    }

    XCTAssertTrue(hasSignInStartedEvent, "Should track signInStarted event for Apple")
  }

  func testSignInWithGoogle_TracksSignInStartedEvent() async {
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

    XCTAssertTrue(hasSignInStartedEvent, "Should track signInStarted event for Google")
  }

  // MARK: - signInWithAppleCompleted() Error Reporting Tests

  func testSignInWithAppleCompletedReportsErrorOnAuthorizationFailure() async {
    let reportedErrors = LockIsolated<[(Error, [String: String])]>([])
    let expectation = XCTestExpectation(description: "reportError called")

    let model = withDependencies {
      $0.errorReporting.reportErrorWithContext = { error, tags, _ in
        reportedErrors.withValue { $0.append((error, tags)) }
        expectation.fulfill()
      }
    } operation: {
      SignInPageModel()
    }

    let genericError = NSError(domain: "test.domain", code: 42, userInfo: nil)
    model.signInWithAppleCompleted(result: .failure(genericError))

    await fulfillment(of: [expectation], timeout: 1.0)

    XCTAssertEqual(reportedErrors.value.count, 1, "Should call reportError exactly once")
    let tags = reportedErrors.value.first?.1 ?? [:]
    XCTAssertEqual(tags["auth_method"], "apple")
  }

  func testSignInWithAppleCompletedDoesNotReportErrorOnUserCancel() async {
    let reportedErrors = LockIsolated<[(Error, [String: String])]>([])
    let invertedExpectation = XCTestExpectation(description: "reportError must NOT be called")
    invertedExpectation.isInverted = true

    let model = withDependencies {
      $0.errorReporting.reportErrorWithContext = { error, tags, _ in
        reportedErrors.withValue { $0.append((error, tags)) }
        invertedExpectation.fulfill()
      }
    } operation: {
      SignInPageModel()
    }

    let cancelError = ASAuthorizationError(.canceled)
    model.signInWithAppleCompleted(result: .failure(cancelError))

    await fulfillment(of: [invertedExpectation], timeout: 0.2)

    XCTAssertTrue(
      reportedErrors.value.isEmpty,
      "Should not report ASAuthorizationError.canceled (user cancellations are not bugs)")
  }

  // MARK: - presentedAlert Tests

  func testSignInWithAppleCompletedPresentsAlertOnAuthorizationFailure() async {
    let model = withDependencies {
      $0.errorReporting.reportErrorWithContext = { _, _, _ in }
    } operation: {
      SignInPageModel()
    }

    let genericError = NSError(domain: "test.domain", code: 42, userInfo: nil)
    model.signInWithAppleCompleted(result: .failure(genericError))

    XCTAssertEqual(model.presentedAlert, .signInError)
  }

  func testSignInWithAppleCompletedDoesNotPresentAlertOnUserCancel() async {
    let model = withDependencies {
      $0.errorReporting.reportErrorWithContext = { _, _, _ in }
    } operation: {
      SignInPageModel()
    }

    let cancelError = ASAuthorizationError(.canceled)
    model.signInWithAppleCompleted(result: .failure(cancelError))

    XCTAssertNil(model.presentedAlert)
  }

  func testSignInWithGooglePresentsAlertWhenNoKeyWindow() async {
    let model = withDependencies {
      $0.errorReporting.reportMessage = { _, _ in }
      $0.analytics.track = { _ in }
    } operation: {
      SignInPageModel()
    }
    model.keyWindowProvider = { nil }

    await model.signInWithGoogleButtonTapped()

    XCTAssertEqual(model.presentedAlert, .signInError)
  }

  // MARK: - Sign-in Error Reporting Context Tests

  func testSignInErrorReportIncludesNSErrorDomainAndCode() {
    let error = NSError(domain: "com.google.GIDSignIn", code: -4)

    let report = SignInErrorReport(
      error: error,
      authMethod: .google,
      step: "google_sign_in_flow")

    XCTAssertEqual(report.tags["auth_method"], "google")
    XCTAssertEqual(report.tags["sign_in_step"], "google_sign_in_flow")
    XCTAssertEqual(report.tags["error_domain"], "com.google.GIDSignIn")
    XCTAssertEqual(report.tags["error_code"], "-4")
  }

  func testSignInErrorReportIncludesHTTPContextAndRedactsTokens() {
    let responseBody = #"{"playolaToken":"secret-jwt","message":"unexpected shape"}"#
    let error = SignInAPIError(
      authMethod: .apple,
      endpointPath: "/v1/auth/apple/mobile/signup",
      statusCode: 200,
      responseBody: responseBody,
      underlyingError: NSError(domain: "decode", code: 7))

    let report = SignInErrorReport(error: error, authMethod: .apple, step: "api_call")

    XCTAssertEqual(report.tags["auth_method"], "apple")
    XCTAssertEqual(report.tags["sign_in_step"], "api_call")
    XCTAssertEqual(report.tags["http_status_code"], "200")
    XCTAssertEqual(report.context["endpoint_path"], "/v1/auth/apple/mobile/signup")
    XCTAssertEqual(
      report.context["response_body_bytes"], "\(responseBody.lengthOfBytes(using: .utf8))")
    XCTAssertEqual(report.context["response_body_top_level_keys"], "message,playolaToken")
    XCTAssertTrue(
      report.context["response_body"]?.contains(#""playolaToken":"[REDACTED]""#) ?? false)
    XCTAssertTrue(
      report.context["response_body"]?.contains(#""message":"unexpected shape""#) ?? false)
    XCTAssertFalse(report.context["response_body"]?.contains("secret-jwt") ?? true)
  }
}
