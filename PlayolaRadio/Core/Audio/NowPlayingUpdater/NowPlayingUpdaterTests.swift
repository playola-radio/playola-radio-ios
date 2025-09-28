//
//  NowPlayingUpdaterTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/14/25.
//

import Dependencies
import MediaPlayer
import XCTest

@testable import PlayolaRadio

@MainActor
final class NowPlayingUpdaterTests: XCTestCase {
  // MARK: - Analytics Tests

  func testTrackListeningSession_StartsSessionWhenTransitioningToPlaying() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = AnyStation.mock

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
    if case .listeningSessionStarted(let stationInfo) = events.first {
      XCTAssertEqual(stationInfo.id, station.id)
      XCTAssertEqual(stationInfo.name, station.name)
    } else {
      XCTFail("Expected listeningSessionStarted event, got: \(String(describing: events.first))")
    }
  }

  func testTrackListeningSession_EndsSessionWhenStoppingFromPlaying() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = AnyStation.mock

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
    if case .listeningSessionEnded(let stationInfo, let sessionLengthSec) = events.first {
      XCTAssertEqual(stationInfo.id, station.id)
      XCTAssertEqual(stationInfo.name, station.name)
      XCTAssertGreaterThanOrEqual(sessionLengthSec, 0)
    } else {
      XCTFail("Expected listeningSessionEnded event, got: \(String(describing: events.first))")
    }
  }

  func testTrackListeningSession_InitiatesSessionBeforeSwitch() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station1 = AnyStation.mock
    let station2 = AnyStation.url(
      UrlStation(
        id: "station2",
        name: "Station 2",
        streamUrl: "https://stream2.example.com",
        imageUrl: "https://example.com/station2.jpg",
        description: "Description 2",
        website: nil,
        location: nil,
        active: true,
        createdAt: Date(),
        updatedAt: Date()
      ))

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

    // Verify session was started
    let initialEvents = capturedEvents.value
    XCTAssertEqual(initialEvents.count, 1, "Expected 1 event after starting session")
    guard case .listeningSessionStarted = initialEvents.first else {
      XCTFail("Expected listeningSessionStarted event after starting session")
      return
    }

    // Clear events and switch to station 2
    capturedEvents.withValue { $0.removeAll() }
    await updater.trackListeningSession(
      currentStatus: .playing(station2),
      previousStatus: .playing(station1)
    )

    // Verify switch generated events
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 3, "Station switch must generate exactly 3 events")
  }

  func testTrackListeningSession_TracksStationSwitchEvents() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station1 = AnyStation.mock
    let station2 = makeTestStation2()

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      NowPlayingUpdater()
    }

    // Setup: Start playing station 1 first
    await updater.trackListeningSession(
      currentStatus: .playing(station1),
      previousStatus: .stopped
    )
    capturedEvents.withValue { $0.removeAll() }

    // Switch to station 2
    await updater.trackListeningSession(
      currentStatus: .playing(station2),
      previousStatus: .playing(station1)
    )

    // Verify the three expected events
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 3, "Expected exactly 3 events when switching stations")
    guard events.count == 3 else { return }

    verifySessionEndedEvent(events[0], expectedStationId: station1.id, eventIndex: 0)
    verifySwitchedStationEvent(
      events[1], fromStationId: station1.id, toStationId: station2.id, eventIndex: 1
    )
    verifySessionStartedEvent(events[2], expectedStationId: station2.id, eventIndex: 2)
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

    // First start a session to set up the session state
    await updater.trackListeningSession(
      currentStatus: .playing(AnyStation.mock),
      previousStatus: .stopped
    )

    // Clear events from setup
    capturedEvents.withValue { $0.removeAll() }

    // Set last played station for error tracking
    updater.lastPlayedStation = AnyStation.mock

    // Transition to error state
    await updater.trackListeningSession(
      currentStatus: .error,
      previousStatus: .playing(AnyStation.mock)
    )

    // Verify events were tracked
    let events = capturedEvents.value
    guard events.count > 0 else {
      XCTFail("Expected at least 1 event, got 0")
      return
    }

    // When transitioning from playing to error, only session ended is tracked
    // The error case in the switch statement is only for non-playing to error transitions
    XCTAssertEqual(events.count, 1)

    // Should be session ended
    if case .listeningSessionEnded = events[0] {
      // Expected
    } else {
      XCTFail("Expected listeningSessionEnded event, got: \(events[0])")
    }
  }

  func testTrackListeningSession_DoesNotStartMultipleSessions() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = AnyStation.mock

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
    let station = AnyStation.mock

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
    if case .listeningSessionStarted(let stationInfo) = events.first {
      XCTAssertEqual(stationInfo.id, station.id)
    } else {
      XCTFail("Expected listeningSessionStarted event, got: \(String(describing: events.first))")
    }
  }

  func testTrackListeningSession_DoesNotTrackSameStationSwitch() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = AnyStation.mock

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

  // MARK: - Helper Methods

  private func makeTestStation2() -> AnyStation {
    return AnyStation.url(
      UrlStation(
        id: "station2",
        name: "Station 2",
        streamUrl: "https://stream2.example.com",
        imageUrl: "https://example.com/station2.jpg",
        description: "Description 2",
        website: nil,
        location: nil,
        active: true,
        createdAt: Date(),
        updatedAt: Date()
      ))
  }

  private func verifySessionEndedEvent(
    _ event: AnalyticsEvent, expectedStationId: String, eventIndex: Int
  ) {
    guard case .listeningSessionEnded(let stationInfo, _) = event else {
      XCTFail("Expected listeningSessionEnded event at index \(eventIndex), got: \(event)")
      return
    }
    XCTAssertEqual(stationInfo.id, expectedStationId)
  }

  private func verifySwitchedStationEvent(
    _ event: AnalyticsEvent,
    fromStationId: String,
    toStationId: String,
    eventIndex: Int
  ) {
    guard case .switchedStation(let from, let to, let timeBeforeSwitchSec, let reason) = event
    else {
      XCTFail("Expected switchedStation event at index \(eventIndex), got: \(event)")
      return
    }
    XCTAssertEqual(from.id, fromStationId)
    XCTAssertEqual(to.id, toStationId)
    XCTAssertGreaterThanOrEqual(timeBeforeSwitchSec, 0)
    XCTAssertEqual(reason, .userInitiated)
  }

  private func verifySessionStartedEvent(
    _ event: AnalyticsEvent, expectedStationId: String, eventIndex: Int
  ) {
    guard case .listeningSessionStarted(let stationInfo) = event else {
      XCTFail("Expected listeningSessionStarted event at index \(eventIndex), got: \(event)")
      return
    }
    XCTAssertEqual(stationInfo.id, expectedStationId)
  }
}
