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
  @ObservationIgnored @Dependency(\.continuousClock) var clock

  var email: String! = ""
  var invitationCode: String! = ""
  var errorMessage: String? = nil
  var onDismiss: (() -> Void)?

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
    } else {
      return " Join waitlist"
    }
  }

  var actionButtonImageName: String {
    if mode == .invitationCodeInput {
      return "KeyHorizontal"
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
    switch mode {
    case .invitationCodeInput:
      mode = .waitingListInput
    case .waitingListInput:
      mode = .invitationCodeInput
    }
  }

  func signInButtonTapped() async {
    guard !invitationCode.isEmpty else {
      errorMessage = "Please enter an invitation code"
      return
    }

    do {
      try await api.verifyInvitationCode(invitationCode)
      // Clear any previous error message
      errorMessage = nil
      // Dismiss the view after successful validation
      onDismiss?()
    } catch let error as InvitationCodeError {
      errorMessage = error.localizedDescription
    } catch {
      errorMessage = "An unexpected error occurred. Please try again."
    }
  }

  func shareWithFriendsButtonTapped() async {}
}
