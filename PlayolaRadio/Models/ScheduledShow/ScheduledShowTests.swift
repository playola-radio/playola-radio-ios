//
//  ScheduledShowTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/25/25.
//

import Dependencies
import Foundation
import XCTest

@testable import PlayolaRadio

@MainActor
final class ScheduledShowTests: XCTestCase {
  // MARK: - endTime Tests

  func testEndTime_CalculatesCorrectlyWithShowDuration() async {
    withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let airtime = now
      let show = Show(
        id: "show-1",
        stationId: "station-1",
        title: "Morning Show",
        durationMS: 3_600_000,  // 1 hour
        createdAt: now,
        updatedAt: now,
        segments: nil
      )

      let scheduledShow = ScheduledShow(
        id: "scheduled-1",
        showId: "show-1",
        stationId: "station-1",
        airtime: airtime,
        createdAt: now,
        updatedAt: now,
        show: show,
        station: nil
      )

      let expectedEndTime = airtime.addingTimeInterval(3600)  // +1 hour
      XCTAssertEqual(
        scheduledShow.endTime.timeIntervalSince1970, expectedEndTime.timeIntervalSince1970,
        accuracy: 1.0)
    }
  }

  func testEndTime_ReturnsAirtimeWhenNoShow() async {
    withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let airtime = now

      let scheduledShow = ScheduledShow(
        id: "scheduled-1",
        showId: "show-1",
        stationId: "station-1",
        airtime: airtime,
        createdAt: now,
        updatedAt: now,
        show: nil,
        station: nil
      )

      XCTAssertEqual(scheduledShow.endTime, airtime)
    }
  }

  func testEndTime_ReturnsAirtimeWhenShowHasZeroDuration() async {
    withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let airtime = now
      let show = Show(
        id: "show-1",
        stationId: "station-1",
        title: "Empty Show",
        durationMS: 0,
        createdAt: now,
        updatedAt: now,
        segments: nil
      )

      let scheduledShow = ScheduledShow(
        id: "scheduled-1",
        showId: "show-1",
        stationId: "station-1",
        airtime: airtime,
        createdAt: now,
        updatedAt: now,
        show: show,
        station: nil
      )

      XCTAssertEqual(scheduledShow.endTime, airtime)
    }
  }

  // MARK: - hasEnded Tests

  func testHasEnded_ReturnsTrueWhenShowEndedInPast() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let airtime = now.addingTimeInterval(-7200)  // Started 2 hours ago
      let show = Show(
        id: "show-1",
        stationId: "station-1",
        title: "Past Show",
        durationMS: 3_600_000,  // 1 hour duration
        createdAt: now,
        updatedAt: now,
        segments: nil
      )

      let scheduledShow = ScheduledShow(
        id: "scheduled-1",
        showId: "show-1",
        stationId: "station-1",
        airtime: airtime,
        createdAt: now,
        updatedAt: now,
        show: show,
        station: nil
      )

      XCTAssertTrue(scheduledShow.hasEnded)
    }
  }

  func testHasEnded_ReturnsFalseWhenShowIsLive() async {
    withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let airtime = now.addingTimeInterval(-1800)  // Started 30 min ago
      let show = Show(
        id: "show-1",
        stationId: "station-1",
        title: "Live Show",
        durationMS: 3_600_000,  // 1 hour duration
        createdAt: now,
        updatedAt: now,
        segments: nil
      )

      let scheduledShow = ScheduledShow(
        id: "scheduled-1",
        showId: "show-1",
        stationId: "station-1",
        airtime: airtime,
        createdAt: now,
        updatedAt: now,
        show: show,
        station: nil
      )

      XCTAssertFalse(scheduledShow.hasEnded)
    }
  }

  func testHasEnded_ReturnsFalseWhenShowIsUpcoming() async {
    withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let airtime = now.addingTimeInterval(3600)  // Starts in 1 hour
      let show = Show(
        id: "show-1",
        stationId: "station-1",
        title: "Future Show",
        durationMS: 3_600_000,
        createdAt: now,
        updatedAt: now,
        segments: nil
      )

      let scheduledShow = ScheduledShow(
        id: "scheduled-1",
        showId: "show-1",
        stationId: "station-1",
        airtime: airtime,
        createdAt: now,
        updatedAt: now,
        show: show,
        station: nil
      )

      XCTAssertFalse(scheduledShow.hasEnded)
    }
  }

  func testHasEnded_ReturnsTrueWhenShowJustEnded() async {
    withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let airtime = now.addingTimeInterval(-3600)  // Started 1 hour ago
      let show = Show(
        id: "show-1",
        stationId: "station-1",
        title: "Just Ended Show",
        durationMS: 3_600_000,  // 1 hour duration (ended exactly now)
        createdAt: now,
        updatedAt: now,
        segments: nil
      )

      let scheduledShow = ScheduledShow(
        id: "scheduled-1",
        showId: "show-1",
        stationId: "station-1",
        airtime: airtime,
        createdAt: now,
        updatedAt: now,
        show: show,
        station: nil
      )

      XCTAssertTrue(scheduledShow.hasEnded)
    }
  }
}
