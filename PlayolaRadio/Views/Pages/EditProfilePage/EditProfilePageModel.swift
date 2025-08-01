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

  func viewAppeared() {
    self.firstName = auth.currentUser?.firstName ?? ""
    self.lastName = auth.currentUser?.lastName ?? ""
    self.email = auth.currentUser?.email ?? ""
  }
}
