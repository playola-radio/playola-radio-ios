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

  // TODO: Create these tests:

  // MARK: - signInWithAppleCompleted() Tests

  // func testSignInWithAppleCompleted_CanHandleDecodingErrorOnAppleIDCredential() {
  //   // TODO: Implement test
  // }

  // func testSignInWithAppleCompleted_StoresAppleSignInInfoIfEmailWasReceived() {
  //   // TODO: Implement test
  // }

  // func testSignInWithAppleCompleted_NotifiesUserIfNoEmailCachedAndNoneProvided() {
  //   // TODO: Implement test
  // }

  // func testSignInWithAppleCompleted_ProvidesResultsToAPI() {
  //   // TODO: Implement test
  // }

  // MARK: - SignInWithGoogle Tests

  // TODO: Implement Google sign in tests

  // MARK: - Presented Sheet Tests

  func testPresentedSheet_HasBeenUnlockedTrue_InvitationCodeNil_ReturnsNil() {
    @Shared(.hasBeenUnlocked) var hasBeenUnlocked = true
    @Shared(.invitationCode) var invitationCode: String?

    let model = SignInPageModel()

    XCTAssertNil(model.presentedSheet)
  }

  func testPresentedSheet_HasBeenUnlockedFalse_InvitationCodeNotNil_ReturnsNil() {
    @Shared(.hasBeenUnlocked) var hasBeenUnlocked = false
    @Shared(.invitationCode) var invitationCode: String? = "TEST123"

    let model = SignInPageModel()

    XCTAssertNil(model.presentedSheet)
  }

  func testPresentedSheet_HasBeenUnlockedTrue_InvitationCodeNotNil_ReturnsNil() {
    @Shared(.hasBeenUnlocked) var hasBeenUnlocked = true
    @Shared(.invitationCode) var invitationCode: String? = "TEST123"

    let model = SignInPageModel()

    XCTAssertNil(model.presentedSheet)
  }

  func testPresentedSheet_HasBeenUnlockedFalse_InvitationCodeNil_ReturnsInvitationCodeSheet() {
    @Shared(.hasBeenUnlocked) var hasBeenUnlocked = false
    @Shared(.invitationCode) var invitationCode: String?

    let model = SignInPageModel()

    if case .invitationCode = model.presentedSheet {
      XCTAssertTrue(true)
    } else {
      XCTFail("Expected invitation code sheet to be presented")
    }
  }
}
