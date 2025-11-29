//
//  ScheduledShowsListModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/8/25.
//

import Dependencies
import Foundation
import IdentifiedCollections
import Sharing

@MainActor
@Observable
class ScheduledShowsListModel {
  @ObservationIgnored
  @Dependency(\.api) var api

  @ObservationIgnored
  @Dependency(\.pushNotifications) var pushNotifications

  @ObservationIgnored
  @Shared(.scheduledShows) var sharedScheduledShows: IdentifiedArrayOf<ScheduledShow> = []

  var scheduledShows: [ScheduledShow] = [] {
    didSet {
      updateTileModels()
    }
  }
  var stationId: String?
  var presentedAlert: PlayolaAlert?
  var tileModels: [ScheduledShowTileModel] = []

  init(stationId: String? = nil, scheduledShows: [ScheduledShow] = []) {
    self.stationId = stationId
    self.scheduledShows = scheduledShows
    updateTileModels()
  }

  private func updateTileModels() {
    tileModels = scheduledShows.map { ScheduledShowTileModel(scheduledShow: $0) }
  }

  func loadScheduledShows(jwtToken: String) async {
    do {
      let fetchedShows = try await api.getScheduledShows(jwtToken, nil, stationId)

      // Update shared state so other components (like StationListModel) can observe
      $sharedScheduledShows.withLock {
        $0 = IdentifiedArray(uniqueElements: fetchedShows)
      }

      // Update local state for display
      self.scheduledShows = fetchedShows
    } catch {
      print("Error loading scheduled shows: \(error)")
    }
  }
}
