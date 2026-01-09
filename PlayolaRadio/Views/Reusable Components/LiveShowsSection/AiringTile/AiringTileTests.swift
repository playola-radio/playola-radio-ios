//
//  AiringTileTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//

import Clocks
import Dependencies
import Foundation
import PlayolaPlayer
import XCTest

@testable import PlayolaRadio

@MainActor
final class AiringTileTests: XCTestCase {
  // MARK: - isLive Tests

  func testIsLiveWhenShowIsUpcoming() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let episode = Episode.mockWith(durationMS: 1000 * 60 * 10)
      let airing = Airing.mockWith(
        airtime: now.addingTimeInterval(12 * 60),
        episode: episode
      )
      XCTAssertFalse(AiringTileModel(airing: airing).isLive)
    }
  }

  func testIsLiveWhenShowIsLive() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let episode = Episode.mockWith(durationMS: 1000 * 60 * 10)
      let airing = Airing.mockWith(
        airtime: now.addingTimeInterval(-5 * 60),
        episode: episode
      )
      let model = AiringTileModel(airing: airing)
      XCTAssertTrue(model.isLive)
    }
  }

  // MARK: - timeDisplayString Tests

  func testTimeDisplayStringAMTime() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let calendar = Calendar.current
      var components = DateComponents()
      components.year = 2025
      components.month = 10
      components.day = 1
      components.hour = 7
      components.minute = 0
      let airtime = calendar.date(from: components)!

      components.hour = 10
      let endTime = calendar.date(from: components)!

      let episode = Episode.mockWith(durationMS: Int((endTime.timeIntervalSince(airtime)) * 1000))
      let airing = Airing.mockWith(
        airtime: airtime,
        episode: episode
      )

      let model = AiringTileModel(airing: airing)

      XCTAssertEqual(model.timeDisplayString, "Wed, Oct 1 at 7:00am - 10:00am")
    }
  }

  func testTimeDisplayStringPMTime() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let calendar = Calendar.current
      var components = DateComponents()
      components.year = 2025
      components.month = 10
      components.day = 1
      components.hour = 19
      components.minute = 0
      let airtime = calendar.date(from: components)!

      components.hour = 22
      let endTime = calendar.date(from: components)!

      let episode = Episode.mockWith(durationMS: Int((endTime.timeIntervalSince(airtime)) * 1000))
      let airing = Airing.mockWith(
        airtime: airtime,
        episode: episode
      )

      let model = AiringTileModel(airing: airing)

      XCTAssertEqual(model.timeDisplayString, "Wed, Oct 1 at 7:00pm - 10:00pm")
    }
  }

  // MARK: - scheduleDisplayString Tests

  func testScheduleDisplayStringReturnsLiveNowWhenShowIsLive() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let episode = Episode.mockWith(durationMS: .some(1000 * 60 * 60))
      let airing = Airing.mockWith(
        airtime: now.addingTimeInterval(-30 * 60),
        episode: .some(episode)
      )
      let model = AiringTileModel(airing: airing)

      XCTAssertEqual(model.scheduleDisplayString, "LIVE NOW")
    }
  }

  func testScheduleDisplayStringReturnsFormattedRRuleWhenNotLive() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let calendar = Calendar.current
      var components = DateComponents()
      components.year = 2026
      components.month = 1
      components.day = 13
      components.hour = 16
      components.minute = 0
      let airtime = calendar.date(from: components)!

      let show = Show.mockWith(rrule: .some("FREQ=WEEKLY;BYDAY=MO"))
      let episode = Episode.mockWith(
        durationMS: .some(1000 * 60 * 60),
        show: .some(show)
      )
      let airing = Airing.mockWith(
        airtime: airtime,
        episode: .some(episode)
      )
      let model = AiringTileModel(airing: airing)

      XCTAssertEqual(model.scheduleDisplayString, "Mondays at 4pm")
    }
  }

  func testScheduleDisplayStringReturnsFormattedRRuleForMultipleDays() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let calendar = Calendar.current
      var components = DateComponents()
      components.year = 2026
      components.month = 1
      components.day = 13
      components.hour = 20
      components.minute = 30
      let airtime = calendar.date(from: components)!

      let show = Show.mockWith(rrule: .some("FREQ=WEEKLY;BYDAY=MO,WE,FR"))
      let episode = Episode.mockWith(
        durationMS: .some(1000 * 60 * 60),
        show: .some(show)
      )
      let airing = Airing.mockWith(
        airtime: airtime,
        episode: .some(episode)
      )
      let model = AiringTileModel(airing: airing)

      XCTAssertEqual(model.scheduleDisplayString, "Mondays, Wednesdays, and Fridays at 8:30pm")
    }
  }

  func testScheduleDisplayStringFallsBackToTimeDisplayStringWhenNoRRule() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let calendar = Calendar.current
      var components = DateComponents()
      components.year = 2025
      components.month = 10
      components.day = 1
      components.hour = 19
      components.minute = 0
      let airtime = calendar.date(from: components)!

      let show = Show.mockWith(rrule: .none)
      let episode = Episode.mockWith(
        durationMS: .some(1000 * 60 * 180),
        show: .some(show)
      )
      let airing = Airing.mockWith(
        airtime: airtime,
        episode: .some(episode)
      )
      let model = AiringTileModel(airing: airing)

      XCTAssertEqual(model.scheduleDisplayString, model.timeDisplayString)
    }
  }

  // MARK: - Computed Properties Tests

  func testShowTitle() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let show = Show.mockWith(title: "Morning Vibes")
      let episode = Episode.mockWith(show: show)
      let airing = Airing.mockWith(episode: episode)

      let model = AiringTileModel(airing: airing)

      XCTAssertEqual(model.showTitle, "Morning Vibes")
    }
  }

  func testEpisodeTitle() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let episode = Episode.mockWith(title: "Episode 42: The Big One")
      let airing = Airing.mockWith(episode: episode)

      let model = AiringTileModel(airing: airing)

      XCTAssertEqual(model.episodeTitle, "Episode 42: The Big One")
    }
  }

  func testStationTitle() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let station = Station.mockWith(name: "Moondog Radio", curatorName: "Jacob Stelly")
      let airing = Airing.mockWith(station: station)

      let model = AiringTileModel(airing: airing)

      XCTAssertEqual(model.stationTitle, "Jacob Stelly's Moondog Radio")
    }
  }

  func testStationSubtitle() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let station = Station.mockWith(name: "Moondog Radio", curatorName: "Jacob Stelly")
      let airing = Airing.mockWith(station: station)

      let model = AiringTileModel(airing: airing)

      XCTAssertEqual(model.stationSubtitle, "on Jacob Stelly's Moondog Radio")
    }
  }

  func testStationSubtitleReturnsEmptyStringWhenStationIsNil() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let airing = Airing.mockWith(station: nil)

      let model = AiringTileModel(airing: airing)

      XCTAssertEqual(model.stationSubtitle, "")
    }
  }

  // MARK: - buttonType Tests

  func testButtonTypeNotifyMeWhenShowIsFarInFuture() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let episode = Episode.mockWith(durationMS: 1000 * 60 * 10)
      let airing = Airing.mockWith(
        airtime: now.addingTimeInterval(60 * 60),
        episode: episode
      )
      let model = AiringTileModel(airing: airing)
      XCTAssertEqual(model.buttonType, .notifyMe)
    }
  }

  func testButtonTypeSubscribedWhenShowIsFarInFutureAndUserIsSubscribed() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let episode = Episode.mockWith(durationMS: 1000 * 60 * 10)
      let airing = Airing.mockWith(
        airtime: now.addingTimeInterval(60 * 60),
        episode: episode
      )
      let model = AiringTileModel(airing: airing)
      model.isSubscribedToStationNotifications = true
      model.buttonType = model.isSubscribedToStationNotifications ? .subscribed : .notifyMe

      XCTAssertEqual(model.buttonType, .subscribed)
    }
  }

  func testButtonTypeListenInWhenShowIsStartingSoon() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let episode = Episode.mockWith(durationMS: 1000 * 60 * 10)
      let airing = Airing.mockWith(
        airtime: now.addingTimeInterval(3 * 60),
        episode: episode
      )
      let model = AiringTileModel(airing: airing)
      XCTAssertEqual(model.buttonType, .listenIn)
    }
  }

  func testButtonTypeListenInWhenShowIsLive() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      @Dependency(\.date.now) var now

      let episode = Episode.mockWith(durationMS: 1000 * 60 * 10)
      let airing = Airing.mockWith(
        airtime: now.addingTimeInterval(-2 * 60),
        episode: episode
      )
      let model = AiringTileModel(airing: airing)
      XCTAssertEqual(model.buttonType, .listenIn)
    }
  }

  func testButtonTypeUpdatesToListenInAfterViewAppearedAndTimeAdvances() async {
    let testClock = TestClock()

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.continuousClock = testClock
    } operation: {
      @Dependency(\.date.now) var now

      let episode = Episode.mockWith(durationMS: 1000 * 60 * 10)
      let airing = Airing.mockWith(
        airtime: now.addingTimeInterval(10 * 60),
        episode: episode
      )
      let model = AiringTileModel(airing: airing)

      XCTAssertEqual(model.buttonType, .notifyMe)

      async let viewAppearedTask: Void = model.viewAppeared()

      await testClock.advance(by: .seconds(5 * 60 + 5))

      await viewAppearedTask

      XCTAssertEqual(model.buttonType, .listenIn)
    }
  }

  // MARK: - Error Handling Tests

  func testListenInButtonTappedShowsAlertWhenStationIsNil() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let airing = Airing.mockWith(station: nil)
      let model = AiringTileModel(airing: airing)

      XCTAssertNil(model.presentedAlert)

      model.listenInButtonTapped()

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert, .errorLoadingStation)
    }
  }

  func testListenInButtonTappedPlaysStationWhenStationIsAvailable() async {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
      let station = Station.mockWith(
        id: "test-station",
        name: "Test Station",
        curatorName: "Test DJ"
      )
      let airing = Airing.mockWith(station: station)
      let model = AiringTileModel(airing: airing, stationPlayer: stationPlayerMock)

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

  func testNotifyMeButtonTappedSchedulesNotificationWithCorrectTitleAndMessage() async {
    let station = Station.mockWith(
      id: "test-station",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly"
    )
    let airing = Airing.mockWith(
      airtime: Date().addingTimeInterval(3600),
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
      let model = AiringTileModel(airing: airing)
      await model.notifyMeButtonTapped()

      XCTAssertEqual(capturedTitle, "Playola Radio")
      XCTAssertEqual(
        capturedBody, "Jacob Stelly's Moondog Radio is going live in about 5 minutes!")
      XCTAssertEqual(capturedIdentifier, airing.id)
      XCTAssertNotNil(capturedDate)
    }
  }

  func testNotifyMeButtonTappedShowsAlertWhenNotificationsDenied() async {
    let station = Station.mockWith(
      id: "test-station",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly"
    )
    let airing = Airing.mockWith(
      airtime: Date().addingTimeInterval(3600),
      station: station
    )

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.pushNotifications.requestAuthorization = { false }
    } operation: {
      let model = AiringTileModel(airing: airing)

      XCTAssertNil(model.presentedAlert)

      await model.notifyMeButtonTapped()

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert, .notificationsDisabled)
    }
  }

  func testNotifyMeButtonTappedShowsSuccessAlertWhenNotificationScheduled() async {
    let station = Station.mockWith(
      id: "test-station",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly"
    )
    let airing = Airing.mockWith(
      airtime: Date().addingTimeInterval(3600),
      station: station
    )

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.pushNotifications.scheduleNotification = { _, _, _, _ in }
      $0.pushNotifications.requestAuthorization = { true }
    } operation: {
      let model = AiringTileModel(airing: airing)

      XCTAssertNil(model.presentedAlert)

      await model.notifyMeButtonTapped()

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert, .notificationScheduled)
    }
  }

  func testNotifyMeButtonTappedShowsErrorAlertWhenSchedulingFails() async {
    let station = Station.mockWith(
      id: "test-station",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly"
    )
    let airing = Airing.mockWith(
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
      let model = AiringTileModel(airing: airing)

      XCTAssertNil(model.presentedAlert)

      await model.notifyMeButtonTapped()

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert, .errorSchedulingNotification)
    }
  }

  // MARK: - Analytics Tests

  func testNotifyMeButtonTappedTracksAnalyticsEvent() async {
    let station = Station.mockWith(
      id: "test-station",
      name: "Moondog Radio",
      curatorName: "Jacob Stelly"
    )
    let show = Show.mockWith(
      id: "test-show-id",
      title: "Morning Vibes"
    )
    let episode = Episode.mockWith(
      showId: "test-show-id",
      show: show
    )
    let airing = Airing.mockWith(
      airtime: Date().addingTimeInterval(3600),
      episode: episode,
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
      let model = AiringTileModel(airing: airing)
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
}
