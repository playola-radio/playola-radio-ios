//
//  ChooseStationPageTests.swift
//  PlayolaRadio
//

import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@MainActor
struct ChooseStationPageTests {
  @Test
  func testInitStoresStations() {
    let stations = [
      Station.mockWith(id: "station-1", name: "First Station"),
      Station.mockWith(id: "station-2", name: "Second Station"),
    ]
    var selectedStation: Station?

    let model = ChooseStationPageModel(
      stations: stations,
      onStationSelected: { selectedStation = $0 }
    )

    #expect(model.stations.count == 2)
    #expect(model.stations[0].id == "station-1")
    #expect(model.stations[1].id == "station-2")
    #expect(selectedStation == nil)
  }

  @Test
  func testSortedStationsSortsByCuratorName() {
    let stations = [
      Station.mockWith(id: "station-z", curatorName: "Zack"),
      Station.mockWith(id: "station-a", curatorName: "Alice"),
      Station.mockWith(id: "station-m", curatorName: "Mike"),
    ]

    let model = ChooseStationPageModel(
      stations: stations,
      onStationSelected: { _ in }
    )

    #expect(model.sortedStations[0].curatorName == "Alice")
    #expect(model.sortedStations[1].curatorName == "Mike")
    #expect(model.sortedStations[2].curatorName == "Zack")
  }

  @Test
  func testSortedStationsFiltersOutInactiveStations() {
    let stations = [
      Station.mockWith(id: "active-1", curatorName: "Alice", active: true),
      Station.mockWith(id: "inactive-1", curatorName: "Bob", active: false),
      Station.mockWith(id: "active-2", curatorName: "Charlie", active: true),
      Station.mockWith(id: "nil-active", curatorName: "Dave", active: nil),
    ]

    let model = ChooseStationPageModel(
      stations: stations,
      onStationSelected: { _ in }
    )

    #expect(model.sortedStations.count == 3)
    #expect(!model.sortedStations.contains { $0.id == "inactive-1" })
    #expect(model.sortedStations.contains { $0.id == "active-1" })
    #expect(model.sortedStations.contains { $0.id == "active-2" })
    #expect(model.sortedStations.contains { $0.id == "nil-active" })
  }

  @Test
  func testStationTappedCallsCallback() {
    let station = Station.mockWith(id: "station-123", curatorName: "Test Curator")
    var selectedStation: Station?

    let model = ChooseStationPageModel(
      stations: [station],
      onStationSelected: { selectedStation = $0 }
    )

    model.stationTapped(station)

    #expect(selectedStation?.id == "station-123")
  }

  @Test
  func testEmptyStationsList() {
    let model = ChooseStationPageModel(
      stations: [],
      onStationSelected: { _ in }
    )

    #expect(model.stations.isEmpty)
    #expect(model.sortedStations.isEmpty)
  }
}
