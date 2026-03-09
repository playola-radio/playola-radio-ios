//
//  ChooseStationPageTests.swift
//  PlayolaRadio
//

import PlayolaPlayer
import XCTest

@testable import PlayolaRadio

@MainActor
final class ChooseStationPageTests: XCTestCase {
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

    XCTAssertEqual(model.stations.count, 2)
    XCTAssertEqual(model.stations[0].id, "station-1")
    XCTAssertEqual(model.stations[1].id, "station-2")
    XCTAssertNil(selectedStation)
  }

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

    XCTAssertEqual(model.sortedStations[0].curatorName, "Alice")
    XCTAssertEqual(model.sortedStations[1].curatorName, "Mike")
    XCTAssertEqual(model.sortedStations[2].curatorName, "Zack")
  }

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

    XCTAssertEqual(model.sortedStations.count, 3)
    XCTAssertFalse(model.sortedStations.contains { $0.id == "inactive-1" })
    XCTAssertTrue(model.sortedStations.contains { $0.id == "active-1" })
    XCTAssertTrue(model.sortedStations.contains { $0.id == "active-2" })
    XCTAssertTrue(model.sortedStations.contains { $0.id == "nil-active" })
  }

  func testStationTappedCallsCallback() {
    let station = Station.mockWith(id: "station-123", curatorName: "Test Curator")
    var selectedStation: Station?

    let model = ChooseStationPageModel(
      stations: [station],
      onStationSelected: { selectedStation = $0 }
    )

    model.stationTapped(station)

    XCTAssertEqual(selectedStation?.id, "station-123")
  }

  func testEmptyStationsList() {
    let model = ChooseStationPageModel(
      stations: [],
      onStationSelected: { _ in }
    )

    XCTAssertTrue(model.stations.isEmpty)
    XCTAssertTrue(model.sortedStations.isEmpty)
  }
}
