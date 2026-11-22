//
//  StationListVisibilityTests.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct StationListVisibilityTests {
  @Test
  func testIsSearchBarPlaceholderVisibleWhenSearchTextEmpty() {
    let model = StationListModel()
    model.searchText = ""
    #expect(model.isSearchBarPlaceholderVisible)
  }

  @Test
  func testIsSearchBarPlaceholderHiddenWhenSearchTextNotEmpty() {
    let model = StationListModel()
    model.searchText = "Alice"
    #expect(!model.isSearchBarPlaceholderVisible)
  }

  @Test
  func testIsClearSearchButtonHiddenWhenSearchTextEmpty() {
    let model = StationListModel()
    model.searchText = ""
    #expect(!model.isClearSearchButtonVisible)
  }

  @Test
  func testIsClearSearchButtonVisibleWhenSearchTextNotEmpty() {
    let model = StationListModel()
    model.searchText = "Alice"
    #expect(model.isClearSearchButtonVisible)
  }

  @Test
  func testNoResultsIconName() {
    #expect(StationListModel().noResultsIconName == "music.note.list")
  }

  @Test
  func testClearSearchButtonAccessibilityLabel() {
    #expect(StationListModel().clearSearchButtonAccessibilityLabel == "Clear search")
  }

  @Test
  func testVisibleSectionsIncludesEverySectionWhenSearchTextEmpty() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = []
    @Shared(.stationLists) var stationLists = StationList.mocks
    let model = StationListModel()
    await model.viewAppeared()

    #expect(model.visibleSections.map(\.id) == model.displayedSections.map(\.id))
    #expect(!model.visibleSections.isEmpty)
  }

  @Test
  func testVisibleSectionsDropsSectionsWithNoMatchingRows() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = []

    let alice = Station.mockWith(id: "s1", name: "Show One", curatorName: "Alice")
    let bob = Station.mockWith(id: "s2", name: "Show Two", curatorName: "Bob")
    let now = Date()
    let aliceList = StationList(
      id: "list-alice", name: "Alice List", slug: "alice-list", hidden: false, sortOrder: 0,
      createdAt: now, updatedAt: now,
      items: [APIStationItem(sortOrder: 0, visibility: .visible, station: alice, urlStation: nil)])
    let bobList = StationList(
      id: "list-bob", name: "Bob List", slug: "bob-list", hidden: false, sortOrder: 1,
      createdAt: now, updatedAt: now,
      items: [APIStationItem(sortOrder: 0, visibility: .visible, station: bob, urlStation: nil)])
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [aliceList, bobList]
    let model = StationListModel()
    await model.viewAppeared()

    model.searchText = "Alice"

    #expect(model.visibleSections.map(\.id) == ["list-alice"])
  }

  @Test
  func testVisibleSectionsEmptyWhenNothingMatchesSearch() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = []
    @Shared(.stationLists) var stationLists = StationList.mocks
    let model = StationListModel()
    await model.viewAppeared()

    model.searchText = "xyznonexistent"

    #expect(model.visibleSections.isEmpty)
  }
}
