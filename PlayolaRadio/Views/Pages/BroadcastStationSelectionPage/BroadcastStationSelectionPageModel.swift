//
//  BroadcastStationSelectionPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//
import Observation
import PlayolaPlayer

@MainActor
@Observable
class BroadcastStationSelectionPageModel: ViewModel {
    let stations: [PlayolaPlayer.Station]

  var navigationCoordinator: NavigationCoordinator!

  init(stations: [PlayolaPlayer.Station], navigationCoordinator: NavigationCoordinator = .shared) {
        self.stations = stations
    self.navigationCoordinator = navigationCoordinator
        super.init()
    }

    func stationSelected(_ station: PlayolaPlayer.Station) {
      navigationCoordinator.path.append(.broadcastPage(BroadcastPageModel(station: station)))
    }
}
