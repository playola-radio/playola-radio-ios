//
//  NowPlayingUpdaterTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/14/25.
//

import Dependencies
import XCTest

@testable import PlayolaRadio

@MainActor
final class NowPlayingUpdaterTests: XCTestCase {

  // MARK: - Analytics Tests

  func testTrackListeningSession_StartsSessionWhenTransitioningToPlaying() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = RadioStation.mock

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      NowPlayingUpdater()
    }

    // Transition from stopped to playing
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .stopped
    )

    // Verify session started event was tracked
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 1)
    if case let .listeningSessionStarted(stationInfo) = events.first {
      XCTAssertEqual(stationInfo.id, station.id)
      XCTAssertEqual(stationInfo.name, station.name)
    } else {
      XCTFail("Expected listeningSessionStarted event, got: \(String(describing: events.first))")
    }
  }

  func testTrackListeningSession_EndsSessionWhenStoppingFromPlaying() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = RadioStation.mock

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      NowPlayingUpdater()
    }

    // First start a session
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .stopped
    )

    // Clear events
    capturedEvents.withValue { $0.removeAll() }

    // Now stop the session
    await updater.trackListeningSession(
      currentStatus: .stopped,
      previousStatus: .playing(station)
    )

    // Verify session ended event was tracked
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 1)
    if case let .listeningSessionEnded(stationInfo, sessionLengthSec) = events.first {
      XCTAssertEqual(stationInfo.id, station.id)
      XCTAssertEqual(stationInfo.name, station.name)
      XCTAssertGreaterThanOrEqual(sessionLengthSec, 0)
    } else {
      XCTFail("Expected listeningSessionEnded event, got: \(String(describing: events.first))")
    }
  }

  func testTrackListeningSession_TracksStationSwitch() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station1 = RadioStation.mock
    let station2 = RadioStation(
      id: "station2",
      name: "Station 2",
      streamURL: "https://stream2.example.com",
      imageURL: "https://example.com/station2.jpg",
      desc: "Description 2",
      longDesc: "Long description for Station 2",
      type: .artist
    )

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      NowPlayingUpdater()
    }

    // Start playing station 1
    await updater.trackListeningSession(
      currentStatus: .playing(station1),
      previousStatus: .stopped
    )

    // Clear events
    capturedEvents.withValue { $0.removeAll() }

    // Switch to station 2
    await updater.trackListeningSession(
      currentStatus: .playing(station2),
      previousStatus: .playing(station1)
    )

    // Verify all switch events were tracked
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 3)

    // First event: session ended for station 1
    if case let .listeningSessionEnded(stationInfo, _) = events[0] {
      XCTAssertEqual(stationInfo.id, station1.id)
    } else {
      XCTFail("Expected listeningSessionEnded event first, got: \(events[0])")
    }

    // Second event: switched station
    if case let .switchedStation(from, to, timeBeforeSwitchSec, reason) = events[1] {
      XCTAssertEqual(from.id, station1.id)
      XCTAssertEqual(to.id, station2.id)
      XCTAssertGreaterThanOrEqual(timeBeforeSwitchSec, 0)
      XCTAssertEqual(reason, .userInitiated)
    } else {
      XCTFail("Expected switchedStation event second, got: \(events[1])")
    }

    // Third event: session started for station 2
    if case let .listeningSessionStarted(stationInfo) = events[2] {
      XCTAssertEqual(stationInfo.id, station2.id)
    } else {
      XCTFail("Expected listeningSessionStarted event third, got: \(events[2])")
    }
  }

  func testTrackListeningSession_TracksPlaybackError() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      NowPlayingUpdater()
    }

    // Set last played station for error tracking
    updater.lastPlayedStation = RadioStation.mock

    // Transition to error state
    await updater.trackListeningSession(
      currentStatus: .error,
      previousStatus: .playing(RadioStation.mock)
    )

    // Verify events were tracked
    let events = capturedEvents.value
    guard events.count > 0 else {
      XCTFail("Expected at least 1 event, got 0")
      return
    }

    XCTAssertEqual(events.count, 2)  // Session ended + error

    // First should be session ended
    if case .listeningSessionEnded = events[0] {
      // Expected
    } else {
      XCTFail("Expected listeningSessionEnded event first, got: \(events[0])")
    }

    // Second should be playback error
    if case let .playbackError(stationInfo, error) = events[1] {
      XCTAssertEqual(stationInfo.id, RadioStation.mock.id)
      XCTAssertEqual(error, "Playback error occurred")
    } else {
      XCTFail("Expected playbackError event second, got: \(events[1])")
    }
  }

  func testTrackListeningSession_DoesNotStartMultipleSessions() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = RadioStation.mock

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      NowPlayingUpdater()
    }

    // Start playing
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .stopped
    )

    // Clear events
    capturedEvents.withValue { $0.removeAll() }

    // Transition from loading to playing (should not start another session)
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .loading(station)
    )

    // Verify no new session was started
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 0)
  }

  func testTrackListeningSession_HandlesLoadingToPlayingTransition() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = RadioStation.mock

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      NowPlayingUpdater()
    }

    // Transition from loading to playing (common flow)
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .loading(station)
    )

    // Verify session started
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 1)
    if case let .listeningSessionStarted(stationInfo) = events.first {
      XCTAssertEqual(stationInfo.id, station.id)
    } else {
      XCTFail("Expected listeningSessionStarted event, got: \(String(describing: events.first))")
    }
  }

  func testTrackListeningSession_DoesNotTrackSameStationSwitch() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = RadioStation.mock

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      NowPlayingUpdater()
    }

    // Start playing
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .stopped
    )

    // Clear events
    capturedEvents.withValue { $0.removeAll() }

    // "Switch" to same station (should not track anything)
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .playing(station)
    )

    // Verify no events were tracked
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 0)
  }
}
