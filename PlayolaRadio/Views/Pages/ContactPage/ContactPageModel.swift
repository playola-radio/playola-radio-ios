//
//  ContactPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Dependencies
import PlayolaCore
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class ContactPageModel: ViewModel {
  @ObservationIgnored var stationPlayer: StationPlayer
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  var editProfilePageModel: EditProfilePageModel = EditProfilePageModel()

  var name: String {
    return auth.currentUser?.fullName ?? "Anonymous"
  }

  var email: String {
    return auth.currentUser?.email ?? "Unknown"
  }

  init(
    stationPlayer: StationPlayer? = nil
  ) {
    self.stationPlayer = stationPlayer ?? .shared
  }

  func onViewAppeared() async {
    // TODO: Load user profile data
  }

  @MainActor
  func onEditProfileTapped() {
    // TODO: Navigate to edit profile view
    print("Edit profile tapped")
    mainContainerNavigationCoordinator.path.append(.editProfilePage(self.editProfilePageModel))
    print(mainContainerNavigationCoordinator.path)
  }

  func onLogOutTapped() {
    stationPlayer.stop()
    $auth.withLock { $0 = Auth() }
  }
}
