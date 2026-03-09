//
//  ChooseStationPageModel.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

@MainActor
@Observable
class ChooseStationPageModel: ViewModel {

  // MARK: - Initialization

  init(
    stations: [Station],
    onStationSelected: @escaping (Station) -> Void
  ) {
    self.stations = stations
    self.onStationSelected = onStationSelected
    super.init()
  }

  // MARK: - Properties

  let stations: [Station]
  let onStationSelected: (Station) -> Void
  let navigationTitle = "Choose Station"

  var sortedStations: [Station] {
    stations
      .filter { $0.active != false }
      .sorted {
        $0.curatorName.localizedCaseInsensitiveCompare($1.curatorName) == .orderedAscending
      }
  }

  // MARK: - User Actions

  func stationTapped(_ station: Station) {
    onStationSelected(station)
  }
}
