//
//  StationListStationRowTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 9/26/25.
//

import Foundation
import PlayolaPlayer
import Sharing
import SwiftUI
import Testing

@testable import PlayolaRadio

@MainActor
struct StationListStationRowTests {
  @Test
  func testModelInitializationFromStation() {
    @Shared(.showSecretStations) var showSecretStations: Bool = true
    let stationList = StationList.mocks.first { !$0.visibleStationItems.isEmpty }!
    let item = stationList.visibleStationItems.first!
    let station = item.anyStation

    let model = StationListStationRowModel(item: item)

    #expect(model.titleText == station.name)
    #expect(model.subtitleText == station.stationName)
    #expect(model.subtitleColor == Color.white)
    #expect(model.imageUrl == station.imageUrl ?? station.processedImageURL())
  }

  @Test
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

    #expect(model.titleText == comingSoonStation.curatorName)
    #expect(model.subtitleText == "Coming Soon")
    #expect(model.subtitleColor == Color.playolaRed)
    #expect(model.imageUrl == comingSoonStation.imageUrl)
  }

  @Test
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

    #expect(model.titleText == comingSoonStation.curatorName)
    #expect(model.subtitleText == "Coming Soon")
    #expect(model.subtitleColor == Color.playolaRed)
    #expect(model.imageUrl == comingSoonStation.imageUrl)
  }

  @Test
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

    #expect(model.titleText == comingSoonStation.curatorName)
    #expect(model.subtitleText == comingSoonStation.name)
    #expect(model.subtitleColor == Color.white)
    #expect(model.imageUrl == comingSoonStation.imageUrl)
  }

  @Test
  func testComingSoonItemShowsDateWhenItExists() {
    @Shared(.showSecretStations) var showSecretStations: Bool = false
    let now = Date(timeIntervalSince1970: 1_758_915_200)
    let comingSoonStation = PlayolaPlayer.Station(
      id: "coming-soon",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly",
      imageUrl: URL(string: "https://example.com/moondog.png"),
      description: "Coming soon",
      active: true,
      releaseDate: Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 25))!,
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

    #expect(model.titleText == comingSoonStation.curatorName)
    #expect(model.subtitleText == "Coming Dec 25th")
    #expect(model.subtitleColor == Color.playolaRed)
    #expect(model.imageUrl == comingSoonStation.imageUrl)
  }

  @Test
  func testComingSoonDateFormattingUsesUTCTimezone() {
    @Shared(.showSecretStations) var showSecretStations: Bool = false
    let now = Date(timeIntervalSince1970: 1_758_915_200)

    // Simulate how the server sends dates: "2025-12-25" parsed as UTC midnight
    // This is 2025-12-25 00:00:00 UTC, which in US timezones would be Dec 24th local time
    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let releaseDateAsUTC = utcCalendar.date(from: DateComponents(year: 2025, month: 12, day: 25))!

    let comingSoonStation = PlayolaPlayer.Station(
      id: "coming-soon",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly",
      imageUrl: URL(string: "https://example.com/moondog.png"),
      description: "Coming soon",
      active: true,
      releaseDate: releaseDateAsUTC,
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

    // Should show Dec 25th (the UTC date), not Dec 24th (what it would be in US timezones)
    #expect(model.subtitleText == "Coming Dec 25th")
  }

  @Test
  func testInactiveVisibleStationShowsComingSoonWhenSecretsHidden() {
    @Shared(.showSecretStations) var showSecretStations: Bool = false
    let now = Date(timeIntervalSince1970: 1_758_915_200)
    let inactiveStation = PlayolaPlayer.Station(
      id: "inactive-visible",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly",
      imageUrl: URL(string: "https://example.com/moondog.png"),
      description: "An inactive station",
      active: false,
      createdAt: now,
      updatedAt: now
    )

    let item = APIStationItem(
      sortOrder: 0,
      visibility: .visible,
      station: inactiveStation,
      urlStation: nil
    )

    let model = StationListStationRowModel(item: item)

    #expect(model.subtitleText == "Coming Soon")
    #expect(model.subtitleColor == Color.playolaRed)
  }

  @Test
  func testInactiveVisibleStationShowsComingSoonWhenSecretsShowing() {
    @Shared(.showSecretStations) var showSecretStations: Bool = true
    let now = Date(timeIntervalSince1970: 1_758_915_200)
    let inactiveStation = PlayolaPlayer.Station(
      id: "inactive-visible",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly",
      imageUrl: URL(string: "https://example.com/moondog.png"),
      description: "An inactive station",
      active: false,
      createdAt: now,
      updatedAt: now
    )

    let item = APIStationItem(
      sortOrder: 0,
      visibility: .visible,
      station: inactiveStation,
      urlStation: nil
    )

    let model = StationListStationRowModel(item: item)

    #expect(model.subtitleText == "Coming Soon")
    #expect(model.subtitleColor == Color.playolaRed)
  }

  @Test
  func testInactiveUrlStationShowsComingSoonWhenSecretsShowing() {
    @Shared(.showSecretStations) var showSecretStations: Bool = true
    let inactiveUrlStation = UrlStation(
      id: "inactive-url",
      name: "Inactive FM",
      streamUrl: "https://mock.stream.url",
      imageUrl: "https://mock.image.url",
      description: "An inactive URL station",
      website: nil,
      location: "Austin, TX",
      active: false,
      createdAt: Date(),
      updatedAt: Date()
    )

    let item = APIStationItem(
      sortOrder: 0,
      visibility: .comingSoon,
      station: nil,
      urlStation: inactiveUrlStation
    )

    let model = StationListStationRowModel(item: item)

    #expect(model.subtitleText == "Coming Soon")
    #expect(model.subtitleColor == Color.playolaRed)
  }

  // MARK: - Live Sort Priority Tests

  @Test
  func testLiveSortPriorityReturnsZeroForVoicetracking() {
    let station = Station.mockWith(id: "live-station")
    let item = APIStationItem(
      sortOrder: 0,
      visibility: .visible,
      station: station,
      urlStation: nil
    )
    let liveStations = [
      LiveStationInfo(stationId: "live-station", liveStatus: .voicetracking, station: station)
    ]

    let priority = item.liveSortPriority(liveStations)

    #expect(priority == 0)
  }

  @Test
  func testLiveSortPriorityReturnsOneForShowAiring() {
    let station = Station.mockWith(id: "show-station")
    let item = APIStationItem(
      sortOrder: 0,
      visibility: .visible,
      station: station,
      urlStation: nil
    )
    let liveStations = [
      LiveStationInfo(stationId: "show-station", liveStatus: .showAiring, station: station)
    ]

    let priority = item.liveSortPriority(liveStations)

    #expect(priority == 1)
  }

  @Test
  func testLiveSortPriorityReturnsTwoForNotLive() {
    let station = Station.mockWith(id: "not-live-station")
    let item = APIStationItem(
      sortOrder: 0,
      visibility: .visible,
      station: station,
      urlStation: nil
    )
    let liveStations: [LiveStationInfo] = []

    let priority = item.liveSortPriority(liveStations)

    #expect(priority == 2)
  }

  // MARK: - Live Status in Row Model Tests

  @Test
  func testRowModelStoresLiveStatus() {
    let station = Station.mockWith(id: "live-station")
    let item = APIStationItem(
      sortOrder: 0,
      visibility: .visible,
      station: station,
      urlStation: nil
    )

    let model = StationListStationRowModel(item: item, liveStatus: .voicetracking)

    #expect(model.liveStatus == .voicetracking)
  }

  @Test
  func testRowModelLiveStatusDefaultsToNil() {
    let station = Station.mockWith(id: "station")
    let item = APIStationItem(
      sortOrder: 0,
      visibility: .visible,
      station: station,
      urlStation: nil
    )

    let model = StationListStationRowModel(item: item)

    #expect(model.liveStatus == nil)
  }
}
