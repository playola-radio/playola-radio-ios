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

struct DisplayedStationSection: Identifiable {
  let id: String
  let title: String
  let rows: [Row]

  struct Row: Identifiable {
    let item: APIStationItem
    let liveStatus: LiveStatus?
    let hasUpcomingGiveaway: Bool
    var id: String { item.anyStation.id }
  }
}

@MainActor
@Observable
class StationListModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.pushNotifications) var pushNotifications
  @ObservationIgnored @Dependency(\.stationPlayer) var stationPlayer

  // MARK: - Shared State

  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
  @ObservationIgnored @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
  @ObservationIgnored @Shared(.upcomingGiveaways)
  var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = []
  @ObservationIgnored @Shared(.hasAskedForNotificationPermission)
  var hasAskedForNotificationPermission: Bool
  @ObservationIgnored @Shared(.welcomeMessageEligible) var welcomeMessageEligible: Bool = false
  @ObservationIgnored @Shared(.welcomeMessageShownThisSession)
  var welcomeMessageShownThisSession: Bool = false
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Properties

  let presetsModel: PresetsModel

  @ObservationIgnored var cancellables = Set<AnyCancellable>()
  var stationListsForDisplay: IdentifiedArrayOf<StationList> = []
  var displayedSections: [DisplayedStationSection] = []
  var segmentTitles: [String] = ["All"]
  var selectedSegment = "All"
  var searchText = ""
  var presentedAlert: PlayolaAlert?
  let navigationTitle = "Radio Stations"
  let suggestArtistButtonText = "Suggest Station"
  let searchBarPlaceholder = "Search stations"
  let noResultsIconName = "music.note.list"
  let noResultsMessage = "No stations found"
  let noResultsHint = "Try a different search, or tap Suggest Station to request one."
  let presetsSegmentTitle = "Presets"

  // MARK: - Initialization

  init(presetsModel: PresetsModel = PresetsModel()) {
    self.presetsModel = presetsModel
    super.init()
  }

  // MARK: - User Actions

  func viewAppeared() async {
    await presetsModel.loadPresetsIfNeeded()
    loadStationListsForDisplay(stationLists)

    if cancellables.isEmpty {
      $stationLists.publisher
        .sink { [weak self] lists in
          self?.loadStationListsForDisplay(lists)
        }
        .store(in: &cancellables)

      $liveStations.publisher
        .sink { [weak self] liveStations in
          guard let self else { return }
          self.loadStationListsForDisplay(self.stationLists, liveStations: liveStations)
        }
        .store(in: &cancellables)

      $upcomingGiveaways.publisher
        .sink { [weak self] upcomingGiveaways in
          guard let self else { return }
          self.loadStationListsForDisplay(
            self.stationLists, upcomingGiveaways: upcomingGiveaways)
        }
        .store(in: &cancellables)
    }

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
    searchText = ""
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

  func presetTileTapped(_ display: PresetDisplayItem) async {
    guard !presetsModel.isEditingPresets else { return }
    let position = presetsModel.displayPresets.firstIndex(where: { $0.id == display.id }) ?? 0
    await analytics.track(
      .presetTileTapped(
        station: StationInfo(from: display.stationItem.anyStation),
        position: position
      ))
    await stationSelected(display.stationItem)
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

    if shouldShowWelcomeMessage(for: item) {
      presentWelcomeMessage(for: station)
      return
    }

    await analytics.track(
      .startedStation(
        station: StationInfo(from: station),
        entryPoint: "station_list"
      ))

    await stationPlayer.play(station: station)
  }

  private func shouldShowWelcomeMessage(for item: APIStationItem) -> Bool {
    WelcomeMessagePageModel.shouldPresent(
      for: item,
      eligible: welcomeMessageEligible,
      alreadyShownThisSession: welcomeMessageShownThisSession)
  }

  // The server "seen" stamp happens in WelcomeMessagePageModel once the recording actually
  // plays — a fetch/playback failure must not burn the user's one welcome. The session flag
  // here still prevents repeat presentations this launch.
  private func presentWelcomeMessage(for station: AnyStation) {
    $welcomeMessageShownThisSession.withLock { $0 = true }
    mainContainerNavigationCoordinator.presentedSheet = .welcomeMessage(
      WelcomeMessagePageModel(station: station))
  }

  // MARK: - View Helpers

  var showsPresetsSection: Bool {
    selectedSegment == "All" || selectedSegment == presetsSegmentTitle
  }

  var showsPresetsOnly: Bool {
    selectedSegment == presetsSegmentTitle
  }

  var isShowingNoResults: Bool {
    guard !searchText.isEmpty else { return false }
    return stationListsForDisplay.allSatisfy { list in
      sortedStationItems(for: list).isEmpty
    }
  }

  func sortedStationItems(for list: StationList) -> [APIStationItem] {
    liveSortedStationItems(for: list, liveStations: liveStations).filter(matchesSearch)
  }

  func displayedRows(for section: DisplayedStationSection) -> [DisplayedStationSection.Row] {
    section.rows.filter { matchesSearch($0.item) }
  }

  private func liveSortedStationItems(
    for list: StationList,
    liveStations: [LiveStationInfo]
  ) -> [APIStationItem] {
    list.stationItems(includeHidden: showSecretStations).sorted { item1, item2 in
      item1.liveSortPriority(liveStations) < item2.liveSortPriority(liveStations)
    }
  }

  private func matchesSearch(_ item: APIStationItem) -> Bool {
    guard !searchText.isEmpty else { return true }
    let station = item.anyStation
    return station.name.localizedCaseInsensitiveContains(searchText)
      || station.stationName.localizedCaseInsensitiveContains(searchText)
  }

  // MARK: - Private Helpers

  private func loadStationListsForDisplay(
    _ rawList: IdentifiedArrayOf<StationList>,
    liveStations: [LiveStationInfo]? = nil,
    upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo>? = nil
  ) {
    let liveStations = liveStations ?? self.liveStations
    let upcomingGiveaways = upcomingGiveaways ?? self.upcomingGiveaways
    let includeHidden = showSecretStations
    let visibleLists = includeHidden ? rawList : rawList.filter { !$0.hidden }

    var titles = ["All", presetsSegmentTitle]
    titles.append(contentsOf: visibleLists.map { $0.title })
    segmentTitles = titles

    if !segmentTitles.contains(selectedSegment) {
      selectedSegment = "All"
    }

    if selectedSegment == "All" {
      stationListsForDisplay = visibleLists
    } else if selectedSegment == presetsSegmentTitle {
      stationListsForDisplay = []
    } else {
      stationListsForDisplay = visibleLists.filter { $0.title == selectedSegment }
    }

    displayedSections = stationListsForDisplay.map { list in
      DisplayedStationSection(
        id: list.id,
        title: list.title,
        rows: liveSortedStationItems(for: list, liveStations: liveStations).map { item in
          let liveStatus = liveStations.first { $0.stationId == item.anyStation.id }?.liveStatus
          return DisplayedStationSection.Row(
            item: item,
            liveStatus: liveStatus,
            hasUpcomingGiveaway: liveStatus != nil
              && upcomingGiveaways[id: item.anyStation.id] != nil
          )
        }
      )
    }
  }
}
