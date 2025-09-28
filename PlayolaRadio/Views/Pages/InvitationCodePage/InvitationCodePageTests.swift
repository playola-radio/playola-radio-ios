//
//  InvitationCodePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/18/25.
//

import Dependencies
import Mixpanel
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class InvitationCodePageTests: XCTestCase {
  override func setUp() {
    super.setUp()
    // Clear waitingListEmail before each test
    UserDefaults.standard.removeObject(forKey: "waitingListEmail")
  }

  func testInit_SetsInitialValues() async {
    let model = InvitationCodePageModel()

    XCTAssertEqual(model.inputText, "")
    XCTAssertNil(model.errorMessage)
    XCTAssertEqual(model.mode, .invitationCodeInput)
    XCTAssertNil(model.waitingListEmail)
  }

  func testSignInButtonTapped_EmptyCode_ShowsErrorMessage() async {
    let model = InvitationCodePageModel()
    model.inputText = ""

    await model.signInButtonTapped()

    XCTAssertEqual(model.errorMessage, "Please enter an invitation code")
  }

  func testSignInButtonTapped_ValidCode_ClearsErrorAndCallsDismiss() async {
    var dismissCalled = false

    let model = withDependencies {
      $0.api.verifyInvitationCode = { code in
        XCTAssertEqual(code, "VALID123")
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }

    model.inputText = "VALID123"
    model.errorMessage = "Previous error"
    model.onDismiss = { dismissCalled = true }

    await model.signInButtonTapped()

    XCTAssertNil(model.errorMessage)
    XCTAssertTrue(dismissCalled)
  }

  func testSignInButtonTapped_InvalidCode_ShowsServerErrorMessage() async {
    let model = withDependencies {
      $0.api.verifyInvitationCode = { code in
        XCTAssertEqual(code, "INVALID123")
        throw InvitationCodeError.invalidCode("Invitation code has expired")
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }

    model.inputText = "INVALID123"

    await model.signInButtonTapped()

    XCTAssertEqual(model.errorMessage, "Invitation code has expired")
  }

  func testSignInButtonTapped_UnexpectedError_ShowsGenericErrorMessage() async {
    let model = withDependencies {
      $0.api.verifyInvitationCode = { code in
        XCTAssertEqual(code, "ERROR123")
        throw APIError.dataNotValid
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }

    model.inputText = "ERROR123"

    await model.signInButtonTapped()

    XCTAssertEqual(model.errorMessage, "An unexpected error occurred. Please try again.")
  }

  func testSignInButtonTapped_ValidCode_CallsDismiss() async {
    var dismissCalled = false

    let model = withDependencies {
      $0.api.verifyInvitationCode = { code in
        XCTAssertEqual(code, "VALID123")
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }

    model.inputText = "VALID123"
    model.onDismiss = { dismissCalled = true }

    await model.signInButtonTapped()

    XCTAssertTrue(dismissCalled)
  }

  func testChangeModeButtonTapped_TogglesMode() async {
    let model = InvitationCodePageModel()

    // Initially in invitationCodeInput mode
    XCTAssertEqual(model.mode, .invitationCodeInput)

    // Tap to change to waitingListInput mode
    await model.changeModeButtonTapped()
    XCTAssertEqual(model.mode, .waitingListInput)

    // Tap again to change back to invitationCodeInput mode
    await model.changeModeButtonTapped()
    XCTAssertEqual(model.mode, .invitationCodeInput)
  }

  func testInvitationCodeInputMode_DisplaysCorrectText() async {
    let model = InvitationCodePageModel()
    model.mode = .invitationCodeInput

    XCTAssertEqual(model.inputLabelTitleText, "Enter invite code")
    XCTAssertEqual(model.actionButtonText, "Sign in")
    XCTAssertEqual(model.actionButtonImageName, "KeyHorizontal")
    XCTAssertEqual(model.changeModeLabelIntroText, "Don't have an invite code?")
    XCTAssertEqual(model.changeModeButtonText, "Join waitlist")
    XCTAssertEqual(model.changeModeButtonImageName, "Envelope")
  }

  func testWaitingListInputMode_DisplaysCorrectText() async {
    let model = InvitationCodePageModel()
    model.mode = .waitingListInput

    XCTAssertEqual(model.inputLabelTitleText, "Enter your email to join waitlist")
    XCTAssertEqual(model.actionButtonText, " Join waitlist")
    XCTAssertEqual(model.actionButtonImageName, "Envelope")
    XCTAssertEqual(model.changeModeLabelIntroText, "Have an invite code?")
    XCTAssertEqual(model.changeModeButtonText, "Sign In")
    XCTAssertEqual(model.changeModeButtonImageName, "KeyHorizontal")
  }

  func testChangingMode_storesOldTextFieldEntry() async {
    let codeText = "ABCD"
    let model = InvitationCodePageModel()
    model.mode = .invitationCodeInput

    model.inputText = codeText

    model.mode = .waitingListInput
    XCTAssertEqual(model.inputText, "")

    model.inputText = "stone@playola.fm"

    model.mode = .invitationCodeInput
    XCTAssertEqual(model.inputText, codeText)

    model.mode = .waitingListInput
    XCTAssertEqual(model.inputText, "stone@playola.fm")
  }

  func testChangingMode_clearsError() async {
    let model = InvitationCodePageModel()
    model.mode = .invitationCodeInput

    model.errorMessage = "Some error"

    await model.changeModeButtonTapped()
    XCTAssertNil(model.errorMessage)

    model.errorMessage = "Another error"
    await model.changeModeButtonTapped()
    XCTAssertNil(model.errorMessage)
  }

  func testJoinWaitlistButtonTapped_EmptyEmail_ShowsErrorMessage() async {
    let model = InvitationCodePageModel()
    model.mode = .waitingListInput
    model.email = ""

    await model.joinWaitlistButtonTapped()

    XCTAssertEqual(model.errorMessage, "Please enter a valid email address")
  }

  func testJoinWaitlistButtonTapped_ValidEmail_CallsAPIAndDismisses() async {
    var dismissCalled = false

    let model = withDependencies {
      $0.api.addToWaitingList = { email in
        XCTAssertEqual(email, "test@example.com")
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }

    XCTAssertNil(model.waitingListEmail)  // Ensure starts as nil
    model.mode = .waitingListInput
    model.email = "test@example.com"
    model.onDismiss = { dismissCalled = true }

    await model.joinWaitlistButtonTapped()

    XCTAssertNil(model.errorMessage)
    XCTAssertTrue(dismissCalled)
    XCTAssertEqual(model.waitingListEmail, "test@example.com")
  }

  func testJoinWaitlistButtonTapped_ValidationError_ShowsServerErrorMessage() async {
    let model = withDependencies {
      $0.api.addToWaitingList = { email in
        XCTAssertEqual(email, "duplicate@example.com")
        throw APIError.validationError("Email address already exists in the waiting list")
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }

    XCTAssertNil(model.waitingListEmail)  // Ensure starts as nil
    model.mode = .waitingListInput
    model.email = "duplicate@example.com"

    await model.joinWaitlistButtonTapped()

    XCTAssertEqual(model.errorMessage, "Email address already exists in the waiting list")
    XCTAssertNil(model.waitingListEmail)  // Should remain nil on error
  }

  func testJoinWaitlistButtonTapped_UnexpectedError_ShowsGenericErrorMessage() async {
    let model = withDependencies {
      $0.api.addToWaitingList = { email in
        XCTAssertEqual(email, "error@example.com")
        throw APIError.dataNotValid
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }

    XCTAssertNil(model.waitingListEmail)  // Ensure starts as nil
    model.mode = .waitingListInput
    model.email = "error@example.com"

    await model.joinWaitlistButtonTapped()

    XCTAssertEqual(model.errorMessage, "An unexpected error occurred. Please try again.")
    XCTAssertNil(model.waitingListEmail)  // Should remain nil on error
  }

  func testActionButtonTapped_InvitationCodeMode_CallsSignInButton() async {
    let model = withDependencies {
      $0.api.verifyInvitationCode = { code in
        XCTAssertEqual(code, "TEST123")
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }

    model.mode = .invitationCodeInput
    model.inputText = "TEST123"

    await model.actionButtonTapped()

    // Should not have error since invitation code validation succeeded
    XCTAssertNil(model.errorMessage)
  }

  func testActionButtonTapped_WaitingListMode_CallsJoinWaitlistButton() async {
    let model = withDependencies {
      $0.api.addToWaitingList = { email in
        XCTAssertEqual(email, "test@waitlist.com")
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }

    XCTAssertNil(model.waitingListEmail)  // Ensure starts as nil
    model.mode = .waitingListInput
    model.inputText = "test@waitlist.com"

    await model.actionButtonTapped()

    // Should not have error since waiting list addition succeeded
    XCTAssertNil(model.errorMessage)
    XCTAssertEqual(model.waitingListEmail, "test@waitlist.com")
  }

  func testWaitingListMode_WithExistingEmail_ShowsSuccessState() async {
    let model = InvitationCodePageModel()
    model.waitingListEmail = "existing@example.com"
    model.mode = .waitingListInput

    XCTAssertEqual(model.titleText, "You're on the list!")
    XCTAssertTrue(
      model.subtitleText.contains(
        "Thanks for signing up. We'll email you as soon as it's your turn to join Playola."))
    XCTAssertEqual(model.actionButtonText, "Share with friends")
    XCTAssertEqual(model.actionButtonImageName, "share-button-icon")
    XCTAssertTrue(model.shouldHideInput)
  }

  func testWaitingListMode_WithoutExistingEmail_ShowsInputState() async {
    let model = InvitationCodePageModel()
    model.waitingListEmail = nil
    model.mode = .waitingListInput

    XCTAssertEqual(model.titleText, "Invite only, for now!")
    XCTAssertEqual(
      model.subtitleText, "Discover music through independent artist-made radio stations"
    )
    XCTAssertEqual(model.actionButtonText, " Join waitlist")
    XCTAssertEqual(model.actionButtonImageName, "Envelope")
    XCTAssertFalse(model.shouldHideInput)
  }

  func testInvitationCodeMode_ShowsCorrectState() async {
    let model = InvitationCodePageModel()
    model.waitingListEmail = "existing@example.com"  // Should not affect invitation code mode
    model.mode = .invitationCodeInput

    XCTAssertEqual(model.titleText, "Invite only, for now!")
    XCTAssertEqual(
      model.subtitleText, "Discover music through independent artist-made radio stations"
    )
    XCTAssertEqual(model.actionButtonText, "Sign in")
    XCTAssertEqual(model.actionButtonImageName, "KeyHorizontal")
    XCTAssertFalse(model.shouldHideInput)
  }

  func testActionButtonTapped_WaitingListSuccessState_ShowsShareSheet() async {
    let model = InvitationCodePageModel()
    model.waitingListEmail = "existing@example.com"
    model.mode = .waitingListInput

    XCTAssertFalse(model.showingShareSheet)  // Initially false

    await model.actionButtonTapped()

    XCTAssertTrue(model.showingShareSheet)  // Should be true after tapping
  }

  func testShareWithFriendsButtonTapped_SetsShowingShareSheet() async {
    var trackedEvents: [AnalyticsEvent] = []

    let model = withDependencies {
      $0.analytics.track = { event in
        trackedEvents.append(event)
      }
    } operation: {
      InvitationCodePageModel()
    }

    XCTAssertFalse(model.showingShareSheet)  // Initially false

    await model.shareWithFriendsButtonTapped()

    XCTAssertTrue(model.showingShareSheet)  // Should be true after calling

    // Verify analytics event was tracked
    XCTAssertEqual(trackedEvents.count, 1)
    guard let event = trackedEvents.first else {
      XCTFail("Expected analytics event to be tracked")
      return
    }
    if case .shareWithFriendsTapped = event {
      // Test passes
    } else {
      XCTFail("Expected shareWithFriendsTapped event")
    }
  }

  func testSignInButtonTapped_ValidCode_TracksAnalyticsAndSetsUserProperty() async {
    var trackedEvents: [AnalyticsEvent] = []
    var userProperties: [String: any MixpanelType] = [:]

    let model = withDependencies {
      $0.api.verifyInvitationCode = { code in
        XCTAssertEqual(code, "ANALYTICS123")
      }
      $0.analytics.track = { event in
        trackedEvents.append(event)
      }
      $0.analytics.setUserProperties = { properties in
        userProperties = properties
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }

    model.inputText = "ANALYTICS123"

    await model.signInButtonTapped()

    // Verify analytics event was tracked
    XCTAssertEqual(trackedEvents.count, 1)
    guard let event = trackedEvents.first else {
      XCTFail("Expected analytics event to be tracked")
      return
    }
    if case .invitationCodeVerified(let code) = event {
      XCTAssertEqual(code, "ANALYTICS123")
    } else {
      XCTFail("Expected invitationCodeVerified event")
    }

    // Verify user property was set
    XCTAssertEqual(userProperties["cohort"] as? String, "ANALYTICS123")
  }
}
