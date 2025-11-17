//
//  ScheduledShowTileTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/16/25.
//

import Dependencies
import Foundation
import PlayolaPlayer
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

  // MARK: - Error Handling Tests

  func testListenNowButtonTapped_ShowsAlertWhenStationIsNil() async {
    let scheduledShow = ScheduledShow.mockWith(
      station: nil
    )
    let model = ScheduledShowTileModel(scheduledShow: scheduledShow)

    XCTAssertNil(model.presentedAlert)

    model.listenNowButtonTapped()

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert, .errorLoadingStation)
  }

  func testListenNowButtonTapped_PlaysStationWhenStationIsAvailable() async {
    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let station = PlayolaPlayer.Station(
      id: "test-station",
      name: "Test Station",
      curatorName: "Test DJ",
      imageUrl: URL(string: "https://example.com/image.png"),
      description: "Test station description",
      active: true,
      createdAt: Date(),
      updatedAt: Date()
    )
    let scheduledShow = ScheduledShow.mockWith(
      station: station
    )
    let model = ScheduledShowTileModel(scheduledShow: scheduledShow, stationPlayer: stationPlayerMock)

    model.listenNowButtonTapped()

    XCTAssertEqual(stationPlayerMock.callsToPlay.count, 1)
    XCTAssertEqual(stationPlayerMock.callsToPlay.first?.id, station.id)
    if case .playola(let playedStation) = stationPlayerMock.callsToPlay.first {
      XCTAssertEqual(playedStation.id, station.id)
      XCTAssertEqual(playedStation.curatorName, station.curatorName)
    } else {
      XCTFail("Expected playola station to be played")
    }
  }

  // MARK: - Notification Tests

  func testRemindMeButtonTapped_SchedulesNotificationWithCorrectTitleAndMessage() async {
    let station = PlayolaPlayer.Station(
      id: "test-station",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly",
      imageUrl: URL(string: "https://example.com/image.png"),
      description: "Test station description",
      active: true,
      createdAt: Date(),
      updatedAt: Date()
    )
    let scheduledShow = ScheduledShow.mockWith(
      airtime: Date().addingTimeInterval(3600), // 1 hour from now
      station: station
    )

    var capturedIdentifier: String?
    var capturedTitle: String?
    var capturedBody: String?
    var capturedDate: Date?

    await withDependencies {
      $0.pushNotifications.scheduleNotification = { identifier, title, body, date in
        capturedIdentifier = identifier
        capturedTitle = title
        capturedBody = body
        capturedDate = date
      }
      $0.pushNotifications.requestAuthorization = { true }
    } operation: {
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)
      await model.remindMeButtonTapped()

      XCTAssertEqual(capturedTitle, "Playola Radio")
      XCTAssertEqual(
        capturedBody, "Jacob Stelly's Moondog Radio is going live in about 5 minutes!")
      XCTAssertEqual(capturedIdentifier, scheduledShow.id)
      XCTAssertNotNil(capturedDate)
    }
  }

  func testRemindMeButtonTapped_ShowsAlertWhenNotificationsDenied() async {
    let station = PlayolaPlayer.Station(
      id: "test-station",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly",
      imageUrl: URL(string: "https://example.com/image.png"),
      description: "Test station description",
      active: true,
      createdAt: Date(),
      updatedAt: Date()
    )
    let scheduledShow = ScheduledShow.mockWith(
      airtime: Date().addingTimeInterval(3600),
      station: station
    )

    await withDependencies {
      $0.pushNotifications.requestAuthorization = { false }
    } operation: {
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)

      XCTAssertNil(model.presentedAlert)

      await model.remindMeButtonTapped()

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert, .notificationsDisabled)
    }
  }
}
