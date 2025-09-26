//
//  StationListStationRowTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 9/26/25.
//

import PlayolaPlayer
import XCTest

@testable import PlayolaRadio

final class StationListStationRowTests: XCTestCase {
  func testModelInitializationFromStation() {
    let stationList = StationList.mocks.first { !$0.visibleStationItems.isEmpty }!
    let item = stationList.visibleStationItems.first!
    let station = item.anyStation!

    let model = StationListStationRowModel(item: item, showSecretStations: true)

    XCTAssertEqual(model.titleText, station.name)
    XCTAssertEqual(model.subtitleText, station.stationName)
    XCTAssertEqual(model.imageUrl, station.imageUrl ?? station.processedImageURL())
  }

  func testComingSoonItemShowsComingSoonWhenSecretsHidden() {
    let now = Date(timeIntervalSince1970: 1_758_915_200)
    let comingSoonStation = PlayolaPlayer.Station(
      id: "coming-soon",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly",
      imageUrl: URL(string: "https://example.com/moondog.png"),
      description: "Coming soon",
      active: true,
      createdAt: now,
      updatedAt: now
    )

    let item = APIStationItem(
      sortOrder: 0,
      visibility: .comingSoon,
      station: comingSoonStation,
      urlStation: nil
    )

    let model = StationListStationRowModel(item: item, showSecretStations: false)

    XCTAssertEqual(model.titleText, comingSoonStation.name)
    XCTAssertEqual(model.subtitleText, "Coming Soon")
    XCTAssertEqual(
      model.imageUrl, comingSoonStation.imageUrl ?? comingSoonStation.processedImageURL())
  }
}
