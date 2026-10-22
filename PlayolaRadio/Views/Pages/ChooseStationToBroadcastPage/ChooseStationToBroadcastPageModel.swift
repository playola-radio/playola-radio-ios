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

  /// Includes in-development stations (`active == false`) so artists can open one and land on the
  /// station-setup Dashboard. The Dashboard tab routes active vs. setup on its own.
  var sortedStations: [Station] {
    stations
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
