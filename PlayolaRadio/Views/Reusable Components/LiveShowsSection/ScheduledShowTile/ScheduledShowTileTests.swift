//
//  ScheduledShowTileTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/16/25.
//

import Clocks
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

  // MARK: - timeDisplayString Tests

  func testTimeDisplayString_AMTime() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let calendar = Calendar.current
      // Create a date: Wed, Oct 1 at 7:00am
      var components = DateComponents()
      components.year = 2025
      components.month = 10
      components.day = 1
      components.hour = 7
      components.minute = 0
      let airtime = calendar.date(from: components)!

      // Create end time: 10:00am
      components.hour = 10
      let endTime = calendar.date(from: components)!

      let show = Show.mockWith(durationMS: Int((endTime.timeIntervalSince(airtime)) * 1000))
      let scheduledShow = ScheduledShow.mockWith(
        airtime: airtime,
        show: show
      )

      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)

      XCTAssertEqual(model.timeDisplayString, "Wed, Oct 1 at 7:00am - 10:00am")
    }
  }

  func testTimeDisplayString_PMTime() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let calendar = Calendar.current
      // Create a date: Wed, Oct 1 at 7:00pm
      var components = DateComponents()
      components.year = 2025
      components.month = 10
      components.day = 1
      components.hour = 19
      components.minute = 0
      let airtime = calendar.date(from: components)!

      // Create end time: 10:00pm
      components.hour = 22
      let endTime = calendar.date(from: components)!

      let show = Show.mockWith(durationMS: Int((endTime.timeIntervalSince(airtime)) * 1000))
      let scheduledShow = ScheduledShow.mockWith(
        airtime: airtime,
        show: show
      )

      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)

      XCTAssertEqual(model.timeDisplayString, "Wed, Oct 1 at 7:00pm - 10:00pm")
    }
  }

  func testTimeDisplayString_CrossingNoonBoundary() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let calendar = Calendar.current
      // Create a date: Wed, Oct 1 at 10:00am
      var components = DateComponents()
      components.year = 2025
      components.month = 10
      components.day = 1
      components.hour = 10
      components.minute = 0
      let airtime = calendar.date(from: components)!

      // Create end time: 2:00pm
      components.hour = 14
      let endTime = calendar.date(from: components)!

      let show = Show.mockWith(durationMS: Int((endTime.timeIntervalSince(airtime)) * 1000))
      let scheduledShow = ScheduledShow.mockWith(
        airtime: airtime,
        show: show
      )

      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)

      XCTAssertEqual(model.timeDisplayString, "Wed, Oct 1 at 10:00am - 2:00pm")
    }
  }

  // MARK: - buttonType Tests

  func testButtonType_notifyMeWhenShowIsFarInFuture() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let show = Show.mockWith(durationMS: 1000 * 60 * 10)
      let scheduledShow = ScheduledShow.mockWith(
        airtime: now.addingTimeInterval(60 * 60),  // 1 hour in the future
        show: show
      )
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)
      XCTAssertEqual(model.buttonType, .notifyMe)
    }
  }

  func testButtonType_listenInWhenShowIsStartingSoon() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let show = Show.mockWith(durationMS: 1000 * 60 * 10)
      let scheduledShow = ScheduledShow.mockWith(
        airtime: now.addingTimeInterval(3 * 60),  // 3 minutes in the future
        show: show
      )
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)
      XCTAssertEqual(model.buttonType, .listenIn)
    }
  }

  func testButtonType_listenInWhenShowIsLive() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let show = Show.mockWith(durationMS: 1000 * 60 * 10)
      let scheduledShow = ScheduledShow.mockWith(
        airtime: now.addingTimeInterval(-2 * 60),  // Started 2 minutes ago
        show: show
      )
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)
      XCTAssertEqual(model.buttonType, .listenIn)
    }
  }

  func testButtonType_updatesToListenInAfterViewAppearedAndTimeAdvances() async {
    let testClock = TestClock()

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.continuousClock = testClock
    } operation: {
      @Dependency(\.date.now) var now

      let show = Show.mockWith(durationMS: 1000 * 60 * 10)
      let scheduledShow = ScheduledShow.mockWith(
        airtime: now.addingTimeInterval(10 * 60),  // 10 minutes in the future
        show: show
      )
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)

      XCTAssertEqual(model.buttonType, .notifyMe)

      async let viewAppearedTask: Void = model.viewAppeared()

      // Advance clock past the 5-minute threshold plus the 5-second buffer
      await testClock.advance(by: .seconds(5 * 60 + 5))

      await viewAppearedTask

      XCTAssertEqual(model.buttonType, .listenIn)
    }
  }

  // MARK: - Error Handling Tests

  func testlistenInButtonTapped_ShowsAlertWhenStationIsNil() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let scheduledShow = ScheduledShow.mockWith(
        station: nil
      )
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)

      XCTAssertNil(model.presentedAlert)

      model.listenInButtonTapped()

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert, .errorLoadingStation)
    }
  }

  func testlistenInButtonTapped_PlaysStationWhenStationIsAvailable() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
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
      let model = ScheduledShowTileModel(
        scheduledShow: scheduledShow, stationPlayer: stationPlayerMock)

      model.listenInButtonTapped()

      XCTAssertEqual(stationPlayerMock.callsToPlay.count, 1)
      XCTAssertEqual(stationPlayerMock.callsToPlay.first?.id, station.id)
      if case .playola(let playedStation) = stationPlayerMock.callsToPlay.first {
        XCTAssertEqual(playedStation.id, station.id)
        XCTAssertEqual(playedStation.curatorName, station.curatorName)
      } else {
        XCTFail("Expected playola station to be played")
      }
    }
  }

  // MARK: - Notification Tests

  func testnotifyMeButtonTapped_SchedulesNotificationWithCorrectTitleAndMessage() async {
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
      airtime: Date().addingTimeInterval(3600),  // 1 hour from now
      station: station
    )

    var capturedIdentifier: String?
    var capturedTitle: String?
    var capturedBody: String?
    var capturedDate: Date?

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.pushNotifications.scheduleNotification = { identifier, title, body, date in
        capturedIdentifier = identifier
        capturedTitle = title
        capturedBody = body
        capturedDate = date
      }
      $0.pushNotifications.requestAuthorization = { true }
    } operation: {
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)
      await model.notifyMeButtonTapped()

      XCTAssertEqual(capturedTitle, "Playola Radio")
      XCTAssertEqual(
        capturedBody, "Jacob Stelly's Moondog Radio is going live in about 5 minutes!")
      XCTAssertEqual(capturedIdentifier, scheduledShow.id)
      XCTAssertNotNil(capturedDate)
    }
  }

  func testnotifyMeButtonTapped_ShowsAlertWhenNotificationsDenied() async {
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
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.pushNotifications.requestAuthorization = { false }
    } operation: {
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)

      XCTAssertNil(model.presentedAlert)

      await model.notifyMeButtonTapped()

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert, .notificationsDisabled)
    }
  }

  func testnotifyMeButtonTapped_ShowsSuccessAlertWhenNotificationScheduled() async {
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
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.pushNotifications.scheduleNotification = { _, _, _, _ in }
      $0.pushNotifications.requestAuthorization = { true }
    } operation: {
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)

      XCTAssertNil(model.presentedAlert)

      await model.notifyMeButtonTapped()

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert, .notificationScheduled)
    }
  }

  func testnotifyMeButtonTapped_ShowsErrorAlertWhenSchedulingFails() async {
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

    struct TestError: Error {}

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.pushNotifications.scheduleNotification = { _, _, _, _ in
        throw TestError()
      }
      $0.pushNotifications.requestAuthorization = { true }
    } operation: {
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)

      XCTAssertNil(model.presentedAlert)

      await model.notifyMeButtonTapped()

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert, .errorSchedulingNotification)
    }
  }

  // MARK: - Analytics Tests

  func testnotifyMeButtonTapped_TracksAnalyticsEvent() async {
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
    let show = Show(
      id: "test-show-id",
      stationId: "test-station",
      title: "Morning Vibes",
      durationMS: 3_600_000,
      createdAt: Date(),
      updatedAt: Date(),
      segments: nil
    )
    let scheduledShow = ScheduledShow.mockWith(
      showId: "test-show-id",
      airtime: Date().addingTimeInterval(3600),
      show: show,
      station: station
    )

    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.pushNotifications.scheduleNotification = { _, _, _, _ in }
      $0.pushNotifications.requestAuthorization = { true }
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)
      await model.notifyMeButtonTapped()

      let events = capturedEvents.value
      XCTAssertEqual(events.count, 1)

      if case .notifyMeRequested(let showId, let showName, let stationName) = events.first {
        XCTAssertEqual(showId, "test-show-id")
        XCTAssertEqual(showName, "Morning Vibes")
        XCTAssertEqual(stationName, "Moondog Radio")
      } else {
        XCTFail("Expected notifyMeRequested event, got: \(String(describing: events.first))")
      }
    }
  }

  func testnotifyMeButtonTapped_DoesNotTrackAnalyticsWhenNotificationDenied() async {
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

    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.pushNotifications.requestAuthorization = { false }
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)
      await model.notifyMeButtonTapped()

      XCTAssertTrue(capturedEvents.value.isEmpty)
    }
  }

  func testnotifyMeButtonTapped_DoesNotTrackAnalyticsWhenSchedulingFails() async {
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

    struct TestError: Error {}
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.pushNotifications.requestAuthorization = { true }
      $0.pushNotifications.scheduleNotification = { _, _, _, _ in
        throw TestError()
      }
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      let model = ScheduledShowTileModel(scheduledShow: scheduledShow)
      await model.notifyMeButtonTapped()

      XCTAssertTrue(capturedEvents.value.isEmpty)
    }
  }
}
