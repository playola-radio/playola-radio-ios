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
    await model.signInWithAppleButtonTapped(request: request)
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
    } operation: {
      SignInPageModel()
    }

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
      $0.errorReporting.reportError = { error, tags in
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
      $0.errorReporting.reportError = { error, tags in
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
}
