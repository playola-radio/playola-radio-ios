//
//  StationListModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/13/25.
//

import Combine
import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class StationListModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.pushNotifications) var pushNotifications
  @ObservationIgnored var stationPlayer: StationPlayer

  // MARK: - Shared State

  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
  @ObservationIgnored @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
  @ObservationIgnored @Shared(.hasAskedForNotificationPermission)
  var hasAskedForNotificationPermission: Bool
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Initialization

  init(stationPlayer: StationPlayer? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
  }

  // MARK: - Properties

  var cancellables = Set<AnyCancellable>()
  var stationListsForDisplay: IdentifiedArrayOf<StationList> = []
  var segmentTitles: [String] = ["All"]
  var selectedSegment = "All"
  var searchText = ""
  var presentedAlert: PlayolaAlert?
  let navigationTitle = "Radio Stations"
  let suggestArtistButtonText = "Suggest Station"
  let searchBarPlaceholder = "Search stations"
  let noResultsMessage = "No stations found"

  // MARK: - User Actions

  func viewAppeared() async {
    $stationLists.publisher
      .sink { [weak self] lists in
        self?.loadStationListsForDisplay(lists)
      }
      .store(in: &cancellables)

    $liveStations.publisher
      .sink { [weak self] _ in
        guard let self else { return }
        self.loadStationListsForDisplay(self.stationLists)
      }
      .store(in: &cancellables)

    if !hasAskedForNotificationPermission {
      presentedAlert = .notificationPermissionPrompt(
        onYes: { [weak self] in
          await self?.notificationAlertYesTapped()
        },
        onNo: { [weak self] in
          await self?.notificationAlertNoTapped()
        }
      )
    }
  }

  func notificationAlertYesTapped() async {
    $hasAskedForNotificationPermission.withLock { $0 = true }
    presentedAlert = nil

    do {
      let granted = try await pushNotifications.requestAuthorization()
      if granted {
        await pushNotifications.registerForRemoteNotifications()
      }
    } catch {
      print("Failed to request notification authorization: \(error)")
    }
  }

  func notificationAlertNoTapped() async {
    $hasAskedForNotificationPermission.withLock { $0 = true }
    presentedAlert = nil
  }

  func suggestArtistTapped() {
    let model = StationSuggestionPageModel()
    model.onDismiss = { [weak self] in
      self?.mainContainerNavigationCoordinator.presentedSheet = nil
    }
    mainContainerNavigationCoordinator.presentedSheet = .artistSuggestion(model)
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

  // MARK: - View Helpers

  func liveStatusForStation(_ stationId: String) -> LiveStatus? {
    liveStations.first { $0.stationId == stationId }?.liveStatus
  }

  var isShowingNoResults: Bool {
    guard !searchText.isEmpty else { return false }
    return stationListsForDisplay.allSatisfy { list in
      sortedStationItems(for: list).isEmpty
    }
  }

  func sortedStationItems(for list: StationList) -> [APIStationItem] {
    let items = list.stationItems(includeHidden: showSecretStations)
    let filtered =
      searchText.isEmpty
      ? items
      : items.filter { item in
        let station = item.anyStation
        return station.name.localizedCaseInsensitiveContains(searchText)
          || station.stationName.localizedCaseInsensitiveContains(searchText)
      }
    return filtered.sorted { item1, item2 in
      item1.liveSortPriority(liveStations) < item2.liveSortPriority(liveStations)
    }
  }

  // MARK: - Private Helpers

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
}

extension PlayolaAlert {
  static func notificationPermissionPrompt(
    onYes: @escaping () async -> Void,
    onNo: @escaping () async -> Void
  ) -> PlayolaAlert {
    PlayolaAlert(
      title: "Stay in the Loop?",
      message: "Allow the artists to notify you when they go live?",
      primaryButtonText: "Yes",
      primaryAction: onYes,
      secondaryButtonText: "No Thanks",
      secondaryAction: onNo
    )
  }
}
