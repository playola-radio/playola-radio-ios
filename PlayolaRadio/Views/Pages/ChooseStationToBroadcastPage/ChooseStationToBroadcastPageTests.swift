//
//  ChooseStationToBroadcastPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/2/25.
//

import Dependencies
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class ChooseStationToBroadcastPageTests: XCTestCase {
  func testInit_StoresStationsList() {
    let stations = [
      Station.mockWith(id: "station-1", name: "First Station"),
      Station.mockWith(id: "station-2", name: "Second Station"),
    ]

    let model = ChooseStationToBroadcastPageModel(stations: stations)

    XCTAssertEqual(model.stations.count, 2)
    XCTAssertEqual(model.stations[0].id, "station-1")
    XCTAssertEqual(model.stations[1].id, "station-2")
  }

  func testInit_WithEmptyStationsList() {
    let model = ChooseStationToBroadcastPageModel(stations: [])

    XCTAssertTrue(model.stations.isEmpty)
  }

  func testStations_AreSortedByCuratorName() {
    let stations = [
      Station.mockWith(id: "station-z", name: "Z Station", curatorName: "Zack"),
      Station.mockWith(id: "station-a", name: "A Station", curatorName: "Alice"),
      Station.mockWith(id: "station-m", name: "M Station", curatorName: "Mike"),
    ]

    let model = ChooseStationToBroadcastPageModel(stations: stations)

    XCTAssertEqual(model.sortedStations[0].curatorName, "Alice")
    XCTAssertEqual(model.sortedStations[1].curatorName, "Mike")
    XCTAssertEqual(model.sortedStations[2].curatorName, "Zack")
  }

  func testDisplayName_ReturnsCuratorNameDashName() {
    let station = Station.mockWith(id: "test", name: "Cool Station", curatorName: "DJ Awesome")

    let model = ChooseStationToBroadcastPageModel(stations: [station])

    XCTAssertEqual(model.displayName(for: station), "DJ Awesome - Cool Station")
  }
}
