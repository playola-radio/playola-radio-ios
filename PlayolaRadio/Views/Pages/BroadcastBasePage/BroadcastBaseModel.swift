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

enum BroadcastTab {
  case schedule
  case songs
}

@MainActor
@Observable
class BroadcastBaseModel: ViewModel {
  var disposeBag: Set<AnyCancellable> = Set()

  // MARK: - State
  var id = UUID()
  var selectedTab: BroadcastTab = .schedule
  var presentedAlert: PlayolaAlert?
  var stations: [PlayolaPlayer.Station] = []
  var selectedStation: PlayolaPlayer.Station?
  var isLoading: Bool = false

  // MARK: - Dependencies
  @ObservationIgnored @Shared(.currentUser) var currentUser: User?
  @ObservationIgnored @Dependency(APIClient.self) var apiClient
  @ObservationIgnored @Shared(.auth) var auth: Auth

  var navigationCoordinator: NavigationCoordinator!

  @MainActor
  init(selectedTab: BroadcastTab = .schedule,
       navigationCoordinator: NavigationCoordinator = .shared) {
    self.selectedTab = selectedTab
    self.navigationCoordinator = navigationCoordinator
    super.init()
  }

  // MARK: - Actions
  func viewAppeared() async {
    defer { self.isLoading = false }
    isLoading = true
    do {
      let stations = try await apiClient.fetchUserStations(userId: auth.jwtUser!.id)
      self.stations = stations

      if (self.stations.count >= 1) {
        selectedStation = self.stations.first { $0.id == "f3864734-de35-414f-b0b3-e6909b0b77bd" }
      } else {
        print("No stations found")
      }
    } catch (let err) {
      print("Error downloading stations: \(err)")
    }
  }

  func hamburgerButtonTapped() {
    navigationCoordinator.slideOutMenuIsShowing = true
  }

  func selectTab(_ tab: BroadcastTab) {
    selectedTab = tab
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
