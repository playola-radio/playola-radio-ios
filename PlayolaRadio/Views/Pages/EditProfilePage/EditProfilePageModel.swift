//
//  EditProfileModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/31/25.
//

import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class EditProfilePageModel: ViewModel {
  @ObservationIgnored @Shared(.auth) var auth

  var firstName: String = ""
  var lastName: String = ""
  var email: String = ""

  var isSaveButtonEnabled: Bool {
    let originalFirstName = auth.currentUser?.firstName ?? ""
    let originalLastName = auth.currentUser?.lastName ?? ""

    // Check if firstName has changed
    if firstName != originalFirstName {
      return true
    }

    // Check if lastName has changed (treating nil and "" as equivalent)
    let normalizedCurrentLastName = lastName.isEmpty ? nil : lastName
    let normalizedOriginalLastName = originalLastName.isEmpty ? nil : originalLastName

    if normalizedCurrentLastName != normalizedOriginalLastName {
      return true
    }

    return false
  }

  func viewAppeared() {
    self.firstName = auth.currentUser?.firstName ?? ""
    self.lastName = auth.currentUser?.lastName ?? ""
    self.email = auth.currentUser?.email ?? ""
  }
}
