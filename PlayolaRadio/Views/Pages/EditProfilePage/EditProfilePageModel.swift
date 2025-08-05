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
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  var firstName: String! = ""
  var lastName: String! = ""
  var email: String! = ""

  var presentedAlert: PlayolaAlert?

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

  func saveButtonTapped() async {
    guard let jwt = auth.jwt else { return }
    do {
      let result = try await api.updateUser(
        jwtToken: jwt, firstName: firstName, lastName: lastName ?? nil)
      $auth.withLock { $0 = result }
      self.presentedAlert = .updateProfileSuccessfullAlert

      // Dismiss the view after showing the alert
      try? await clock.sleep(for: .seconds(1.5))
      self.mainContainerNavigationCoordinator.pop()

    } catch let error {
      print(error)
      self.presentedAlert = .updateProfileErrorAlert
    }
  }

  func viewAppeared() {
    self.firstName = auth.currentUser?.firstName ?? ""
    self.lastName = auth.currentUser?.lastName ?? ""
    self.email = auth.currentUser?.email ?? ""
  }
}

extension PlayolaAlert {
  static var updateProfileSuccessfullAlert: PlayolaAlert {
    PlayolaAlert(
      title: "Update Successful",
      message: "Your profile has been successfully updated.",
      dismissButton: .cancel(Text("OK")))
  }

  static var updateProfileErrorAlert: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "There was a problem updating your profile. Please try again later.",
      dismissButton: .cancel(Text("OK")))
  }
}
