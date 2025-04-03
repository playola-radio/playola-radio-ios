//
//  BroadcastBaseModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//

import Combine
import SwiftUI
import Sharing
import Dependencies
import PlayolaPlayer

@MainActor
@Observable
class BroadcastBaseModel: ViewModel {
  var disposeBag: Set<AnyCancellable> = Set()
  var station: PlayolaPlayer.Station
  var selectedTab: NavigationCoordinator.BroadcastTabs = .schedule {
    didSet {
      navigationCoordinator.activeBroadcastTab = selectedTab
    }
  }

  // MARK: - State
  var id = UUID()
  var presentedAlert: PlayolaAlert?

  // MARK: - Dependencies
  @ObservationIgnored @Shared(.currentUser) var currentUser: User?
  @ObservationIgnored @Dependency(APIClient.self) var apiClient
  @ObservationIgnored @Shared(.auth) var auth: Auth

  var navigationCoordinator: NavigationCoordinator!

  @MainActor
  init(station: PlayolaPlayer.Station, navigationCoordinator: NavigationCoordinator = .shared) {
    self.station = station
    self.navigationCoordinator = navigationCoordinator
    super.init()
  }

  func selectTab(_ tab: NavigationCoordinator.BroadcastTabs) {
    selectedTab = tab
  }

  func hamburgerButtonTapped() {
    navigationCoordinator.slideOutMenuIsShowing = true
  }
}

extension PlayolaAlert {
  static var noStationFound: PlayolaAlert {
    PlayolaAlert(
      title: "No Station Found",
      message: "You don't have a station yet. Please contact support to create one.",
      dismissButton: .cancel(Text("OK"))
    )
  }
}
