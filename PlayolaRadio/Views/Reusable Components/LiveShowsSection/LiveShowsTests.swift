//
//  LiveShowTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/8/25.
//

import Dependencies
import IdentifiedCollections
import XCTest

@testable import PlayolaRadio

@MainActor
final class LiveShowsTests: XCTestCase {
  func testScheduledShowDisplay_IsLiveWhenShowHasStartedAndNotEnded() async {
    await withDependencies {
      $0.date.now = Date()
    } operation: {
      @Dependency(\.date.now) var now

      let showDurationInSeconds = TimeInterval(Show.mock.durationMS) / 1000.0
      let timeAgo = showDurationInSeconds / 2

      let scheduledShow = ScheduledShow(
        id: "live-show",
        showId: "show-1",
        stationId: "station-1",
        airtime: now.addingTimeInterval(-timeAgo),
        createdAt: now,
        updatedAt: now,
        show: Show.mock,
        station: nil
      )

      let display = ScheduledShowDisplay.from(scheduledShow)

      XCTAssertTrue(display.isLive)
      XCTAssertEqual(display.statusText, "LIVE NOW")
    }
  }

  func testScheduledShowDisplay_IsNotLiveWhenShowHasNotStarted() async {
    await withDependencies {
      $0.date.now = Date()
    } operation: {
      @Dependency(\.date.now) var now

      let scheduledShow = ScheduledShow(
        id: "upcoming-show",
        showId: "show-1",
        stationId: "station-1",
        airtime: now.addingTimeInterval(3600),
        createdAt: now,
        updatedAt: now,
        show: Show.mock,
        station: nil
      )

      let display = ScheduledShowDisplay.from(scheduledShow)

      XCTAssertFalse(display.isLive)
      XCTAssertEqual(display.statusText, "UPCOMING")
    }
  }

  func testScheduledShowDisplay_IsNotLiveWhenShowHasEnded() async {
    await withDependencies {
      $0.date.now = Date()
    } operation: {
      @Dependency(\.date.now) var now

      let showDurationInSeconds = TimeInterval(Show.mock.durationMS) / 1000.0

      let scheduledShow = ScheduledShow(
        id: "ended-show",
        showId: "show-1",
        stationId: "station-1",
        airtime: now.addingTimeInterval(-(showDurationInSeconds + 3600)),
        createdAt: now,
        updatedAt: now,
        show: Show.mock,
        station: nil
      )

      let display = ScheduledShowDisplay.from(scheduledShow)

      XCTAssertFalse(display.isLive)
      XCTAssertEqual(display.statusText, "UPCOMING")
    }
  }
}
