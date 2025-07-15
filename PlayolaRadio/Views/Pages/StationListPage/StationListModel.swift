//
//  StationListModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/13/25.
//

import Combine
import IdentifiedCollections
import Sharing
import SwiftUI

@MainActor
@Observable
class StationListModel: ViewModel {
  var cancellables = Set<AnyCancellable>()
  // MARK: State
  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []

  @ObservationIgnored var stationPlayer: StationPlayer

  var stationListsForDisplay: IdentifiedArrayOf<StationList> = []
  var segmentTitles: [String] = ["All"]
  var selectedSegment = "All"
  var presentedAlert: PlayolaAlert?

  init(stationPlayer: StationPlayer? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
  }

  // MARK: Actions
  func viewAppeared() async {
    $stationLists.publisher
      .sink { [weak self] lists in
        self?.loadStationListsForDisplay(lists)
      }
      .store(in: &cancellables)
  }

  private func loadStationListsForDisplay(_ rawList: IdentifiedArrayOf<StationList>) {
    let visibleLists =
      showSecretStations
      ? rawList
      : rawList.filter { $0.id != StationList.inDevelopmentListId }

    segmentTitles = ["All"] + visibleLists.map { $0.title }

    if !segmentTitles.contains(selectedSegment) {
      selectedSegment = "All"
    }

    if selectedSegment == "All" {
      stationListsForDisplay = visibleLists
    } else {
      stationListsForDisplay = visibleLists.filter { $0.title == selectedSegment }
    }
  }

  func segmentSelected(_ segmentTitle: String) {
    selectedSegment = segmentTitle
    loadStationListsForDisplay(stationLists)
  }

  func stationSelected(_ station: RadioStation) {
    stationPlayer.play(station: station)
  }
}
