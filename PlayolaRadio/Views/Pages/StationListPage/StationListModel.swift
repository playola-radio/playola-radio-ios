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

struct PresetDisplayItem: Identifiable {
  let id: String
  let stationItem: APIStationItem
  let isPending: Bool
  let title: String
  let imageUrl: URL?
  let subtitleText: String?
  let subtitleColor: Color?
  let accessibilityLabel: String
  let removeAccessibilityLabel: String

  init(
    id: String, stationItem: APIStationItem, isPending: Bool, showSecretStations: Bool = false
  ) {
    self.id = id
    self.stationItem = stationItem
    self.isPending = isPending

    let station = stationItem.anyStation
    let title = station.name
    self.title = title
    self.imageUrl = station.imageUrl
    self.accessibilityLabel = "Preset: \(title)"
    self.removeAccessibilityLabel = "Remove \(title) from presets"

    let isInactive = !station.active
    let isComingSoonAndHidden = stationItem.visibility == .comingSoon && !showSecretStations
    if isInactive || isComingSoonAndHidden {
      self.subtitleText = "Coming Soon"
      self.subtitleColor = Color.playolaRed
    } else {
      self.subtitleText = nil
      self.subtitleColor = nil
    }
  }
}

enum PresetListState: Equatable {
  case normal
  case editing
}

struct DisplayedStationSection: Identifiable {
  let id: String
  let title: String
  let rows: [Row]

  struct Row: Identifiable {
    let item: APIStationItem
    let liveStatus: LiveStatus?
    var id: String { item.anyStation.id }
  }
}

