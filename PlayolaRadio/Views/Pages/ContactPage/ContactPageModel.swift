//
//  ContactPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Dependencies
import Sharing
import SwiftUI

@MainActor
@Observable
class ContactPageModel: ViewModel {

  func onViewAppeared() async {
    // TODO: Load user profile data
  }

  func onEditProfileTapped() {
    // TODO: Navigate to edit profile view
    print("Edit profile tapped")
  }

  func onLogOutTapped() {
    // TODO: Implement log out functionality
    print("Log out tapped")
  }
}
