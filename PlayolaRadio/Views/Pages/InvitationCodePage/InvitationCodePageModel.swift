//
//  InvitationCodePageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/18/25.
//

import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class InvitationCodePageModel: ViewModel {
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.continuousClock) var clock

  @ObservationIgnored @Shared(.invitationCode) var invitationCode
  @ObservationIgnored @AppStorage("waitingListEmail") var waitingListEmail: String?

  var email: String! = ""
  var invitationCodeInputStr: String! = ""
  var errorMessage: String?
  var onDismiss: (() -> Void)?
  var showingShareSheet = false

  var inputText: String {
    get {
      return mode == .invitationCodeInput ? invitationCodeInputStr : email
    }
    set {
      if mode == .invitationCodeInput {
        invitationCodeInputStr = newValue
      } else {
        email = newValue
      }
    }
  }

  var titleText: String {
    if mode == .waitingListInput && waitingListEmail != nil {
      return "You're on the list!"
    } else {
      return "Invite only, for now!"
    }
  }

  var subtitleText: String {
    if mode == .waitingListInput && waitingListEmail != nil {
      return "Thanks for signing up. We'll email you as soon as it's your turn to join Playola."
    } else {
      return "Discover music through independent artist-made radio stations"
    }
  }

  var showCheckmark: Bool {
    return mode == .waitingListInput && waitingListEmail != nil
  }

  var attributedSubtitleText: AttributedString {
    if mode == .waitingListInput && waitingListEmail != nil {
      var attributedString = AttributedString(
        "✓ Thanks for signing up. We'll email you as soon as it's your turn to join Playola.")
      if let range = attributedString.range(of: "✓") {
        attributedString[range].foregroundColor = .green
      }
      return attributedString
    } else {
      return AttributedString("Discover music through independent artist-made radio stations")
    }
  }

  var shouldHideInput: Bool {
    return mode == .waitingListInput && waitingListEmail != nil
  }

  var inputLabelTitleText: String {
    if mode == .invitationCodeInput {
      return "Enter invite code"
    } else {
      return "Enter your email to join waitlist"
    }
  }

  var actionButtonText: String {
    if mode == .invitationCodeInput {
      return "Sign in"
    } else if mode == .waitingListInput && waitingListEmail != nil {
      return "Share with friends"
    } else {
      return " Join waitlist"
    }
  }

  var actionButtonImageName: String {
    if mode == .invitationCodeInput {
      return "KeyHorizontal"
    } else if mode == .waitingListInput && waitingListEmail != nil {
      return "share-button-icon"
    } else {
      return "Envelope"
    }
  }

  var changeModeLabelIntroText: String {
    if mode == .invitationCodeInput {
      return "Don't have an invite code?"
    } else {
      return "Have an invite code?"
    }
  }

  var changeModeButtonText: String {
    if mode == .invitationCodeInput {
      return "Join waitlist"
    } else {
      return "Sign In"
    }
  }

  var changeModeButtonImageName: String {
    if mode == .invitationCodeInput {
      return "Envelope"
    } else {
      return "KeyHorizontal"
    }
  }

  enum Mode {
    case invitationCodeInput
    case waitingListInput
  }

  var mode: Mode = .invitationCodeInput

  func changeModeButtonTapped() async {
    errorMessage = nil
    switch mode {
    case .invitationCodeInput:
      mode = .waitingListInput
    case .waitingListInput:
      mode = .invitationCodeInput
    }
  }

  func actionButtonTapped() async {
    if mode == .invitationCodeInput {
      return await signInButtonTapped()
    } else if mode == .waitingListInput && waitingListEmail != nil {
      return await shareWithFriendsButtonTapped()
    } else {
      return await joinWaitlistButtonTapped()
    }
  }

  func joinWaitlistButtonTapped() async {
    guard !email.isEmpty else {
      errorMessage = "Please enter a valid email address"
      return
    }

    do {
      try await api.addToWaitingList(email)
      errorMessage = nil
      waitingListEmail = email
      onDismiss?()
    } catch let error as APIError {
      switch error {
      case .validationError(let message):
        errorMessage = message
      default:
        errorMessage = "An unexpected error occurred. Please try again."
      }
    } catch {
      errorMessage = "An unexpected error occurred. Please try again."
    }
  }

  func signInButtonTapped() async {
    guard !invitationCodeInputStr.isEmpty else {
      errorMessage = "Please enter an invitation code"
      return
    }

    do {
      try await api.verifyInvitationCode(invitationCodeInputStr)

      errorMessage = nil
      $invitationCode.withLock { $0 = invitationCodeInputStr }

      // Track the successful invitation code verification
      await analytics.track(.invitationCodeVerified(code: invitationCodeInputStr))

      // Set the invitation code as a user property (cohort identifier)
      await analytics.setUserProperties(["cohort": invitationCodeInputStr])

      onDismiss?()
    } catch let error as InvitationCodeError {
      errorMessage = error.localizedDescription
    } catch {
      errorMessage = "An unexpected error occurred. Please try again."
    }
  }

  func shareWithFriendsButtonTapped() async {
    await analytics.track(.shareWithFriendsTapped)
    showingShareSheet = true
  }
}
