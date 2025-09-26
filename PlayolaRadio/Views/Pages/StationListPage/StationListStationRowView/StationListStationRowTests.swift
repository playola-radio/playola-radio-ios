//
//  StationListStationRowTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 9/26/25.
//

import XCTest

@testable import PlayolaRadio

final class StationListStationRowTests: XCTestCase {
  func testModelInitializationFromStation() {
    let stationList = StationList.mocks.first { !$0.visibleStationItems.isEmpty }!
    let item = stationList.visibleStationItems.first!
    let station = item.anyStation!

    let model = StationListStationRowModel(item: item)

    XCTAssertEqual(model.titleText, station.name)
    XCTAssertEqual(model.subtitleText, station.stationName)
    XCTAssertEqual(model.imageUrl, station.imageUrl ?? station.processedImageURL())
  }
}
