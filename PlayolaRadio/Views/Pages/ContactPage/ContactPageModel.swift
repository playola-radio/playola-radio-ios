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

  init(stationPlayer: StationPlayer? = nil) {
    self.stationPlayer = stationPlayer ?? StationPlayer.shared
  }

  func onViewAppeared() async {
    // TODO: Load user profile data
  }

  func onEditProfileTapped() {
    // TODO: Navigate to edit profile view
    print("Edit profile tapped")
  }

  func onLogOutTapped() {
    stationPlayer.stop()
    $auth.withLock { $0 = Auth() }
  }
}
