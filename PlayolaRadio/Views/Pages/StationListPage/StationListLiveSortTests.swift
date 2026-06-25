//
//  StationListLiveSortTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/13/25.
//

import CustomDump
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct StationListLiveSortTests {
  @Test
  func testLiveStatusForStationReturnsNilWhenNotLive() async {
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

    let model = StationListModel()
    await model.viewAppeared()

    let status = model.liveStatusForStation("some-station-id")

    #expect(status == nil)
  }

  @Test
  func testLiveStatusForStationReturnsVoicetrackingStatus() async {
    let station = Station.mockWith(id: "live-station")
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = [
      LiveStationInfo(stationId: "live-station", liveStatus: .voicetracking, station: station)
    ]

    let model = StationListModel()
    await model.viewAppeared()

    let status = model.liveStatusForStation("live-station")

    #expect(status == .voicetracking)
  }

  @Test
  func testLiveStatusForStationReturnsShowAiringStatus() async {
    let station = Station.mockWith(id: "show-station")
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = [
      LiveStationInfo(stationId: "show-station", liveStatus: .showAiring, station: station)
    ]

    let model = StationListModel()
    await model.viewAppeared()

    let status = model.liveStatusForStation("show-station")

    #expect(status == .showAiring)
  }

  @Test
  func testSortedStationItemsPutsLiveStationsFirst() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let now = Date()

    let station1 = Station.mockWith(id: "station-1", name: "Station 1")
    let station2 = Station.mockWith(id: "station-2", name: "Station 2")
    let station3 = Station.mockWith(id: "station-3", name: "Station 3")

    @Shared(.liveStations) var liveStations: [LiveStationInfo] = [
      LiveStationInfo(stationId: "station-2", liveStatus: .voicetracking, station: station2)
    ]

    let list = StationList(
      id: "test-list",
      name: "Test List",
      slug: "test-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
        APIStationItem(sortOrder: 2, visibility: .visible, station: station3, urlStation: nil),
      ]
    )

    let model = StationListModel()
    await model.viewAppeared()

    let sortedItems = model.sortedStationItems(for: list)

    #expect(sortedItems.count == 3)
    #expect(sortedItems[0].anyStation.id == "station-2")
  }

  @Test
  func testSortedStationItemsPutsVoicetrackingBeforeShowAiring() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let now = Date()

    let station1 = Station.mockWith(id: "station-1", name: "Station 1")
    let station2 = Station.mockWith(id: "station-2", name: "Station 2")
    let station3 = Station.mockWith(id: "station-3", name: "Station 3")

    @Shared(.liveStations) var liveStations: [LiveStationInfo] = [
      LiveStationInfo(stationId: "station-1", liveStatus: .showAiring, station: station1),
      LiveStationInfo(stationId: "station-3", liveStatus: .voicetracking, station: station3),
    ]

    let list = StationList(
      id: "test-list",
      name: "Test List",
      slug: "test-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
        APIStationItem(sortOrder: 2, visibility: .visible, station: station3, urlStation: nil),
      ]
    )

    let model = StationListModel()
    await model.viewAppeared()

    let sortedItems = model.sortedStationItems(for: list)

    #expect(sortedItems.count == 3)
    #expect(sortedItems[0].anyStation.id == "station-3")  // voicetracking first
    #expect(sortedItems[1].anyStation.id == "station-1")  // showAiring second
    #expect(sortedItems[2].anyStation.id == "station-2")  // not live last
  }

  @Test
  func testSortedStationItemsPreservesOrderWhenNoLiveStations() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
    let now = Date()

    let station1 = Station.mockWith(id: "station-1", name: "Station 1")
    let station2 = Station.mockWith(id: "station-2", name: "Station 2")

    let list = StationList(
      id: "test-list",
      name: "Test List",
      slug: "test-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
      ]
    )

    let model = StationListModel()
    await model.viewAppeared()

    let sortedItems = model.sortedStationItems(for: list)

    #expect(sortedItems.count == 2)
    #expect(sortedItems[0].anyStation.id == "station-1")
    #expect(sortedItems[1].anyStation.id == "station-2")
  }

  @Test
  func testDisplayedSectionsReorderWhenLiveStationsChange() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let now = Date()

    let station1 = Station.mockWith(id: "station-1", name: "Station 1")
    let station2 = Station.mockWith(id: "station-2", name: "Station 2")
    let station3 = Station.mockWith(id: "station-3", name: "Station 3")

    let list = StationList(
      id: "test-list",
      name: "Test List",
      slug: "test-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
        APIStationItem(sortOrder: 2, visibility: .visible, station: station3, urlStation: nil),
      ]
    )
    @Shared(.stationLists) var stationLists = IdentifiedArray(uniqueElements: [list])
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

    let model = StationListModel()
    await model.viewAppeared()

    expectNoDifference(
      model.displayedSections.map(\.id),
      ["test-list"]
    )
    expectNoDifference(
      model.displayedSections[0].rows.map(\.id),
      ["station-1", "station-2", "station-3"]
    )

    $liveStations.withLock {
      $0 = [LiveStationInfo(stationId: "station-2", liveStatus: .voicetracking, station: station2)]
    }

    expectNoDifference(
      model.displayedSections[0].rows.map(\.id),
      ["station-2", "station-1", "station-3"]
    )
    expectNoDifference(model.displayedSections[0].rows.first?.liveStatus, .voicetracking)
  }

  @Test
  func testRepeatedViewAppearedDoesNotDuplicateSubscriptions() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

    let model = StationListModel()
    await model.viewAppeared()
    await model.viewAppeared()
    await model.viewAppeared()

    expectNoDifference(model.cancellables.count, 2)
  }
}
