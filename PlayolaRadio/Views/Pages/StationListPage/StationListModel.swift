//
//  StationListModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/13/25.
//

import Sharing
import Combine
import SwiftUI
import IdentifiedCollections

@MainActor
@Observable
class StationListModel: ViewModel {
  var cancellables = Set<AnyCancellable>()
  // MARK: State
  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []

  var stationListsForDisplay: IdentifiedArrayOf<StationList> = []
  var segmentTitles: [String] = ["All"]
  var selectedSegment = "All"
  var presentedAlert: PlayolaAlert? = nil

  // MARK: Actions
  func viewAppeared() async {
    $stationLists.publisher
      .sink { [weak self] lists in
        self?.loadStationListsForDisplay(lists)
      }
      .store(in: &cancellables)
  }

  private func loadStationListsForDisplay(_ rawList: IdentifiedArrayOf<StationList>) {
    let visibleLists = showSecretStations
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

  func handlePlayolaIconTapped10Times() {
    $showSecretStations.withLock { $0 = !$0 }
    presentedAlert = showSecretStations ? .secretStationsTurnedOnAlert : .secretStationsHiddenAlert

    loadStationListsForDisplay(stationLists)
  }

  func segmentSelected(_ segmentTitle: String) {
    selectedSegment = segmentTitle
    loadStationListsForDisplay(stationLists)
  }
}
