//
//  ChooseStationToBroadcastPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/2/25.
//

import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct ChooseStationToBroadcastPageTests {
  @Test
  func testInitStoresStationsList() {
    let stations = [
      Station.mockWith(id: "station-1", name: "First Station"),
      Station.mockWith(id: "station-2", name: "Second Station"),
    ]

    let model = ChooseStationToBroadcastPageModel(stations: stations)

    #expect(model.stations.count == 2)
    #expect(model.stations[0].id == "station-1")
    #expect(model.stations[1].id == "station-2")
  }

  @Test
  func testInitWithEmptyStationsList() {
    let model = ChooseStationToBroadcastPageModel(stations: [])

    #expect(model.stations.isEmpty)
  }

  @Test
  func testStationsAreSortedByCuratorName() {
    let stations = [
      Station.mockWith(id: "station-z", name: "Z Station", curatorName: "Zack"),
      Station.mockWith(id: "station-a", name: "A Station", curatorName: "Alice"),
      Station.mockWith(id: "station-m", name: "M Station", curatorName: "Mike"),
    ]

    let model = ChooseStationToBroadcastPageModel(stations: stations)

    #expect(model.sortedStations[0].curatorName == "Alice")
    #expect(model.sortedStations[1].curatorName == "Mike")
    #expect(model.sortedStations[2].curatorName == "Zack")
  }

  @Test
  func testDisplayNameReturnsCuratorNameDashName() {
    let station = Station.mockWith(id: "test", name: "Cool Station", curatorName: "DJ Awesome")

    let model = ChooseStationToBroadcastPageModel(stations: [station])

    #expect(model.displayName(for: station) == "DJ Awesome - Cool Station")
  }

  @Test
  func testStationSelectedSwitchesToBroadcastMode() {
    let stations = [
      Station.mockWith(id: "station-1", name: "First Station"),
      Station.mockWith(id: "station-2", name: "Second Station"),
    ]

    let model = ChooseStationToBroadcastPageModel(stations: stations)

    #expect(model.mainContainerNavigationCoordinator.appMode == .listening)

    model.stationSelected(stations[1])

    #expect(
      model.mainContainerNavigationCoordinator.appMode
        == .broadcasting(stationId: "station-2"))
    #expect(model.mainContainerNavigationCoordinator.path.isEmpty)
  }

  @Test
  func testSortedStationsFiltersOutInactiveStations() {
    let stations = [
      Station.mockWith(id: "active-1", name: "Active Station", curatorName: "Alice", active: true),
      Station.mockWith(
        id: "inactive-1", name: "Inactive Station", curatorName: "Bob", active: false),
      Station.mockWith(
        id: "active-2", name: "Another Active", curatorName: "Charlie", active: true),
      Station.mockWith(
        id: "nil-active", name: "Nil Active Station", curatorName: "Dave", active: nil),
    ]

    let model = ChooseStationToBroadcastPageModel(stations: stations)

    #expect(model.sortedStations.count == 3)
    #expect(!model.sortedStations.contains { $0.id == "inactive-1" })
    #expect(model.sortedStations.contains { $0.id == "active-1" })
    #expect(model.sortedStations.contains { $0.id == "active-2" })
    #expect(model.sortedStations.contains { $0.id == "nil-active" })
  }
}
