//
//  ScheduledShowsListModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/8/25.
//

import Dependencies
import Foundation

@MainActor
@Observable
class ScheduledShowsListModel {
  @ObservationIgnored
  @Dependency(\.api) var api

  @ObservationIgnored
  @Dependency(\.pushNotifications) var pushNotifications

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
      self.scheduledShows = try await api.getScheduledShows(jwtToken, nil, stationId)
    } catch {
      // TODO: Handle error
      print("Error loading scheduled shows: \(error)")
    }
  }
}
