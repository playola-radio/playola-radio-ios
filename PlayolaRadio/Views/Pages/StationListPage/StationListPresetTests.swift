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

@Suite(.freshSharedState)
@MainActor
struct StationListPresetTests {

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

  // MARK: - Tile Tap

  @Test
  func testPresetTileTappedPlaysStation() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let item = presetItem("s1")
    @Shared(.stationLists) var sharedLists = presetStationLists("s1")

    let display = PresetDisplayItem(id: "p1", stationItem: item, isPending: false)

    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let captured = LockIsolated<[AnalyticsEvent]>([])

    let model = withDependencies {
      $0.stationPlayer = stationPlayerMock
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      StationListModel()
    }
    model.stationListsForDisplay = sharedLists

    await model.presetTileTapped(display)

    #expect(stationPlayerMock.callsToPlay.first?.id == "s1")
    let tracked = captured.value.contains {
      if case .presetTileTapped = $0 { return true }
      return false
    }
    #expect(tracked)
  }

  @Test
  func testPresetTileTappedNoOpInEditMode() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let item = presetItem("s1")
    @Shared(.stationLists) var sharedLists = presetStationLists("s1")

    let display = PresetDisplayItem(id: "p1", stationItem: item, isPending: false)

    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()

    let model = withDependencies {
      $0.stationPlayer = stationPlayerMock
      $0.analytics.track = { _ in }
    } operation: {
      StationListModel()
    }
    model.presetsModel.presetListState = .editing

    await model.presetTileTapped(display)

    #expect(stationPlayerMock.callsToPlay.isEmpty)
  }
}

private func presetItem(_ stationId: String, sortOrder: Int = 0) -> APIStationItem {
  APIStationItem(
    sortOrder: sortOrder, visibility: .visible,
    station: Station.mockWith(id: stationId), urlStation: nil)
}

private func presetStationLists(_ stationIds: String...) -> IdentifiedArrayOf<StationList> {
  IdentifiedArrayOf(uniqueElements: [
    makePresetTestList(with: stationIds.enumerated().map { presetItem($1, sortOrder: $0) })
  ])
}

private func makePresetTestList(with items: [APIStationItem], date: Date = Date()) -> StationList {
  StationList(
    id: "preset-test-list", name: "Test List", slug: "preset-test-list",
    hidden: false, sortOrder: 0, createdAt: date, updatedAt: date, items: items)
}
