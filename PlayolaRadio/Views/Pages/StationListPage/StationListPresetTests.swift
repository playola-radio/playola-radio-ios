//
//  StationListPresetTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct StationListPresetTests {

  // MARK: - Preset Loading Tests

  @Test
  func testViewAppearedLoadsPresets() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "user-1", firstName: "Bri", lastName: nil, email: "b@example.com",
        verifiedEmail: nil, profileImageUrl: nil, role: "user"),
      jwt: "fake-token"
    )
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    @Shared(.stationLists) var stationLists = StationList.mocks

    let returnedPresets = [Preset.mockPlayola(id: "p1"), Preset.mockUrl(id: "p2")]
    let capturedToken = LockIsolated<String?>(nil)

    let model = withDependencies {
      $0.api.getPresets = { token in
        capturedToken.setValue(token)
        return returnedPresets
      }
    } operation: {
      StationListModel()
    }

    await model.viewAppeared()

    #expect(capturedToken.value == "fake-token")
    expectNoDifference(Array(presets), returnedPresets)
  }

  // MARK: - isPreset

  @Test
  func testIsPresetReturnsTrueForExistingPreset() async {
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [
      Preset.mockPlayola(stationId: "playola-1")
    ]
    let model = StationListModel()
    #expect(model.isPreset(stationId: "playola-1"))
  }

  @Test
  func testIsPresetReturnsTrueForUrlStationPreset() async {
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [
      Preset.mockUrl(urlStationId: "url-1")
    ]
    let model = StationListModel()
    #expect(model.isPreset(stationId: "url-1"))
  }

  @Test
  func testIsPresetReturnsFalseForUnknownStation() async {
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    let model = StationListModel()
    #expect(!model.isPreset(stationId: "nope"))
  }

  @Test
  func testIsPresetReturnsTrueWhilePendingAdd() async {
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    @Shared(.pendingPresetStationIds) var pending: Set<String> = ["playola-2"]
    let model = StationListModel()
    #expect(model.isPreset(stationId: "playola-2"))
  }

  // MARK: - displayPresets

  @Test
  func testDisplayPresetsOrdersByPosition() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let station1 = Station.mockWith(id: "s1", name: "S1")
    let station2 = Station.mockWith(id: "s2", name: "S2")
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [
      makePresetTestList(with: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
      ])
    ]
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [
      Preset.mockPlayola(id: "p2", stationId: "s2", position: 1),
      Preset.mockPlayola(id: "p1", stationId: "s1", position: 0),
    ]

    let model = StationListModel()
    let items = model.displayPresets

    expectNoDifference(items.map(\.id), ["p1", "p2"])
    #expect(items.allSatisfy { !$0.isPending })
  }

  @Test
  func testDisplayPresetsFiltersOrphans() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let station1 = Station.mockWith(id: "s1", name: "S1")
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [
      makePresetTestList(with: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil)
      ])
    ]
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [
      Preset.mockPlayola(id: "p1", stationId: "s1", position: 0),
      Preset.mockPlayola(id: "p-orphan", stationId: "gone", position: 1),
    ]

    let model = StationListModel()
    expectNoDifference(model.displayPresets.map(\.id), ["p1"])
  }

  // MARK: - Presets Segment

  @Test
  func testPresetsSegmentSelectedShowsOnlyCarousel() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.stationLists) var stationLists = StationList.mocks
    let model = StationListModel()
    await model.viewAppeared()

    await model.segmentSelected("Presets")

    #expect(model.selectedSegment == "Presets")
    #expect(model.stationListsForDisplay.isEmpty)
    #expect(model.showsPresetsSection)
    #expect(model.showsPresetsOnly)
  }

  @Test
  func testShowsPresetsSectionTrueOnAllSegment() async {
    @Shared(.stationLists) var stationLists = StationList.mocks
    let model = StationListModel()
    await model.viewAppeared()

    #expect(model.selectedSegment == "All")
    #expect(model.showsPresetsSection)
    #expect(!model.showsPresetsOnly)
  }

  @Test
  func testShowsPresetsSectionFalseOnOtherSegments() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.stationLists) var stationLists = StationList.mocks
    let visibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
    guard let first = visibleLists.first else {
      Issue.record("No visible lists")
      return
    }
    let model = StationListModel()
    await model.viewAppeared()

    await model.segmentSelected(first.title)

    #expect(!model.showsPresetsSection)
  }

  // MARK: - Star Tap — Add

  @Test
  func testStarTappedOnNonPresetAddsOptimisticallyThenPersists() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "u1", firstName: "B", lastName: nil, email: "b@x.com",
        verifiedEmail: nil, profileImageUrl: nil, role: "user"),
      jwt: "t")
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    @Shared(.pendingPresetStationIds) var pending: Set<String> = []

    let item = makePresetVisibleItem()
    let stationId = item.anyStation.id

    let capturedCallArgs = LockIsolated<(String, String?, String?)?>(nil)
    let returnedPreset = Preset.mockPlayola(id: "new-preset", stationId: stationId, position: 0)

    let model = withDependencies {
      $0.api.createPreset = { token, sid, urlSid in
        capturedCallArgs.setValue((token, sid, urlSid))
        return returnedPreset
      }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(capturedCallArgs.value?.0 == "t")
    #expect(capturedCallArgs.value?.1 == stationId)
    #expect(capturedCallArgs.value?.2 == nil)
    #expect(pending.isEmpty)
    expectNoDifference(Array(presets), [returnedPreset])
  }

  @Test
  func testStarTappedAddFailureRollsBackAndShowsAlert() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "u1", firstName: "B", lastName: nil, email: "b@x.com",
        verifiedEmail: nil, profileImageUrl: nil, role: "user"),
      jwt: "t")
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    @Shared(.pendingPresetStationIds) var pending: Set<String> = []

    let item = makePresetVisibleItem()

    let model = withDependencies {
      $0.api.createPreset = { _, _, _ in
        throw APIError.validationError("server says no")
      }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(pending.isEmpty)
    #expect(presets.isEmpty)
    #expect(model.presentedAlert == .errorSavingPreset)
  }

  @Test
  func testStarTappedIgnoredWhilePendingAdd() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "u1", firstName: "B", lastName: nil, email: "b@x.com",
        verifiedEmail: nil, profileImageUrl: nil, role: "user"),
      jwt: "t")
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    let item = makePresetVisibleItem()
    @Shared(.pendingPresetStationIds) var pending: Set<String> = [item.anyStation.id]

    let callCount = LockIsolated(0)
    let model = withDependencies {
      $0.api.createPreset = { _, _, _ in
        callCount.setValue(callCount.value + 1)
        return Preset.mockPlayola()
      }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(callCount.value == 0)
  }

  @Test
  func testStarTappedTracksPresetAddedAnalyticsOnSuccess() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "u1", firstName: "B", lastName: nil, email: "b@x.com",
        verifiedEmail: nil, profileImageUrl: nil, role: "user"),
      jwt: "t")
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []

    let item = makePresetVisibleItem()
    let stationId = item.anyStation.id
    let captured = LockIsolated<[AnalyticsEvent]>([])

    let model = withDependencies {
      $0.api.createPreset = { _, _, _ in
        Preset.mockPlayola(stationId: stationId)
      }
      $0.analytics.track = { event in
        captured.withValue { $0.append(event) }
      }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    let added = captured.value.contains {
      if case .presetAdded(let info) = $0, info.id == stationId { return true }
      return false
    }
    #expect(added)
  }

  @Test
  func testDisplayPresetsAppendsPendingAddAsGhostTile() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let station1 = Station.mockWith(id: "s1", name: "S1")
    let station2 = Station.mockWith(id: "s2", name: "S2")
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [
      makePresetTestList(with: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
      ])
    ]
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [
      Preset.mockPlayola(id: "p1", stationId: "s1", position: 0)
    ]
    @Shared(.pendingPresetStationIds) var pending: Set<String> = ["s2"]

    let model = StationListModel()
    let items = model.displayPresets

    expectNoDifference(items.map(\.id), ["p1", "pending-s2"])
    expectNoDifference(items.map(\.isPending), [false, true])
    #expect(items[1].stationItem.anyStation.id == "s2")
  }

  // MARK: - Star Tap — Remove

  @Test
  func testStarTappedOnExistingPresetRemovesOptimistically() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "u1", firstName: "B", lastName: nil, email: "b@x.com",
        verifiedEmail: nil, profileImageUrl: nil, role: "user"),
      jwt: "t")
    let item = makePresetVisibleItem()
    let stationId = item.anyStation.id
    let presetToRemove = Preset.mockPlayola(id: "p-remove", stationId: stationId, position: 0)
    let otherPreset = Preset.mockPlayola(id: "p-keep", stationId: "other-s", position: 1)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [presetToRemove, otherPreset]
    @Shared(.pendingPresetRemovalIds) var pendingRemovals: Set<String> = []

    let capturedArgs = LockIsolated<(String, String)?>(nil)
    let model = withDependencies {
      $0.api.deletePreset = { token, presetId in
        capturedArgs.setValue((token, presetId))
      }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(capturedArgs.value?.0 == "t")
    #expect(capturedArgs.value?.1 == "p-remove")
    #expect(pendingRemovals.isEmpty)
    #expect(presets.count == 1)
    #expect(presets.first?.id == "p-keep")
    #expect(presets.first?.position == 0)  // gap closed
  }

  @Test
  func testRemovePresetFailureRestoresPresetAndPositions() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "u1", firstName: "B", lastName: nil, email: "b@x.com",
        verifiedEmail: nil, profileImageUrl: nil, role: "user"),
      jwt: "t")
    let item = makePresetVisibleItem()
    let stationId = item.anyStation.id
    let presetToRemove = Preset.mockPlayola(id: "p-remove", stationId: stationId, position: 0)
    let otherPreset = Preset.mockPlayola(id: "p-keep", stationId: "other-s", position: 1)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [presetToRemove, otherPreset]

    let model = withDependencies {
      $0.api.deletePreset = { _, _ in
        throw APIError.validationError("nope")
      }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(presets.count == 2)
    #expect(presets[id: "p-remove"]?.position == 0)
    #expect(presets[id: "p-keep"]?.position == 1)
    #expect(model.presentedAlert == .errorRemovingPreset)
  }

  @Test
  func testStarTappedIgnoredWhilePendingRemoval() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "u1", firstName: "B", lastName: nil, email: "b@x.com",
        verifiedEmail: nil, profileImageUrl: nil, role: "user"),
      jwt: "t")
    let item = makePresetVisibleItem()
    let stationId = item.anyStation.id
    let preset = Preset.mockPlayola(id: "p1", stationId: stationId, position: 0)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [preset]
    @Shared(.pendingPresetRemovalIds) var pendingRemovals: Set<String> = ["p1"]

    let callCount = LockIsolated(0)
    let model = withDependencies {
      $0.api.deletePreset = { _, _ in
        callCount.setValue(callCount.value + 1)
      }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(callCount.value == 0)
  }

  @Test
  func testRemovePresetTracksPresetRemovedAnalytics() async {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(
        id: "u1", firstName: "B", lastName: nil, email: "b@x.com",
        verifiedEmail: nil, profileImageUrl: nil, role: "user"),
      jwt: "t")
    let item = makePresetVisibleItem()
    let stationId = item.anyStation.id
    let preset = Preset.mockPlayola(id: "p1", stationId: stationId, position: 0)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [preset]

    let captured = LockIsolated<[AnalyticsEvent]>([])
    let model = withDependencies {
      $0.api.deletePreset = { _, _ in }
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    let removed = captured.value.contains {
      if case .presetRemoved(let info) = $0, info.id == stationId { return true }
      return false
    }
    #expect(removed)
  }
}

private func makePresetTestList(with items: [APIStationItem], date: Date = Date()) -> StationList {
  StationList(
    id: "preset-test-list",
    name: "Test List",
    slug: "preset-test-list",
    hidden: false,
    sortOrder: 0,
    createdAt: date,
    updatedAt: date,
    items: items
  )
}

private func makePresetVisibleItem(date: Date = Date()) -> APIStationItem {
  let station = PlayolaPlayer.Station(
    id: "playable-station",
    name: "Moondog Radio",
    curatorName: "Jacob Stelly",
    imageUrl: URL(string: "https://example.com/moondog.png"),
    description: "A playable station",
    active: true,
    createdAt: date,
    updatedAt: date
  )
  return APIStationItem(sortOrder: 0, visibility: .visible, station: station, urlStation: nil)
}
