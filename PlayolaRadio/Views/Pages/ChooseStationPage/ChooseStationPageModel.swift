//
//  ChooseStationPageModel.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

@MainActor
@Observable
class ChooseStationPageModel: ViewModel {
  let stations: [Station]
  let onStationSelected: (Station) -> Void

  var sortedStations: [Station] {
    stations
      .filter { $0.active != false }
      .sorted {
        $0.curatorName.localizedCaseInsensitiveCompare($1.curatorName) == .orderedAscending
      }
  }

  init(
    stations: [Station],
    onStationSelected: @escaping (Station) -> Void
  ) {
    self.stations = stations
    self.onStationSelected = onStationSelected
    super.init()
  }

  func stationTapped(_ station: Station) {
    onStationSelected(station)
  }
}
