//
//  StationListModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/13/25.
//

import Combine
import Dependencies
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
  @ObservationIgnored @Shared(.scheduledShows) var scheduledShows:
    IdentifiedArrayOf<ScheduledShow> = []
  @ObservationIgnored @Dependency(\.analytics) var analytics

  @ObservationIgnored var stationPlayer: StationPlayer

  var stationListsForDisplay: IdentifiedArrayOf<StationList> = []
  var segmentTitles: [String] = ["All"]
  var selectedSegment = "All"
  var presentedAlert: PlayolaAlert?

  var hasLiveShows: Bool {
    return scheduledShows.contains { show in
      !show.hasEnded
    }
  }

  var isShowingLiveShows: Bool {
    selectedSegment == "Going Live"
  }

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
    let includeHidden = showSecretStations
    let visibleLists = includeHidden ? rawList : rawList.filter { !$0.hidden }

    // Build segment titles: ["All", ...station list titles]
    var titles = ["All"]
    titles.append(contentsOf: visibleLists.map { $0.title })
    segmentTitles = titles

    if !segmentTitles.contains(selectedSegment) {
      selectedSegment = "All"
    }

    if selectedSegment == "All" {
      stationListsForDisplay = visibleLists
    } else {
      stationListsForDisplay = visibleLists.filter { $0.title == selectedSegment }
    }
  }

  func segmentSelected(_ segmentTitle: String) async {
    let previousSegment = selectedSegment
    selectedSegment = segmentTitle
    loadStationListsForDisplay(stationLists)

    // Only track if this is actually a change
    guard previousSegment != segmentTitle else { return }

    await analytics.track(
      .viewedStationList(
        listName: segmentTitle,
        screen: "station_list_page"
      ))
  }

  func stationSelected(_ item: APIStationItem) async {
    if item.visibility == .comingSoon && showSecretStations == false {
      return
    }

    let station = item.anyStation

    if case .playola(let playolaStation) = station,
      let isActive = playolaStation.active,
      isActive == false
    {
      return
    }

    if case .url(let urlStation) = station,
      let isActive = urlStation.active,
      isActive == false
    {
      return
    }

    let allItems = stationListsForDisplay.flatMap {
      $0.stationItems(includeHidden: showSecretStations)
    }

    let allStations = allItems.map { $0.anyStation }
    let position = allStations.firstIndex(where: { $0.id == station.id }) ?? 0

    await analytics.track(
      .tappedStationCard(
        station: StationInfo(from: station),
        position: position,
        totalStations: allStations.count
      ))

    await analytics.track(
      .startedStation(
        station: StationInfo(from: station),
        entryPoint: "station_list"
      ))

    stationPlayer.play(station: station)
  }
}
