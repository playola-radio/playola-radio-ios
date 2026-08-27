//
//  AnalyticsClientTests.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AnalyticsClientTests {
  private static let pauseKey = "analytics_session_paused_at"

  @Test
  func testPauseListeningSessionStoresInjectedDateTimestamp() async {
    UserDefaults.standard.removeObject(forKey: Self.pauseKey)
    defer { UserDefaults.standard.removeObject(forKey: Self.pauseKey) }

    let pausedAt = Date(timeIntervalSince1970: 1_700_000_000)

    await withDependencies {
      $0.date = .constant(pausedAt)
    } operation: {
      let client = AnalyticsClient.liveValue
      await client.pauseListeningSession()
    }

    let stored = UserDefaults.standard.object(forKey: Self.pauseKey) as? TimeInterval
    #expect(stored == pausedAt.timeIntervalSince1970)
  }

  @Test
  func testPauseAndResumeUseCallTimeDates() async {
    UserDefaults.standard.removeObject(forKey: Self.pauseKey)
    defer { UserDefaults.standard.removeObject(forKey: Self.pauseKey) }

    let pausedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let resumedAt = pausedAt.addingTimeInterval(60)

    await withDependencies {
      $0.date = .constant(pausedAt)
    } operation: {
      let client = AnalyticsClient.liveValue
      await client.pauseListeningSession()
    }

    let storedAfterPause = UserDefaults.standard.object(forKey: Self.pauseKey) as? TimeInterval
    #expect(storedAfterPause == pausedAt.timeIntervalSince1970)

    await withDependencies {
      $0.date = .constant(resumedAt)
    } operation: {
      let client = AnalyticsClient.liveValue
      await client.resumeListeningSession()
    }

    // resume should clear the stored timestamp after computing the duration
    #expect(UserDefaults.standard.object(forKey: Self.pauseKey) == nil)
  }

  // MARK: - render_backend property mapping

  @Test
  func testListeningSessionStartedIncludesRenderBackendProperty() {
    let event = AnalyticsEvent.listeningSessionStarted(
      station: StationInfo(from: AnyStation.mockPlayola()),
      renderBackend: "sampleBuffer"
    )
    #expect(event.properties["render_backend"] as? String == "sampleBuffer")
  }

  @Test
  func testListeningSessionStartedOmitsRenderBackendPropertyWhenNil() {
    let event = AnalyticsEvent.listeningSessionStarted(
      station: StationInfo(from: AnyStation.mockUrl()),
      renderBackend: nil
    )
    #expect(event.properties["render_backend"] == nil)
  }

  @Test
  func testPlaybackErrorIncludesRenderBackendProperty() {
    let event = AnalyticsEvent.playbackError(
      station: StationInfo(from: AnyStation.mockPlayola()),
      error: "boom",
      renderBackend: "legacyEngine"
    )
    #expect(event.properties["render_backend"] as? String == "legacyEngine")
    #expect(event.properties["error"] as? String == "boom")
  }
}
