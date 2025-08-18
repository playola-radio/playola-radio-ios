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

  enum Mode {
    case invitationCodeInput
    case waitingListInput
  }

  var mode: Mode = .invitationCodeInput

  func joinWaitlistButtonTapped() async {}

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
