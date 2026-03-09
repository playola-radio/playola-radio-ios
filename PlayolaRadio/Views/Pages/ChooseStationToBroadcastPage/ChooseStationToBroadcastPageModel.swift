//
//  ChooseStationToBroadcastPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/2/25.
//

import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class ChooseStationToBroadcastPageModel: ViewModel {

  // MARK: - Shared State

  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Initialization

  init(stations: [Station]) {
    self.stations = stations
    super.init()
  }

  // MARK: - Properties

  let stations: [Station]
  let navigationTitle = "Choose Station"

  var sortedStations: [Station] {
    stations
      .filter { $0.active != false }
      .sorted {
        $0.curatorName.localizedCaseInsensitiveCompare($1.curatorName) == .orderedAscending
      }
  }

  // MARK: - User Actions

  func stationSelected(_ station: Station) {
    mainContainerNavigationCoordinator.switchToBroadcastMode(stationId: station.id)
  }

  // MARK: - View Helpers

  func displayName(for station: Station) -> String {
    "\(station.curatorName) - \(station.name)"
  }
}
