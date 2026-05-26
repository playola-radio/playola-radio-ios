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
    @Shared(.auth) var auth = signedInAuth()
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    @Shared(.pendingPresetStationIds) var pending: Set<String> = []

    let item = makePresetVisibleItem()
    let stationId = item.anyStation.id

    let capturedToken = LockIsolated<String?>(nil)
    let capturedStationId = LockIsolated<String?>(nil)
    let capturedUrlStationId = LockIsolated<String?>(nil)
    let returnedPreset = Preset.mockPlayola(id: "new-preset", stationId: stationId, position: 0)

    let model = withDependencies {
      $0.api.createPreset = { token, sid, urlSid in
        capturedToken.setValue(token)
        capturedStationId.setValue(sid)
        capturedUrlStationId.setValue(urlSid)
        return returnedPreset
      }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(capturedToken.value == "t")
    #expect(capturedStationId.value == stationId)
    #expect(capturedUrlStationId.value == nil)
    #expect(pending.isEmpty)
    expectNoDifference(Array(presets), [returnedPreset])
  }

  @Test
  func testStarTappedAddFailureRollsBackAndShowsAlert() async {
    @Shared(.auth) var auth = signedInAuth()
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    @Shared(.pendingPresetStationIds) var pending: Set<String> = []

    let item = makePresetVisibleItem()

    let model = withDependencies {
      $0.api.createPreset = { _, _, _ in
        throw APIError.validationError("server says no")
      }
      $0.analytics.track = { _ in }
      $0.errorReporting.reportError = { _, _ in }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(pending.isEmpty)
    #expect(presets.isEmpty)
    #expect(model.presentedAlert == .errorSavingPreset("server says no"))
  }

  @Test
  func testStarTappedIgnoredWhilePendingAdd() async {
    @Shared(.auth) var auth = signedInAuth()
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
    @Shared(.auth) var auth = signedInAuth()
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
    @Shared(.auth) var auth = signedInAuth()
    let item = makePresetVisibleItem()
    let stationId = item.anyStation.id
    let presetToRemove = Preset.mockPlayola(id: "p-remove", stationId: stationId, position: 0)
    let otherPreset = Preset.mockPlayola(id: "p-keep", stationId: "other-s", position: 1)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [presetToRemove, otherPreset]
    @Shared(.pendingPresetRemovalStationIds) var pendingRemovals: Set<String> = []

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
    expectNoDifference(
      Array(presets),
      [Preset.mockPlayola(id: "p-keep", stationId: "other-s", position: 0)])
  }

  @Test
  func testRemovePresetFailureRestoresPresetAndPositions() async {
    @Shared(.auth) var auth = signedInAuth()
    let item = makePresetVisibleItem()
    let stationId = item.anyStation.id
    let presetToRemove = Preset.mockPlayola(id: "p-remove", stationId: stationId, position: 0)
    let otherPreset = Preset.mockPlayola(id: "p-keep", stationId: "other-s", position: 1)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [presetToRemove, otherPreset]

    let model = withDependencies {
      $0.api.deletePreset = { _, _ in
        throw APIError.validationError("nope")
      }
      $0.analytics.track = { _ in }
      $0.errorReporting.reportError = { _, _ in }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    expectNoDifference(
      presets.sorted { $0.position < $1.position },
      [presetToRemove, otherPreset])
    #expect(model.presentedAlert == .errorRemovingPreset)
  }

  @Test
  func testStarTappedIgnoredWhileStationIsPendingRemoval() async {
    // Simulates the race: `removePreset` has optimistically removed the preset
    // from `$presets` but the DELETE is still in flight, so `presets` no longer
    // contains the entry. A concurrent `starTapped` would otherwise route to
    // `addPreset` and issue POST while DELETE is in flight. The station-id
    // guard must catch this even though no preset is in `presets`.
    @Shared(.auth) var auth = signedInAuth()
    let item = makePresetVisibleItem()
    let stationId = item.anyStation.id
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    @Shared(.pendingPresetRemovalStationIds) var pendingRemovals: Set<String> = [stationId]

    let createCallCount = LockIsolated(0)
    let deleteCallCount = LockIsolated(0)
    let model = withDependencies {
      $0.api.createPreset = { _, _, _ in
        createCallCount.setValue(createCallCount.value + 1)
        return Preset.mockPlayola()
      }
      $0.api.deletePreset = { _, _ in
        deleteCallCount.setValue(deleteCallCount.value + 1)
      }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(createCallCount.value == 0)
    #expect(deleteCallCount.value == 0)
  }

  @Test
  func testRemovePresetTracksPresetRemovedAnalytics() async {
    @Shared(.auth) var auth = signedInAuth()
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

  // MARK: - presetMoved

  @Test
  func testPresetMovedReassignsLocalPositionsAndCallsServer() async {
    @Shared(.auth) var auth = signedInAuth()
    let p1 = Preset.mockPlayola(id: "p1", stationId: "s1", position: 0)
    let p2 = Preset.mockPlayola(id: "p2", stationId: "s2", position: 1)
    let p3 = Preset.mockPlayola(id: "p3", stationId: "s3", position: 2)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [p1, p2, p3]

    let stationLists = IdentifiedArrayOf<StationList>(uniqueElements: [
      makePresetTestList(with: [
        APIStationItem(
          sortOrder: 0, visibility: .visible, station: Station.mockWith(id: "s1"), urlStation: nil),
        APIStationItem(
          sortOrder: 1, visibility: .visible, station: Station.mockWith(id: "s2"), urlStation: nil),
        APIStationItem(
          sortOrder: 2, visibility: .visible, station: Station.mockWith(id: "s3"), urlStation: nil),
      ])
    ])
    @Shared(.stationLists) var sharedLists = stationLists

    let capturedToken = LockIsolated<String?>(nil)
    let capturedPresetId = LockIsolated<String?>(nil)
    let capturedPosition = LockIsolated<Int?>(nil)
    let model = withDependencies {
      $0.api.movePreset = { token, presetId, position in
        capturedToken.setValue(token)
        capturedPresetId.setValue(presetId)
        capturedPosition.setValue(position)
        return Preset.mockPlayola(id: presetId, stationId: "s1", position: position)
      }
    } operation: {
      StationListModel()
    }
    model.presetListState = .editing

    await model.presetMoved(from: 0, to: 2)

    let ordered = presets.sorted { $0.position < $1.position }
    expectNoDifference(
      ordered,
      [
        Preset.mockPlayola(id: "p2", stationId: "s2", position: 0),
        Preset.mockPlayola(id: "p3", stationId: "s3", position: 1),
        Preset.mockPlayola(id: "p1", stationId: "s1", position: 2),
      ])
    #expect(capturedToken.value == "t")
    #expect(capturedPresetId.value == "p1")
    #expect(capturedPosition.value == 2)
  }

  @Test
  func testPresetMovedNoOpWhenFromEqualsTo() async {
    @Shared(.auth) var auth = signedInAuth()
    let p1 = Preset.mockPlayola(id: "p1", stationId: "s1", position: 0)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [p1]

    let callCount = LockIsolated(0)
    let model = withDependencies {
      $0.api.movePreset = { _, _, _ in
        callCount.setValue(callCount.value + 1)
        return p1
      }
    } operation: {
      StationListModel()
    }

    await model.presetMoved(from: 0, to: 0)

    #expect(callCount.value == 0)
  }

  @Test
  func testPresetMoveFailureRevertsToSnapshot() async {
    @Shared(.auth) var auth = signedInAuth()
    let p1 = Preset.mockPlayola(id: "p1", stationId: "s1", position: 0)
    let p2 = Preset.mockPlayola(id: "p2", stationId: "s2", position: 1)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [p1, p2]

    let stationLists = IdentifiedArrayOf<StationList>(uniqueElements: [
      makePresetTestList(with: [
        APIStationItem(
          sortOrder: 0, visibility: .visible, station: Station.mockWith(id: "s1"), urlStation: nil),
        APIStationItem(
          sortOrder: 1, visibility: .visible, station: Station.mockWith(id: "s2"), urlStation: nil),
      ])
    ])
    @Shared(.stationLists) var sharedLists = stationLists

    let model = withDependencies {
      $0.api.movePreset = { _, _, _ in throw APIError.validationError("nope") }
      $0.analytics.track = { _ in }
      $0.errorReporting.reportError = { _, _ in }
    } operation: {
      StationListModel()
    }
    model.presetListState = .editing

    await model.presetMoved(from: 0, to: 1)

    let ordered = presets.sorted { $0.position < $1.position }
    expectNoDifference(ordered, [p1, p2])
    #expect(model.presentedAlert == .errorMovingPreset)
  }

  // MARK: - Tile Tap / Long Press

  @Test
  func testPresetTileTappedPlaysStation() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let station = Station.mockWith(id: "s1", name: "S1")
    let item = APIStationItem(
      sortOrder: 0, visibility: .visible, station: station, urlStation: nil)
    let stationLists = IdentifiedArrayOf<StationList>(uniqueElements: [
      makePresetTestList(with: [item])
    ])
    @Shared(.stationLists) var sharedLists = stationLists

    let display = PresetDisplayItem(id: "p1", stationItem: item, isPending: false)

    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let captured = LockIsolated<[AnalyticsEvent]>([])

    let model = withDependencies {
      $0.stationPlayer = stationPlayerMock
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      StationListModel()
    }
    model.stationListsForDisplay = stationLists

    await model.presetTileTapped(display)

    #expect(stationPlayerMock.callsToPlay.first?.id == "s1")
    let tracked = captured.value.contains {
      if case .presetTileTapped = $0 { return true }
      return false
    }
    #expect(tracked)
  }

  @Test
  func testPresetTileLongPressedEntersEditMode() async {
    let preset = Preset.mockPlayola(id: "p1", stationId: "s1", position: 0)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [preset]
    let item = makePresetVisibleItem()
    let display = PresetDisplayItem(id: "p1", stationItem: item, isPending: false)

    let model = StationListModel()
    #expect(model.presetListState == .normal)

    model.presetTileLongPressed(display)

    #expect(model.presetListState == .editing)
    #expect(model.isEditingPresets)
  }

  @Test
  func testPresetTileLongPressIgnoredWhenPending() async {
    let item = makePresetVisibleItem()
    let display = PresetDisplayItem(id: "pending-x", stationItem: item, isPending: true)

    let model = StationListModel()
    model.presetTileLongPressed(display)

    #expect(model.presetListState == .normal)
  }

  // MARK: - Edit Mode

  @Test
  func testPresetListStateDefaultsToNormal() async {
    let model = StationListModel()
    #expect(model.presetListState == .normal)
    #expect(!model.isEditingPresets)
  }

  @Test
  func testPresetsEditDoneTappedExitsEditMode() async {
    let model = StationListModel()
    model.presetListState = .editing
    model.presetsEditDoneTapped()
    #expect(model.presetListState == .normal)
  }

  @Test
  func testBackgroundTappedExitsEditMode() async {
    let model = StationListModel()
    model.presetListState = .editing
    model.backgroundTappedOutsidePresets()
    #expect(model.presetListState == .normal)
  }

  @Test
  func testBackgroundTappedDoesNothingInNormalMode() async {
    let model = StationListModel()
    #expect(model.presetListState == .normal)
    model.backgroundTappedOutsidePresets()
    #expect(model.presetListState == .normal)
  }

  @Test
  func testPresetTileTappedNoOpInEditMode() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let station = Station.mockWith(id: "s1", name: "S1")
    let item = APIStationItem(
      sortOrder: 0, visibility: .visible, station: station, urlStation: nil)
    let stationLists = IdentifiedArrayOf<StationList>(uniqueElements: [
      makePresetTestList(with: [item])
    ])
    @Shared(.stationLists) var sharedLists = stationLists

    let display = PresetDisplayItem(id: "p1", stationItem: item, isPending: false)

    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()

    let model = withDependencies {
      $0.stationPlayer = stationPlayerMock
      $0.analytics.track = { _ in }
    } operation: {
      StationListModel()
    }
    model.presetListState = .editing

    await model.presetTileTapped(display)

    #expect(stationPlayerMock.callsToPlay.isEmpty)
  }

  @Test
  func testPresetRemoveTappedRemovesPreset() async {
    @Shared(.auth) var auth = signedInAuth()
    let item = makePresetVisibleItem()
    let stationId = item.anyStation.id
    let preset = Preset.mockPlayola(id: "p1", stationId: stationId, position: 0)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [preset]
    let display = PresetDisplayItem(id: "p1", stationItem: item, isPending: false)

    let capturedPresetId = LockIsolated<String?>(nil)
    let model = withDependencies {
      $0.api.deletePreset = { _, presetId in
        capturedPresetId.setValue(presetId)
      }
      $0.analytics.track = { _ in }
      $0.errorReporting.reportError = { _, _ in }
    } operation: {
      StationListModel()
    }

    await model.presetRemoveTapped(display)

    #expect(capturedPresetId.value == "p1")
    #expect(presets.isEmpty)
  }

  @Test
  func testPresetRemoveTappedIgnoredOnPendingTile() async {
    @Shared(.auth) var auth = signedInAuth()
    let item = makePresetVisibleItem()
    let display = PresetDisplayItem(id: "pending-x", stationItem: item, isPending: true)

    let callCount = LockIsolated(0)
    let model = withDependencies {
      $0.api.deletePreset = { _, _ in callCount.setValue(callCount.value + 1) }
    } operation: {
      StationListModel()
    }

    await model.presetRemoveTapped(display)

    #expect(callCount.value == 0)
  }

  @Test
  func testPresetMovedIgnoredInNormalMode() async {
    @Shared(.auth) var auth = signedInAuth()
    let p1 = Preset.mockPlayola(id: "p1", stationId: "s1", position: 0)
    let p2 = Preset.mockPlayola(id: "p2", stationId: "s2", position: 1)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [p1, p2]

    let callCount = LockIsolated(0)
    let model = withDependencies {
      $0.api.movePreset = { _, _, _ in
        callCount.setValue(callCount.value + 1)
        return p1
      }
    } operation: {
      StationListModel()
    }

    #expect(model.presetListState == .normal)
    await model.presetMoved(from: 0, to: 1)

    #expect(callCount.value == 0)
  }

  // MARK: - Error Instrumentation

  @Test
  func testAddPresetServerErrorReportsToSentry() async {
    @Shared(.auth) var auth = signedInAuth()
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []

    let item = makePresetVisibleItem()
    let reportedError = LockIsolated<(any Error)?>(nil)
    let reportedTags = LockIsolated<[String: String]>([:])

    let model = withDependencies {
      $0.api.createPreset = { _, _, _ in
        throw APIError.validationError("conflict")
      }
      $0.analytics.track = { _ in }
      $0.errorReporting.reportError = { error, tags in
        reportedError.setValue(error)
        reportedTags.setValue(tags)
      }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(reportedError.value != nil)
    #expect(reportedTags.value["endpoint"] == "POST /v1/presets")
  }

  @Test
  func testAddPresetNetworkErrorDoesNotReportToSentry() async {
    @Shared(.auth) var auth = signedInAuth()
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []

    let item = makePresetVisibleItem()
    let reportCalled = LockIsolated(false)

    let networkError = NSError(
      domain: NSURLErrorDomain,
      code: NSURLErrorNotConnectedToInternet,
      userInfo: nil)

    let model = withDependencies {
      $0.api.createPreset = { _, _, _ in throw networkError }
      $0.analytics.track = { _ in }
      $0.errorReporting.reportError = { _, _ in
        reportCalled.setValue(true)
      }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(!reportCalled.value)
  }

  @Test
  func testAddPresetFailureTracksApiErrorAnalytics() async {
    @Shared(.auth) var auth = signedInAuth()
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []

    let item = makePresetVisibleItem()
    let captured = LockIsolated<[AnalyticsEvent]>([])

    let model = withDependencies {
      $0.api.createPreset = { _, _, _ in
        throw APIError.validationError("boom")
      }
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
      $0.errorReporting.reportError = { _, _ in }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    let tracked = captured.value.contains {
      if case .apiError(let endpoint, _) = $0, endpoint == "POST /v1/presets" {
        return true
      }
      return false
    }
    #expect(tracked)
  }

  // MARK: - loadPresets Edge Cases

  @Test
  func testLoadPresetsNoOpWhenNoAuth() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: nil)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []

    let callCount = LockIsolated(0)
    let model = withDependencies {
      $0.api.getPresets = { _ in
        callCount.setValue(callCount.value + 1)
        return []
      }
    } operation: {
      StationListModel()
    }

    await model.viewAppeared()

    #expect(callCount.value == 0)
    #expect(presets.isEmpty)
  }

  @Test
  func testLoadPresetsFailureReportsErrorWithoutMutatingPresets() async {
    @Shared(.auth) var auth = signedInAuth()
    let existing = Preset.mockPlayola(id: "p1", stationId: "s1", position: 0)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [existing]

    let reportedTags = LockIsolated<[String: String]>([:])
    let model = withDependencies {
      $0.api.getPresets = { _ in throw APIError.validationError("nope") }
      $0.analytics.track = { _ in }
      $0.errorReporting.reportError = { _, tags in reportedTags.setValue(tags) }
    } operation: {
      StationListModel()
    }

    await model.viewAppeared()

    expectNoDifference(Array(presets), [existing])
    #expect(reportedTags.value["endpoint"] == "GET /v1/presets")
  }

  // MARK: - presetMoved Analytics

  @Test
  func testPresetMovedTracksAnalyticsOnSuccess() async {
    @Shared(.auth) var auth = signedInAuth()
    let p1 = Preset.mockPlayola(id: "p1", stationId: "s1", position: 0)
    let p2 = Preset.mockPlayola(id: "p2", stationId: "s2", position: 1)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [p1, p2]

    @Shared(.stationLists) var sharedLists: IdentifiedArrayOf<StationList> = [
      makePresetTestList(with: [
        APIStationItem(
          sortOrder: 0, visibility: .visible, station: Station.mockWith(id: "s1"), urlStation: nil),
        APIStationItem(
          sortOrder: 1, visibility: .visible, station: Station.mockWith(id: "s2"), urlStation: nil),
      ])
    ]

    let captured = LockIsolated<[AnalyticsEvent]>([])
    let model = withDependencies {
      $0.api.movePreset = { _, presetId, position in
        Preset.mockPlayola(id: presetId, stationId: "s1", position: position)
      }
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      StationListModel()
    }
    model.presetListState = .editing

    await model.presetMoved(from: 0, to: 1)

    let moved = captured.value.contains {
      if case .presetMoved(_, let fromIndex, let toIndex) = $0, fromIndex == 0, toIndex == 1 {
        return true
      }
      return false
    }
    #expect(moved)
  }

  // MARK: - displayPresets Dedupe

  @Test
  func testDisplayPresetsFiltersPendingThatAlreadyExistsAsRealPreset() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let station1 = Station.mockWith(id: "s1", name: "S1")
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [
      makePresetTestList(with: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil)
      ])
    ]
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [
      Preset.mockPlayola(id: "p1", stationId: "s1", position: 0)
    ]
    @Shared(.pendingPresetStationIds) var pending: Set<String> = ["s1"]

    let model = StationListModel()

    expectNoDifference(model.displayPresets.map(\.id), ["p1"])
  }

  // MARK: - presetRemoveTapped Orphan Fallback

  @Test
  func testPresetRemoveTappedFallsBackForOrphanStation() async {
    @Shared(.auth) var auth = signedInAuth()
    let orphanPreset = Preset.mockPlayola(id: "p1", stationId: "missing-s", position: 0)
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = [orphanPreset]
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []

    let orphanItem = APIStationItem(
      sortOrder: 0,
      visibility: .visible,
      station: Station.mockWith(id: "missing-s"),
      urlStation: nil)
    let display = PresetDisplayItem(id: "p1", stationItem: orphanItem, isPending: false)

    let capturedPresetId = LockIsolated<String?>(nil)
    let model = withDependencies {
      $0.api.deletePreset = { _, presetId in capturedPresetId.setValue(presetId) }
      $0.analytics.track = { _ in }
    } operation: {
      StationListModel()
    }

    await model.presetRemoveTapped(display)

    #expect(capturedPresetId.value == "p1")
    #expect(presets.isEmpty)
  }
}

private func signedInAuth() -> Auth {
  Auth(
    currentUser: LoggedInUser(
      id: "u1", firstName: "B", lastName: nil, email: "b@x.com",
      verifiedEmail: nil, profileImageUrl: nil, role: "user"),
    jwt: "t")
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