@MainActor
@Observable
class StationListModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.errorReporting) var errorReporting
  @ObservationIgnored @Dependency(\.pushNotifications) var pushNotifications
  @ObservationIgnored @Dependency(\.stationPlayer) var stationPlayer

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
  @ObservationIgnored @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
  @ObservationIgnored @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
  @ObservationIgnored @Shared(.pendingPresetStationIds) var pendingPresetStationIds: Set<String> =
    []
  @ObservationIgnored @Shared(.pendingPresetRemovalStationIds)
  var pendingPresetRemovalStationIds: Set<String> = []
  @ObservationIgnored @Shared(.hasAskedForNotificationPermission)
  var hasAskedForNotificationPermission: Bool
  @ObservationIgnored @Shared(.welcomeMessageEligible) var welcomeMessageEligible: Bool = false
  @ObservationIgnored @Shared(.welcomeMessageShownThisSession)
  var welcomeMessageShownThisSession: Bool = false
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Properties

  @ObservationIgnored var cancellables = Set<AnyCancellable>()
  var stationListsForDisplay: IdentifiedArrayOf<StationList> = []
  var displayedSections: [DisplayedStationSection] = []
  var segmentTitles: [String] = ["All"]
  var selectedSegment = "All"
  var searchText = ""
  var presentedAlert: PlayolaAlert?
  var presetListState: PresetListState = .normal
  var isLoadingPresets: Bool = false
  var presetsLoadFailed: Bool = false
  let navigationTitle = "Radio Stations"
  let suggestArtistButtonText = "Suggest Station"
  let searchBarPlaceholder = "Search stations"
  let noResultsIconName = "music.note.list"
  let noResultsMessage = "No stations found"
  let noResultsHint = "Try a different search, or tap Suggest Station to request one."
  let presetsSegmentTitle = "Presets"
  let presetsSectionTitle = "Presets"
  let presetsEmptyStateText = "Tap the ★ on any station to save it here."
  let presetsEditDoneButtonText = "Done"
  let presetsLoadErrorText = "Couldn't load presets."
  let presetsRetryButtonText = "Retry"

  // MARK: - User Actions

  func viewAppeared() async {
    await loadPresets()
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

  func starTapped(for item: APIStationItem) async {
    let stationId = item.anyStation.id

    if let existing = presets.first(where: { $0.embeddedStationId == stationId }) {
      await removePreset(presetId: existing.id, stationInfo: StationInfo(from: item.anyStation))
      return
    }

    if pendingPresetStationIds.contains(stationId)
      || pendingPresetRemovalStationIds.contains(stationId)
    {
      return
    }

    await addPreset(for: item)
  }

  // swiftlint:disable:next cyclomatic_complexity
  func presetMoved(presetId: String, to: Int) async {
    guard presetListState == .editing else { return }
    guard let token = auth.jwt else { return }
    guard presets[id: presetId] != nil else { return }

    let displayIds = displayPresets.map(\.id)
    guard let fromIndex = displayIds.firstIndex(of: presetId) else { return }
    guard fromIndex != to else { return }

    let snapshot: [String: Int] = Dictionary(
      uniqueKeysWithValues: presets.map { ($0.id, $0.position) })

    var orderedIds = displayIds.filter { presets[id: $0] != nil }
    guard let oldIndex = orderedIds.firstIndex(of: presetId) else { return }
    orderedIds.remove(at: oldIndex)
    let clampedTo = min(max(0, to), orderedIds.count)
    orderedIds.insert(presetId, at: clampedTo)

    $presets.withLock { collection in
      for (index, id) in orderedIds.enumerated() {
        if var preset = collection[id: id] {
          preset.position = index
          collection[id: id] = preset
        }
      }
    }

    let movedStationInfo: StationInfo? = {
      guard let item = displayPresets.first(where: { $0.id == presetId })?.stationItem
      else { return nil }
      return StationInfo(from: item.anyStation)
    }()

    do {
      _ = try await api.movePreset(token, presetId, clampedTo)
      if let info = movedStationInfo {
        await analytics.track(
          .presetMoved(station: info, fromIndex: fromIndex, toIndex: clampedTo))
      }
    } catch {
      $presets.withLock { collection in
        for var preset in collection {
          if let original = snapshot[preset.id] {
            preset.position = original
            collection[id: preset.id] = preset
          }
        }
      }
      await reportPresetError(
        error,
        endpoint: "PUT /v1/presets/\(presetId)",
        extraTags: ["preset_id": presetId])
      presentedAlert = .errorMovingPreset
    }
  }

  func presetTileTapped(_ display: PresetDisplayItem) async {
    guard presetListState == .normal else { return }
    let position = displayPresets.firstIndex(where: { $0.id == display.id }) ?? 0
    await analytics.track(
      .presetTileTapped(
        station: StationInfo(from: display.stationItem.anyStation),
        position: position
      ))
    await stationSelected(display.stationItem)
  }

  func presetTileLongPressed(_ display: PresetDisplayItem) {
    guard !display.isPending else { return }
    presetListState = .editing
  }

  func presetRemoveTapped(_ display: PresetDisplayItem) async {
    guard !display.isPending,
      let preset = presets[id: display.id]
    else { return }

    let allItems = stationLists.flatMap { $0.stationItems(includeHidden: showSecretStations) }
    let stationInfo: StationInfo? =
      allItems
      .first(where: { $0.anyStation.id == preset.embeddedStationId })
      .map { StationInfo(from: $0.anyStation) }

    await removePreset(presetId: preset.id, stationInfo: stationInfo)
  }

  func presetsEditDoneTapped() {
    presetListState = .normal
  }

  func backgroundTappedOutsidePresets() {
    if presetListState == .editing { presetListState = .normal }
  }

  func retryLoadPresetsTapped() async {
    await loadPresets()
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

  var isEditingPresets: Bool { presetListState == .editing }

  var displayPresets: [PresetDisplayItem] {
    let allItems = stationLists.flatMap { $0.stationItems(includeHidden: showSecretStations) }

    let real: [PresetDisplayItem] =
      presets
      .sorted { $0.position < $1.position }
      .compactMap { preset in
        guard let item = allItems.first(where: { $0.anyStation.id == preset.embeddedStationId })
        else { return nil }
        return PresetDisplayItem(
          id: preset.id, stationItem: item, isPending: false,
          showSecretStations: showSecretStations)
      }

    let realStationIds = Set(presets.map { $0.embeddedStationId })
    let pending: [PresetDisplayItem] =
      pendingPresetStationIds
      .subtracting(realStationIds)
      .compactMap { stationId -> PresetDisplayItem? in
        guard let item = allItems.first(where: { $0.anyStation.id == stationId })
        else { return nil }
        return PresetDisplayItem(
          id: "pending-\(stationId)",
          stationItem: item,
          isPending: true,
          showSecretStations: showSecretStations
        )
      }
      .sorted { $0.id < $1.id }

    return real + pending
  }

  func isPreset(stationId: String) -> Bool {
    pendingPresetStationIds.contains(stationId)
      || presets.contains { $0.embeddedStationId == stationId }
  }

  func presetStarAccessibilityLabel(isPreset: Bool, stationName: String) -> String {
    isPreset ? "Remove \(stationName) from presets" : "Add \(stationName) to presets"
  }

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

  private func reportPresetError(
    _ error: Error,
    endpoint: String,
    extraTags: [String: String] = [:]
  ) async {
    print("\(endpoint) failed: \(error)")
    await analytics.track(
      .apiError(endpoint: endpoint, error: error.localizedDescription))
    if !NetworkErrorClassifier.isNetworkError(error) {
      var tags = extraTags
      tags["endpoint"] = endpoint
      tags.merge(NetworkErrorClassifier.errorTags(for: error)) { _, new in new }
      await errorReporting.reportError(error, tags)
    }
  }

  private func serverMessage(from error: Error) -> String? {
    if case APIError.validationError(let message) = error { return message }
    return nil
  }

  private func addPreset(for item: APIStationItem) async {
    guard let token = auth.jwt else { return }
    let stationId = item.anyStation.id
    let stationInfo = StationInfo(from: item.anyStation)
    let isPlayola = item.station != nil

    $pendingPresetStationIds.withLock { _ = $0.insert(stationId) }

    do {
      let created = try await api.createPreset(
        token,
        isPlayola ? stationId : nil,
        isPlayola ? nil : stationId
      )
      $pendingPresetStationIds.withLock { $0.remove(stationId) }
      $presets.withLock { $0.append(created) }
      await analytics.track(.presetAdded(station: stationInfo))
    } catch {
      $pendingPresetStationIds.withLock { $0.remove(stationId) }
      await reportPresetError(
        error,
        endpoint: "POST /v1/presets",
        extraTags: [
          "station_id": stationId,
          "station_type": isPlayola ? "playola" : "url",
        ])
      presentedAlert = .errorSavingPreset(serverMessage(from: error))
    }
  }

  private func removePreset(presetId: String, stationInfo: StationInfo?) async {
    guard let token = auth.jwt else { return }
    guard let presetSnapshot = presets[id: presetId] else { return }
    let stationId = presetSnapshot.embeddedStationId
    if pendingPresetRemovalStationIds.contains(stationId) { return }

    let positionsSnapshot: [String: Int] = Dictionary(
      uniqueKeysWithValues: presets.map { ($0.id, $0.position) })

    $pendingPresetRemovalStationIds.withLock { _ = $0.insert(stationId) }
    $presets.withLock { collection in
      collection.remove(id: presetId)
      for var existing in collection where existing.position > presetSnapshot.position {
        existing.position -= 1
        collection[id: existing.id] = existing
      }
    }

    do {
      try await api.deletePreset(token, presetId)
      $pendingPresetRemovalStationIds.withLock { $0.remove(stationId) }
      if let stationInfo {
        await analytics.track(.presetRemoved(station: stationInfo))
      }
    } catch {
      $pendingPresetRemovalStationIds.withLock { $0.remove(stationId) }
      $presets.withLock { collection in
        collection.append(presetSnapshot)
        for var existing in collection {
          if let original = positionsSnapshot[existing.id] {
            existing.position = original
            collection[id: existing.id] = existing
          }
        }
      }
      await reportPresetError(
        error,
        endpoint: "DELETE /v1/presets/\(presetId)",
        extraTags: ["preset_id": presetId])
      presentedAlert = .errorRemovingPreset
    }
  }

  private func loadPresets() async {
    guard let token = auth.jwt else { return }
    isLoadingPresets = true
    defer { isLoadingPresets = false }
    do {
      let fetched = try await api.getPresets(token)
      $presets.withLock { $0 = IdentifiedArray(uniqueElements: fetched) }
      presetsLoadFailed = false
    } catch {
      presetsLoadFailed = true
      await reportPresetError(error, endpoint: "GET /v1/presets")
    }
  }

  private func loadStationListsForDisplay(
    _ rawList: IdentifiedArrayOf<StationList>,
    liveStations: [LiveStationInfo]? = nil
  ) {
    let liveStations = liveStations ?? self.liveStations
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
          DisplayedStationSection.Row(
            item: item,
            liveStatus: liveStations.first { $0.stationId == item.anyStation.id }?.liveStatus
          )
        }
      )
    }
  }
}
