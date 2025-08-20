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

    let model = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      SignInPageModel()
    }

    let request = ASAuthorizationAppleIDRequest(coder: NSCoder())!
    await model.signInWithAppleButtonTapped(request: request)

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

  // MARK: - Invitation Code Page Tests

  func testInvitationCodesPageModel_HasBeenUnlockedTrue_InvitationCodeNil_ReturnsModel() {
    Config.shared.hasBeenUnlocked = true
    Config.shared.invitationCode = nil

    let model = SignInPageModel()

    XCTAssertNotNil(model.invitationCodesPageModel)

    // Clean up
    Config.shared.hasBeenUnlocked = false
    Config.shared.invitationCode = nil
  }

  func testInvitationCodesPageModel_HasBeenUnlockedFalse_InvitationCodeNotNil_ReturnsModel() {
    Config.shared.hasBeenUnlocked = false
    Config.shared.invitationCode = "TEST123"

    let model = SignInPageModel()

    XCTAssertNotNil(model.invitationCodesPageModel)

    // Clean up
    Config.shared.hasBeenUnlocked = false
    Config.shared.invitationCode = nil
  }

  func testInvitationCodesPageModel_HasBeenUnlockedTrue_InvitationCodeNotNil_ReturnsModel() {
    Config.shared.hasBeenUnlocked = true
    Config.shared.invitationCode = "TEST123"

    let model = SignInPageModel()

    XCTAssertNotNil(model.invitationCodesPageModel)

    // Clean up
    Config.shared.hasBeenUnlocked = false
    Config.shared.invitationCode = nil
  }

  func testInvitationCodesPageModel_HasBeenUnlockedFalse_InvitationCodeNil_ReturnsNil() {
    Config.shared.hasBeenUnlocked = false
    Config.shared.invitationCode = nil

    let model = SignInPageModel()

    XCTAssertNil(model.invitationCodesPageModel)

    // Clean up
    Config.shared.hasBeenUnlocked = false
    Config.shared.invitationCode = nil
  }
}
