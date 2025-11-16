//
//  LiveShowTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/8/25.
//
//
//import Dependencies
//import IdentifiedCollections
//import PlayolaPlayer
//import XCTest
//
//@testable import PlayolaRadio
//
//@MainActor
//final class LiveShowsTests: XCTestCase {
//  func testScheduledShowDisplay_IsLiveWhenShowHasStartedAndNotEnded() async {
//    withDependencies {
//      $0.date.now = Date()
//    } operation: {
//      @Dependency(\.date.now) var now
//
//      let showDurationInSeconds = TimeInterval(Show.mock.durationMS) / 1000.0
//      let timeAgo = showDurationInSeconds / 2
//
//      let scheduledShow = ScheduledShow(
//        id: "live-show",
//        showId: "show-1",
//        stationId: "station-1",
//        airtime: now.addingTimeInterval(-timeAgo),
//        createdAt: now,
//        updatedAt: now,
//        show: Show.mock,
//        station: nil
//      )
//
//      let display = ScheduledShowDisplay.from(scheduledShow)
//
//      XCTAssertTrue(display.isLive)
//      XCTAssertEqual(display.statusText, "LIVE NOW")
//    }
//  }
//
//  func testScheduledShowDisplay_IsNotLiveWhenShowHasNotStarted() async {
//    withDependencies {
//      $0.date.now = Date()
//    } operation: {
//      @Dependency(\.date.now) var now
//
//      let scheduledShow = ScheduledShow(
//        id: "upcoming-show",
//        showId: "show-1",
//        stationId: "station-1",
//        airtime: now.addingTimeInterval(3600),
//        createdAt: now,
//        updatedAt: now,
//        show: Show.mock,
//        station: nil
//      )
//
//      let display = ScheduledShowDisplay.from(scheduledShow)
//
//      XCTAssertFalse(display.isLive)
//      XCTAssertEqual(display.statusText, "UPCOMING")
//    }
//  }
//
//  func testScheduledShowDisplay_IsNotLiveWhenShowHasEnded() async {
//    withDependencies {
//      $0.date.now = Date()
//    } operation: {
//      @Dependency(\.date.now) var now
//
//      let showDurationInSeconds = TimeInterval(Show.mock.durationMS) / 1000.0
//
//      let scheduledShow = ScheduledShow(
//        id: "ended-show",
//        showId: "show-1",
//        stationId: "station-1",
//        airtime: now.addingTimeInterval(-(showDurationInSeconds + 3600)),
//        createdAt: now,
//        updatedAt: now,
//        show: Show.mock,
//        station: nil
//      )
//
//      let display = ScheduledShowDisplay.from(scheduledShow)
//
//      XCTAssertFalse(display.isLive)
//      XCTAssertEqual(display.statusText, "UPCOMING")
//    }
//  }
//
//  func testTimeDisplayString_AMTime() {
//    let calendar = Calendar.current
//    // Create a date: Wed, Oct 1 at 7:00am
//    var components = DateComponents()
//    components.year = 2025
//    components.month = 10
//    components.day = 1
//    components.hour = 7
//    components.minute = 0
//    let airtime = calendar.date(from: components)!
//
//    // Create end time: 10:00am
//    components.hour = 10
//    let endTime = calendar.date(from: components)!
//
//    let display = ScheduledShowDisplay(
//      id: "test-show",
//      showId: "show-1",
//      showTitle: "Morning Show",
//      airtime: airtime,
//      endTime: endTime,
//      isLive: false
//    )
//
//    XCTAssertEqual(display.timeDisplayString, "Wed, Oct 1 at 7:00am - 10:00am")
//  }
//
//  func testTimeDisplayString_PMTime() {
//    let calendar = Calendar.current
//    // Create a date: Wed, Oct 1 at 7:00pm
//    var components = DateComponents()
//    components.year = 2025
//    components.month = 10
//    components.day = 1
//    components.hour = 19
//    components.minute = 0
//    let airtime = calendar.date(from: components)!
//
//    // Create end time: 10:00pm
//    components.hour = 22
//    let endTime = calendar.date(from: components)!
//
//    let display = ScheduledShowDisplay(
//      id: "test-show",
//      showId: "show-1",
//      showTitle: "Evening Show",
//      airtime: airtime,
//      endTime: endTime,
//      isLive: false
//    )
//
//    XCTAssertEqual(display.timeDisplayString, "Wed, Oct 1 at 7:00pm - 10:00pm")
//  }
//
//  func testTimeDisplayString_WithoutEndTime() {
//    let calendar = Calendar.current
//    // Create a date: Wed, Oct 1 at 7:00pm
//    var components = DateComponents()
//    components.year = 2025
//    components.month = 10
//    components.day = 1
//    components.hour = 19
//    components.minute = 0
//    let airtime = calendar.date(from: components)!
//
//    let display = ScheduledShowDisplay(
//      id: "test-show",
//      showId: "show-1",
//      showTitle: "Evening Show",
//      airtime: airtime,
//      endTime: nil,
//      isLive: false
//    )
//
//    XCTAssertEqual(display.timeDisplayString, "Wed, Oct 1 at 7:00pm")
//  }
//
//  // MARK: - LiveShowsModel Tests
//
//  func testLoadScheduledShows_LoadsShowsFromAPI() async {
//    let calendar = Calendar.current
//    var components = DateComponents()
//    components.year = 2025
//    components.month = 10
//    components.day = 1
//    components.hour = 19
//    components.minute = 0
//    let airtime = calendar.date(from: components)!
//
//    let mockScheduledShows = [
//      ScheduledShow(
//        id: "show-1",
//        showId: "show-id-1",
//        stationId: "station-1",
//        airtime: airtime,
//        createdAt: Date(),
//        updatedAt: Date(),
//        show: Show(
//          id: "show-id-1",
//          stationId: "station-1",
//          title: "Evening Show",
//          durationMS: 3_600_000,
//          createdAt: Date(),
//          updatedAt: Date(),
//          segments: nil
//        ),
//        station: nil
//      )
//    ]
//
//    await withDependencies {
//      $0.api.getScheduledShows = { _, _, _ in mockScheduledShows }
//    } operation: {
//      let model = LiveShowsListModel()
//
//      XCTAssertEqual(model.scheduledShows.count, 0)
//
//      await model.loadScheduledShows(jwtToken: "test-token")
//
//      XCTAssertEqual(model.scheduledShows.count, 1)
//      XCTAssertEqual(model.scheduledShows[0].showTitle, "Evening Show")
//      XCTAssertEqual(model.scheduledShows[0].showId, "show-id-1")
//    }
//  }
//
//  func testLoadScheduledShows_FiltersByStationId() async {
//    let mockScheduledShows = [
//      ScheduledShow(
//        id: "show-1",
//        showId: "show-id-1",
//        stationId: "station-1",
//        airtime: Date(),
//        createdAt: Date(),
//        updatedAt: Date(),
//        show: Show.mock,
//        station: nil
//      )
//    ]
//
//    var capturedStationId: String?
//
//    await withDependencies {
//      $0.api.getScheduledShows = { _, _, stationId in
//        capturedStationId = stationId
//        return mockScheduledShows
//      }
//    } operation: {
//      let model = LiveShowsListModel(stationId: "test-station-id")
//
//      await model.loadScheduledShows(jwtToken: "test-token")
//
//      XCTAssertEqual(capturedStationId, "test-station-id")
//    }
//  }
//}
