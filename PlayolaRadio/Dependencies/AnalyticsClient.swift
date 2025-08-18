//
//  AnalyticsClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/14/25.
//

import Dependencies
import DependenciesMacros
import Foundation
import Mixpanel
import Sharing

// MARK: - Analytics Client Dependency

@DependencyClient
struct AnalyticsClient: Sendable {
  // MARK: Core Tracking

  /// Track a specific analytics event
  var track: @Sendable (_ event: AnalyticsEvent) async -> Void

  /// Identify the current user
  var identify: @Sendable (_ userId: String) async -> Void

  /// Reset the current user (on sign out)
  var reset: @Sendable () async -> Void

  /// Set user properties for the current user
  var setUserProperties: @Sendable (_ properties: [String: any MixpanelType]) async -> Void

  // MARK: Session Management

  /// Start a new listening session for a station
  var startListeningSession: @Sendable (_ station: RadioStation) async -> Void

  /// End the current listening session
  var endListeningSession:
    @Sendable (_ station: RadioStation, _ duration: TimeInterval) async -> Void

  /// Pause the current listening session (e.g., when app backgrounds)
  var pauseListeningSession: @Sendable () async -> Void

  /// Resume a paused listening session
  var resumeListeningSession: @Sendable () async -> Void

  // MARK: Utility Methods

  /// Initialize the analytics service
  var initialize: @Sendable () async -> Void

  /// Flush any pending events
  var flush: @Sendable () async -> Void
}

// MARK: - Dependency Registration

extension AnalyticsClient: TestDependencyKey {
  static let testValue = AnalyticsClient.noop
}

extension DependencyValues {
  var analytics: AnalyticsClient {
    get { self[AnalyticsClient.self] }
    set { self[AnalyticsClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension AnalyticsClient: DependencyKey {
  static let liveValue = Self(
    track: { event in
      await MainActor.run {
        @Shared(.auth) var auth: Auth
        var properties = event.properties

        // Automatically add userId to all events when available
        if let userId = auth.currentUser?.id {
          properties["user_id"] = userId
        }

        Mixpanel.mainInstance().track(
          event: event.name,
          properties: properties
        )
      }
    },
    identify: { userId in
      await MainActor.run {
        Mixpanel.mainInstance().identify(distinctId: userId)
      }
    },
    reset: {
      await MainActor.run {
        Mixpanel.mainInstance().reset()
      }
    },
    setUserProperties: { properties in
      await MainActor.run {
        Mixpanel.mainInstance().people.set(properties: properties)
      }
    },
    startListeningSession: { station in
      await MainActor.run {
        let properties: [String: any MixpanelType] = [
          "station_id": station.id,
          "station_name": station.name,
          "station_type": station.type.rawValue,
        ]
        Mixpanel.mainInstance().track(
          event: "Listening Session Started",
          properties: properties
        )
        Mixpanel.mainInstance().time(event: "Listening Session Ended")
      }
    },
    endListeningSession: { station, duration in
      await MainActor.run {
        let properties: [String: any MixpanelType] = [
          "station_id": station.id,
          "station_name": station.name,
          "station_type": station.type.rawValue,
          "session_length_sec": Int(duration),
        ]
        Mixpanel.mainInstance().track(
          event: "Listening Session Ended",
          properties: properties
        )
      }
    },
    pauseListeningSession: {
      await MainActor.run {
        // Store current timestamp for calculating pause duration
        UserDefaults.standard.set(
          Date().timeIntervalSince1970, forKey: "analytics_session_paused_at")
      }
    },
    resumeListeningSession: {
      await MainActor.run {
        // Calculate pause duration and track if needed
        if let pausedAt = UserDefaults.standard.object(forKey: "analytics_session_paused_at")
          as? TimeInterval
        {
          let pauseDuration = Date().timeIntervalSince1970 - pausedAt
          let properties: [String: any MixpanelType] = [
            "pause_duration_sec": Int(pauseDuration)
          ]
          Mixpanel.mainInstance().track(
            event: "Listening Session Resumed",
            properties: properties
          )
          UserDefaults.standard.removeObject(forKey: "analytics_session_paused_at")
        }
      }
    },
    initialize: {
      await MainActor.run {
        Mixpanel.initialize(
          token: Config.shared.mixpanelToken,
          trackAutomaticEvents: false
        )
      }
    },
    flush: {
      await MainActor.run {
        Mixpanel.mainInstance().flush()
      }
    }
  )
}

// MARK: - Test Implementation

extension AnalyticsClient {
  static let noop = Self(
    track: { _ in },
    identify: { _ in },
    reset: {},
    setUserProperties: { _ in },
    startListeningSession: { _ in },
    endListeningSession: { _, _ in },
    pauseListeningSession: {},
    resumeListeningSession: {},
    initialize: {},
    flush: {}
  )
}
