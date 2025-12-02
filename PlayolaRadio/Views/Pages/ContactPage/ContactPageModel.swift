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
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics
  var editProfilePageModel: EditProfilePageModel = EditProfilePageModel()
  var likedSongsPageModel: LikedSongsPageModel = LikedSongsPageModel()
  var broadcastPageModel: BroadcastPageModel?
  var chooseStationToBroadcastPageModel: ChooseStationToBroadcastPageModel?

  private var userStations: [Station] = []

  var stationIdToTransitionTo: String? {
    userStations.first?.id
  }

  var myStationButtonVisible: Bool {
    !userStations.isEmpty
  }

  var myStationButtonLabel: String {
    userStations.count > 1 ? "My Stations" : "My Station"
  }

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
    await loadUserStations()
  }

  private func loadUserStations() async {
    guard let jwt = auth.jwt else { return }
    do {
      userStations = try await api.fetchUserStations(jwt)
    } catch {
      // Silently fail - button will remain hidden
    }
  }

  @MainActor
  func onEditProfileTapped() {
    // TODO: Navigate to edit profile view
    print("Edit profile tapped")
    mainContainerNavigationCoordinator.path.append(.editProfilePage(self.editProfilePageModel))
    print(mainContainerNavigationCoordinator.path)
  }

  @MainActor
  func onLikedSongsTapped() {
    mainContainerNavigationCoordinator.path.append(.likedSongsPage(self.likedSongsPageModel))
  }

  @MainActor
  func onMyStationTapped() async {
    guard !userStations.isEmpty else { return }

    if userStations.count == 1, let station = userStations.first {
      let model = BroadcastPageModel(stationId: station.id)
      broadcastPageModel = model
      mainContainerNavigationCoordinator.path.append(.broadcastPage(model))
      await analytics.track(
        .viewedBroadcastScreen(stationId: station.id, stationName: station.name))
    } else {
      let model = ChooseStationToBroadcastPageModel(stations: userStations)
      chooseStationToBroadcastPageModel = model
      mainContainerNavigationCoordinator.path.append(.chooseStationToBroadcastPage(model))
    }
  }

  func onLogOutTapped() {
    stationPlayer.stop()
    $auth.withLock { $0 = Auth() }
  }
}
