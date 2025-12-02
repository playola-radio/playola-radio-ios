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
  let stations: [Station]

  var sortedStations: [Station] {
    stations.sorted {
      $0.curatorName.localizedCaseInsensitiveCompare($1.curatorName) == .orderedAscending
    }
  }

  init(stations: [Station]) {
    self.stations = stations
    super.init()
  }

  func displayName(for station: Station) -> String {
    "\(station.curatorName) - \(station.name)"
  }
}
