//
//  PresetsModel.swift
//  PlayolaRadio
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

@MainActor
@Observable
final class PresetsModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.errorReporting) var errorReporting

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool
  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
  @ObservationIgnored @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
  @ObservationIgnored @Shared(.pendingPresetStationIds) var pendingPresetStationIds: Set<String> =
    []
  @ObservationIgnored @Shared(.pendingPresetRemovalStationIds)
  var pendingPresetRemovalStationIds: Set<String> = []

  // MARK: - Properties

  var presentedAlert: PlayolaAlert?
  var presetListState: PresetListState = .normal
  var isLoadingPresets: Bool = false
  var presetsLoadFailed: Bool = false
  let presetsSectionTitle = "Presets"
  let presetsEmptyStateText = "Tap the ★ on any station to save it here."
  let presetsEditDoneButtonText = "Done"
  let presetsLoadErrorText = "Couldn't load presets."
  let presetsRetryButtonText = "Retry"

  @ObservationIgnored private var hasLoadedPresets = false
  @ObservationIgnored private var lastJWT: String?
  @ObservationIgnored private var authCancellable: AnyCancellable?

  // MARK: - Initialization

  override init() {
    super.init()
    setupAuthObserver()
  }

  // MARK: - User Actions

  func loadPresetsIfNeeded() async {
    guard !hasLoadedPresets, !isLoadingPresets else { return }
    await loadPresets()
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
      $pendingPresetStationIds.withLock { _ = $0.remove(stationId) }
      $presets.withLock { _ = $0.append(created) }
      await analytics.track(.presetAdded(station: stationInfo))
    } catch {
      $pendingPresetStationIds.withLock { _ = $0.remove(stationId) }
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
      $pendingPresetRemovalStationIds.withLock { _ = $0.remove(stationId) }
      if let stationInfo {
        await analytics.track(.presetRemoved(station: stationInfo))
      }
    } catch {
      $pendingPresetRemovalStationIds.withLock { _ = $0.remove(stationId) }
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

  // Presets are per-account. Mirror LikesManager: force a refetch when the JWT
  // changes and clear the shared collection on sign-out, so a second user who
  // signs in without restarting never sees the first user's presets.
  private func setupAuthObserver() {
    authCancellable =
      $auth.publisher
      .sink { [weak self] newAuth in
        Task { @MainActor [weak self] in
          await self?.handleAuthChange(newAuth)
        }
      }
  }

  private func handleAuthChange(_ newAuth: Auth) async {
    let newJWT = newAuth.jwt
    guard newJWT != lastJWT else { return }
    let hadJWT = lastJWT != nil
    lastJWT = newJWT
    // Force the next loadPresetsIfNeeded to refetch for the new auth state.
    hasLoadedPresets = false
    if newJWT == nil && hadJWT {
      $presets.withLock { $0.removeAll() }
      $pendingPresetStationIds.withLock { $0.removeAll() }
      $pendingPresetRemovalStationIds.withLock { $0.removeAll() }
    }
  }

  private func loadPresets() async {
    guard let token = auth.jwt else { return }
    isLoadingPresets = true
    defer { isLoadingPresets = false }
    do {
      let fetched = try await api.getPresets(token)
      // The account may have changed during the await; only commit a response
      // that still matches the current JWT so one user's presets never land in
      // another user's session.
      guard auth.jwt == token else { return }
      $presets.withLock { $0 = IdentifiedArray(uniqueElements: fetched) }
      presetsLoadFailed = false
      hasLoadedPresets = true
    } catch {
      presetsLoadFailed = true
      await reportPresetError(error, endpoint: "GET /v1/presets")
    }
  }
}
