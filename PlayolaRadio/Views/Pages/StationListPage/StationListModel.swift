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
}

@MainActor
@Observable
class StationListModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.api) var api
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
  @ObservationIgnored @Shared(.pendingPresetRemovalIds) var pendingPresetRemovalIds: Set<String> =
    []
  @ObservationIgnored @Shared(.hasAskedForNotificationPermission)
  var hasAskedForNotificationPermission: Bool
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Properties

  var cancellables = Set<AnyCancellable>()
  var stationListsForDisplay: IdentifiedArrayOf<StationList> = []
  var segmentTitles: [String] = ["All"]
  var selectedSegment = "All"
  var searchText = ""
  var presentedAlert: PlayolaAlert?
  var presentedPresetActionSheetPreset: Preset?
  let navigationTitle = "Radio Stations"
  let suggestArtistButtonText = "Suggest Station"
  let searchBarPlaceholder = "Search stations"
  let noResultsIconName = "music.note.list"
  let noResultsMessage = "No stations found"
  let noResultsHint = "Try a different search, or tap Suggest Station to request one."
  let presetsSegmentTitle = "Presets"
  let presetsSectionTitle = "Presets"
  let presetsEmptyStateText = "Tap the ★ on any station to save it here."

  // MARK: - User Actions

  func viewAppeared() async {
    await loadPresets()

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
      || pendingPresetRemovalIds.contains(where: { id in
        presets[id: id]?.embeddedStationId == stationId
      })
    {
      return
    }

    await addPreset(for: item)
  }

  func presetMoved(from: Int, to: Int) async {
    guard from != to else { return }
    guard let token = auth.jwt else { return }

    let snapshot: [String: Int] = Dictionary(
      uniqueKeysWithValues: presets.map { ($0.id, $0.position) })

    let displayIds = displayPresets.map(\.id)
    guard from >= 0, from < displayIds.count, to >= 0, to < displayIds.count
    else { return }
    let movedId = displayIds[from]
    guard presets[id: movedId] != nil else { return }

    var orderedIds = displayIds.filter { presets[id: $0] != nil }
    guard let oldIndex = orderedIds.firstIndex(of: movedId) else { return }
    orderedIds.remove(at: oldIndex)
    let clampedTo = min(max(0, to), orderedIds.count)
    orderedIds.insert(movedId, at: clampedTo)

    $presets.withLock { collection in
      for (index, id) in orderedIds.enumerated() {
        if var preset = collection[id: id] {
          preset.position = index
          collection[id: id] = preset
        }
      }
    }

    let movedStationInfo: StationInfo? = {
      guard let item = displayPresets.first(where: { $0.id == movedId })?.stationItem
      else { return nil }
      return StationInfo(from: item.anyStation)
    }()

    do {
      _ = try await api.movePreset(token, movedId, clampedTo)
      if let info = movedStationInfo {
        await analytics.track(.presetMoved(station: info, fromIndex: from, toIndex: clampedTo))
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
      presentedAlert = .errorMovingPreset
    }
  }

  func presetTileTapped(_ display: PresetDisplayItem) async {
    let position = displayPresets.firstIndex(where: { $0.id == display.id }) ?? 0
    await analytics.track(
      .presetTileTapped(
        station: StationInfo(from: display.stationItem.anyStation),
        position: position
      ))
    await stationSelected(display.stationItem)
  }

  func presetTileLongPressed(_ display: PresetDisplayItem) {
    guard !display.isPending,
      let preset = presets[id: display.id]
    else { return }
    presentedPresetActionSheetPreset = preset
  }

  func removePresetTapped(_ preset: Preset) async {
    let stationInfo: StationInfo? = {
      let allItems = stationLists.flatMap { $0.stationItems(includeHidden: showSecretStations) }
      guard let item = allItems.first(where: { $0.anyStation.id == preset.embeddedStationId })
      else { return nil }
      return StationInfo(from: item.anyStation)
    }()

    presentedPresetActionSheetPreset = nil
    await removePreset(
      presetId: preset.id,
      stationInfo: stationInfo
        ?? StationInfo(
          from: .playola(Station.mockWith(id: preset.embeddedStationId))))
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

    await stationPlayer.play(station: station)
  }

  // MARK: - View Helpers

  var displayPresets: [PresetDisplayItem] {
    let allItems = stationLists.flatMap { $0.stationItems(includeHidden: showSecretStations) }

    let real: [PresetDisplayItem] =
      presets
      .sorted { $0.position < $1.position }
      .compactMap { preset in
        guard let item = allItems.first(where: { $0.anyStation.id == preset.embeddedStationId })
        else { return nil }
        return PresetDisplayItem(id: preset.id, stationItem: item, isPending: false)
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
          isPending: true
        )
      }
      .sorted { $0.id < $1.id }

    return real + pending
  }

  func isPreset(stationId: String) -> Bool {
    pendingPresetStationIds.contains(stationId)
      || presets.contains { $0.embeddedStationId == stationId }
  }

  var showsPresetsSection: Bool {
    selectedSegment == "All" || selectedSegment == presetsSegmentTitle
  }

  var showsPresetsOnly: Bool {
    selectedSegment == presetsSegmentTitle
  }

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

  private func addPreset(for item: APIStationItem) async {
    guard let token = auth.jwt else { return }
    let stationId = item.anyStation.id
    let stationInfo = StationInfo(from: item.anyStation)
    let isPlayola = item.station != nil

    $pendingPresetStationIds.withLock { $0.insert(stationId) }

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
      presentedAlert = .errorSavingPreset
    }
  }

  private func removePreset(presetId: String, stationInfo: StationInfo) async {
    guard let token = auth.jwt else { return }
    if pendingPresetRemovalIds.contains(presetId) { return }

    guard let presetSnapshot = presets[id: presetId] else { return }
    let positionsSnapshot: [String: Int] = Dictionary(
      uniqueKeysWithValues: presets.map { ($0.id, $0.position) })

    $pendingPresetRemovalIds.withLock { $0.insert(presetId) }
    $presets.withLock { collection in
      collection.remove(id: presetId)
      for var existing in collection where existing.position > presetSnapshot.position {
        existing.position -= 1
        collection[id: existing.id] = existing
      }
    }

    do {
      try await api.deletePreset(token, presetId)
      $pendingPresetRemovalIds.withLock { $0.remove(presetId) }
      await analytics.track(.presetRemoved(station: stationInfo))
    } catch {
      $pendingPresetRemovalIds.withLock { $0.remove(presetId) }
      $presets.withLock { collection in
        collection.append(presetSnapshot)
        for var existing in collection {
          if let original = positionsSnapshot[existing.id] {
            existing.position = original
            collection[id: existing.id] = existing
          }
        }
      }
      presentedAlert = .errorRemovingPreset
    }
  }

  private func loadPresets() async {
    guard let token = auth.jwt else { return }
    do {
      let fetched = try await api.getPresets(token)
      $presets.withLock { $0 = IdentifiedArray(uniqueElements: fetched) }
    } catch {
    }
  }

  private func loadStationListsForDisplay(_ rawList: IdentifiedArrayOf<StationList>) {
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
