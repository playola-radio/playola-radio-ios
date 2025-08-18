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
  var email: String! = ""
  var invitationCode: String! = ""
  var errorMessage: String? = nil

  enum Mode {
    case invitationCodeInput
    case waitingListInput
  }

  var mode: Mode = .invitationCodeInput

  func joinWaitlistButtonTapped() async {}

  func signInButtonTapped() async {}

  func shareWithFriendsButtonTapped() async {}
}
