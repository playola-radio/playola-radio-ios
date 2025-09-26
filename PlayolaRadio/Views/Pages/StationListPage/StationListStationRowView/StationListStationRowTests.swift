//
//  StationListStationRowTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 9/26/25.
//

import PlayolaPlayer
import Sharing
import SwiftUI
import XCTest

@testable import PlayolaRadio

final class StationListStationRowTests: XCTestCase {
  func testModelInitializationFromStation() {
    @Shared(.showSecretStations) var showSecretStations: Bool = true
    let stationList = StationList.mocks.first { !$0.visibleStationItems.isEmpty }!
    let item = stationList.visibleStationItems.first!
    let station = item.anyStation

    let model = StationListStationRowModel(item: item)

    XCTAssertEqual(model.titleText, station.name)
    XCTAssertEqual(model.subtitleText, station.stationName)
    XCTAssertEqual(model.subtitleColor, Color.white)
    XCTAssertEqual(model.imageUrl, station.imageUrl ?? station.processedImageURL())
  }

  func testComingSoonItemShowsComingSoonWhenSecretsHidden() {
    @Shared(.showSecretStations) var showSecretStations: Bool = false
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

    let model = StationListStationRowModel(item: item)

    XCTAssertEqual(model.titleText, comingSoonStation.curatorName)
    XCTAssertEqual(model.subtitleText, "Coming Soon")
    XCTAssertEqual(model.subtitleColor, Color.playolaRed)
    XCTAssertEqual(
      model.imageUrl, comingSoonStation.imageUrl)
  }

  func testComingSoonItemShowsComingSoonWhenSecretsShowingAndInactive() {
    @Shared(.showSecretStations) var showSecretStations: Bool = true
    let now = Date(timeIntervalSince1970: 1_758_915_200)
    let comingSoonStation = PlayolaPlayer.Station(
      id: "coming-soon",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly",
      imageUrl: URL(string: "https://example.com/moondog.png"),
      description: "Coming soon",
      active: false,
      createdAt: now,
      updatedAt: now
    )

    let item = APIStationItem(
      sortOrder: 0,
      visibility: .comingSoon,
      station: comingSoonStation,
      urlStation: nil
    )

    let model = StationListStationRowModel(item: item)

    XCTAssertEqual(model.titleText, comingSoonStation.curatorName)
    XCTAssertEqual(model.subtitleText, "Coming Soon")
    XCTAssertEqual(model.subtitleColor, Color.playolaRed)
    XCTAssertEqual(
      model.imageUrl, comingSoonStation.imageUrl)
  }

  func testComingSoonItemShowsNormallyWhenSecretsShowingAndActive() {
    @Shared(.showSecretStations) var showSecretStations: Bool = true
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

    let model = StationListStationRowModel(item: item)

    XCTAssertEqual(model.titleText, comingSoonStation.curatorName)
    XCTAssertEqual(model.subtitleText, "Coming Soon")
    XCTAssertEqual(model.subtitleColor, Color.playolaRed)
    XCTAssertEqual(
      model.imageUrl, comingSoonStation.imageUrl)
  }
}
