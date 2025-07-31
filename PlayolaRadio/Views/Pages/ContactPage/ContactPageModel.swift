//
//  ContactPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class ContactPageModel: ViewModel {
  @ObservationIgnored var stationPlayer: StationPlayer
  @ObservationIgnored @Shared(.auth) var auth
  let editProfilePageModel = EditProfilePageModel()

  var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator!

  init(
    stationPlayer: StationPlayer? = nil,
    mainContainerNavigationCoordinator: MainContainerNavigationCoordinator? = nil
  ) {
    self.stationPlayer = stationPlayer ?? .shared
    self.mainContainerNavigationCoordinator = mainContainerNavigationCoordinator ?? .shared
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
