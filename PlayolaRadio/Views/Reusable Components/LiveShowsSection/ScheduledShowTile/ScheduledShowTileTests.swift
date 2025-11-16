//
//  ScheduledShowTileTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/16/25.
//

import Dependencies
import Foundation
import XCTest

@testable import PlayolaRadio

@MainActor
final class ScheduledShowTileTests: XCTestCase {
  // MARK: - endTime Tests

  func testIsLiveWhenShowIsUpcoming() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let show = Show.mockWith(durationMS: 1000 * 60 * 10)
      let scheduledShow = ScheduledShow.mockWith(
        airtime: now.addingTimeInterval(12 * 60),
        show: show
      )
      XCTAssertFalse(ScheduledShowTileModel(scheduledShow: scheduledShow).isLive)
    }
  }

  func testIsLiveWhenShowIsLive() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let show = Show.mockWith(durationMS: 1000 * 60 * 10)
      let scheduledShow = ScheduledShow.mockWith(
        airtime: now.addingTimeInterval(-5 * 60),
        show: show
      )
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)
      XCTAssertTrue(model.isLive)
    }
  }

  // MARK: - buttonType Tests

  func testButtonType_RemindMeWhenShowIsFarInFuture() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let show = Show.mockWith(durationMS: 1000 * 60 * 10)
      let scheduledShow = ScheduledShow.mockWith(
        airtime: now.addingTimeInterval(60 * 60), // 1 hour in the future
        show: show
      )
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)
      XCTAssertEqual(model.buttonType, .remindMe)
    }
  }

  func testButtonType_ListenNowWhenShowIsStartingSoon() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let show = Show.mockWith(durationMS: 1000 * 60 * 10)
      let scheduledShow = ScheduledShow.mockWith(
        airtime: now.addingTimeInterval(3 * 60), // 3 minutes in the future
        show: show
      )
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)
      XCTAssertEqual(model.buttonType, .listenNow)
    }
  }

  func testButtonType_ListenNowWhenShowIsLive() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let show = Show.mockWith(durationMS: 1000 * 60 * 10)
      let scheduledShow = ScheduledShow.mockWith(
        airtime: now.addingTimeInterval(-2 * 60), // Started 2 minutes ago
        show: show
      )
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)
      XCTAssertEqual(model.buttonType, .listenNow)
    }
  }
}
