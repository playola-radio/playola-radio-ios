//
//  AnalyticsClientMock.swift
//  PlayolaRadioTests
//
//  Created by Brian D Keane on 8/14/25.
//

import Dependencies
import Foundation
import Mixpanel

@testable import PlayolaRadio

extension AnalyticsClient {
  /// Test mock that captures all events for verification
  static func mock(
    eventHandler: @escaping (AnalyticsEvent) -> Void = { _ in }
  ) -> Self {
    var trackedEvents: [AnalyticsEvent] = []
    var currentUserId: String?
    var userProperties: [String: any MixpanelType] = [:]
    var listeningSessionStartTime: Date?

    return Self(
      track: { event in
        trackedEvents.append(event)
        eventHandler(event)
      },
      identify: { userId in
        currentUserId = userId
      },
      reset: {
        currentUserId = nil
        userProperties = [:]
        trackedEvents.removeAll()
      },
      setUserProperties: { properties in
        userProperties.merge(properties) { _, new in new }
      },
      startListeningSession: { station in
        listeningSessionStartTime = Date()
        let event = AnalyticsEvent.listeningSessionStarted(
          station: StationInfo(from: station)
        )
        trackedEvents.append(event)
        eventHandler(event)
      },
      endListeningSession: { station, duration in
        listeningSessionStartTime = nil
        let event = AnalyticsEvent.listeningSessionEnded(
          station: StationInfo(from: station),
          sessionLengthSec: Int(duration)
        )
        trackedEvents.append(event)
        eventHandler(event)
      },
      pauseListeningSession: {
        // Mock implementation - could track pause state if needed
      },
      resumeListeningSession: {
        // Mock implementation - could track resume state if needed
      },
      initialize: {
        // No-op for tests
      },
      flush: {
        // No-op for tests
      }
    )
  }

  /// Test mock that captures events in an array for assertion
  static func mockWithStorage() -> (client: Self, storage: EventStorage) {
    let storage = EventStorage()

    let client = Self(
      track: { event in
        await storage.addEvent(event)
      },
      identify: { userId in
        await storage.setUserId(userId)
      },
      reset: {
        await storage.reset()
      },
      setUserProperties: { properties in
        await storage.setUserProperties(properties)
      },
      startListeningSession: { station in
        await storage.startSession(station)
        let event = AnalyticsEvent.listeningSessionStarted(
          station: StationInfo(from: station)
        )
        await storage.addEvent(event)
      },
      endListeningSession: { station, duration in
        await storage.endSession()
        let event = AnalyticsEvent.listeningSessionEnded(
          station: StationInfo(from: station),
          sessionLengthSec: Int(duration)
        )
        await storage.addEvent(event)
      },
      pauseListeningSession: {
        await storage.pauseSession()
      },
      resumeListeningSession: {
        await storage.resumeSession()
      },
      initialize: {
        // No-op for tests
      },
      flush: {
        // No-op for tests
      }
    )

    return (client, storage)
  }
}

// MARK: - Event Storage for Testing

@MainActor
final class EventStorage {
  private(set) var events: [AnalyticsEvent] = []
  private(set) var userId: String?
  private(set) var userProperties: [String: any MixpanelType] = [:]
  private(set) var sessionStartTime: Date?
  private(set) var sessionPausedAt: Date?
  private(set) var currentStation: RadioStation?

  func addEvent(_ event: AnalyticsEvent) {
    events.append(event)
  }

  func setUserId(_ id: String) {
    userId = id
  }

  func setUserProperties(_ properties: [String: any MixpanelType]) {
    userProperties.merge(properties) { _, new in new }
  }

  func startSession(_ station: RadioStation) {
    sessionStartTime = Date()
    currentStation = station
  }

  func endSession() {
    sessionStartTime = nil
    currentStation = nil
    sessionPausedAt = nil
  }

  func pauseSession() {
    sessionPausedAt = Date()
  }

  func resumeSession() {
    sessionPausedAt = nil
  }

  func reset() {
    events.removeAll()
    userId = nil
    userProperties.removeAll()
    sessionStartTime = nil
    sessionPausedAt = nil
    currentStation = nil
  }

  // MARK: - Test Helpers

  func hasEvent(_ eventMatcher: (AnalyticsEvent) -> Bool) -> Bool {
    events.contains(where: eventMatcher)
  }

  func eventCount(_ eventMatcher: (AnalyticsEvent) -> Bool) -> Int {
    events.filter(eventMatcher).count
  }

  func lastEvent() -> AnalyticsEvent? {
    events.last
  }
}
