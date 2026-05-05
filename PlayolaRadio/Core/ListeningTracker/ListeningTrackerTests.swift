//
//  ListeningTrackerTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@MainActor
struct ListeningTrackerTests {

  func createMockRewardsProfile(totalTimeListenedMS: Int = 0) -> RewardsProfile {
    return RewardsProfile(
      totalTimeListenedMS: totalTimeListenedMS,
      totalMSAvailableForRewards: 0,
      accurateAsOfTime: Date()
    )
  }

  func createNowPlaying(playbackStatus: StationPlayer.PlaybackStatus) -> NowPlaying {
    return NowPlaying(
      artistPlaying: "Test Artist",
      titlePlaying: "Test Song",
      albumArtworkUrl: nil,
      playolaSpinPlaying: nil,
      currentStation: AnyStation.mock,
      playbackStatus: playbackStatus
    )
  }

  // MARK: - Initialization Tests

  @Test
  func testInitWithEmptyLocalSessions() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil

    let rewardsProfile = createMockRewardsProfile()
    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    #expect(tracker.localListeningSessions.count == 0)
    #expect(!tracker.isListening)
    #expect(tracker.rewardsProfile.totalTimeListenedMS == 0)
  }

  @Test
  func testInitWithExistingLocalSessions() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil

    let rewardsProfile = createMockRewardsProfile()
    let existingSessions = [
      LocalListeningSession(
        startTime: Date().addingTimeInterval(-100), endTime: Date().addingTimeInterval(-50))
    ]
    let tracker = ListeningTracker(
      rewardsProfile: rewardsProfile, localListeningSessions: existingSessions)

    #expect(tracker.localListeningSessions.count == 1)
    #expect(!tracker.isListening)
  }

  // MARK: - isListening Tests

  @Test
  func testIsListeningReturnsFalseWhenNoSessions() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil

    let rewardsProfile = createMockRewardsProfile()
    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    #expect(!tracker.isListening)
  }

  @Test
  func testIsListeningReturnsFalseWhenLastSessionEnded() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil

    let rewardsProfile = createMockRewardsProfile()
    let existingSessions = [
      LocalListeningSession(
        startTime: Date().addingTimeInterval(-100), endTime: Date().addingTimeInterval(-50))
    ]
    let tracker = ListeningTracker(
      rewardsProfile: rewardsProfile, localListeningSessions: existingSessions)

    #expect(!tracker.isListening)
  }

  @Test
  func testIsListeningReturnsTrueWhenLastSessionNotEnded() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Set playing state to match the open session
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(AnyStation.mock)) }

    let existingSessions = [
      LocalListeningSession(startTime: Date().addingTimeInterval(-100), endTime: nil)
    ]
    let tracker = ListeningTracker(
      rewardsProfile: rewardsProfile, localListeningSessions: existingSessions)

    #expect(tracker.isListening)
  }

  // MARK: - totalListenTimeMS Tests

  @Test
  func testTotalListenTimeMSWithOnlyServerTime() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil

    let rewardsProfile = createMockRewardsProfile(totalTimeListenedMS: 5000)
    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    #expect(tracker.totalListenTimeMS == 5000)
  }

  @Test
  func testTotalListenTimeMSWithOnlyLocalSessions() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil

    let rewardsProfile = createMockRewardsProfile(totalTimeListenedMS: 0)
    let startTime = Date()
    let endTime = startTime.addingTimeInterval(10)  // 10 seconds = 10000ms
    let existingSessions = [
      LocalListeningSession(startTime: startTime, endTime: endTime)
    ]
    let tracker = ListeningTracker(
      rewardsProfile: rewardsProfile, localListeningSessions: existingSessions)

    #expect(tracker.totalListenTimeMS == 10000)
  }

  @Test
  func testTotalListenTimeMSWithBothServerAndLocalTime() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil

    let rewardsProfile = createMockRewardsProfile(totalTimeListenedMS: 5000)
    let startTime = Date()
    let endTime = startTime.addingTimeInterval(10)  // 10 seconds = 10000ms
    let existingSessions = [
      LocalListeningSession(startTime: startTime, endTime: endTime)
    ]
    let tracker = ListeningTracker(
      rewardsProfile: rewardsProfile, localListeningSessions: existingSessions)

    #expect(tracker.totalListenTimeMS == 15000)
  }

  @Test
  func testTotalListenTimeMSWithMultipleLocalSessions() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil

    let rewardsProfile = createMockRewardsProfile(totalTimeListenedMS: 1000)
    let baseTime = Date()
    let existingSessions = [
      // 5000ms
      LocalListeningSession(startTime: baseTime, endTime: baseTime.addingTimeInterval(5)),
      LocalListeningSession(
        // 3000ms
        startTime: baseTime.addingTimeInterval(10), endTime: baseTime.addingTimeInterval(13)),
    ]
    let tracker = ListeningTracker(
      rewardsProfile: rewardsProfile, localListeningSessions: existingSessions)

    #expect(tracker.totalListenTimeMS == 9000)  // 1000 + 5000 + 3000
  }

  // MARK: - Playback State Change Tests

  @Test
  func testPlaybackStateChangeStartsNewSessionWhenPlayingStarted() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Create tracker with initial stopped state
    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    #expect(tracker.localListeningSessions.count == 0)
    #expect(!tracker.isListening)

    // Update the shared state synchronously
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(AnyStation.mock)) }

    // The publisher should have already fired synchronously
    #expect(tracker.localListeningSessions.count == 1)
    #expect(tracker.isListening)
    #expect(tracker.localListeningSessions.last?.startTime != nil)
    #expect(tracker.localListeningSessions.last?.endTime == nil)
  }

  @Test
  func testPlaybackStateChangeEndsSessionWhenPlaybackStopped() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Set initial playing state before creating tracker
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(AnyStation.mock)) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    // Verify initial state
    #expect(tracker.localListeningSessions.count == 1)
    #expect(tracker.isListening)

    // Simulate playback stopping
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .stopped) }

    // The publisher should have already fired synchronously
    #expect(tracker.localListeningSessions.count == 1)
    #expect(!tracker.isListening)
    #expect(tracker.localListeningSessions.last?.endTime != nil)
  }

  @Test
  func testPlaybackStateChangeDoesNotStartDuplicateSessionWhenAlreadyPlaying() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Set initial playing state
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(AnyStation.mock)) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    #expect(tracker.localListeningSessions.count == 1)
    #expect(tracker.isListening)

    // Simulate another playing state (should not create new session)
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(AnyStation.mock)) }

    // Should still have only one session
    #expect(tracker.localListeningSessions.count == 1)
    #expect(tracker.isListening)
  }

  @Test
  func testPlaybackStateChangeHandlesLoadingStateAsNonPlaying() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Set initial playing state
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(AnyStation.mock)) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    #expect(tracker.localListeningSessions.count == 1)
    #expect(tracker.isListening)

    // Simulate loading state (should end session)
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .loading(AnyStation.mock)) }

    #expect(tracker.localListeningSessions.count == 1)
    #expect(!tracker.isListening)
    #expect(tracker.localListeningSessions.last?.endTime != nil)
  }

  @Test
  func testPlaybackStateChangeHandlesErrorStateAsNonPlaying() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Set initial playing state
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(AnyStation.mock)) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    #expect(tracker.localListeningSessions.count == 1)
    #expect(tracker.isListening)

    // Simulate error state (should end session)
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .error) }

    #expect(tracker.localListeningSessions.count == 1)
    #expect(!tracker.isListening)
    #expect(tracker.localListeningSessions.last?.endTime != nil)
  }

  @Test
  func testPlaybackStateChangeHandlesNilNowPlayingAsNonPlaying() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Set initial playing state
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(AnyStation.mock)) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    #expect(tracker.localListeningSessions.count == 1)
    #expect(tracker.isListening)

    // Simulate nil nowPlaying (should end session)
    $nowPlaying.withLock { $0 = nil }

    #expect(tracker.localListeningSessions.count == 1)
    #expect(!tracker.isListening)
    #expect(tracker.localListeningSessions.last?.endTime != nil)
  }

  // MARK: - Edge Cases

  @Test
  func testPlaybackStateChangeDoesNotEndSessionWhenNoSessionsExist() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Start with stopped state
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .stopped) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    #expect(tracker.localListeningSessions.count == 0)
    #expect(!tracker.isListening)
  }

  @Test
  func testMultiplePlaybackStateChanges() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()
    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    // Start playing
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(AnyStation.mock)) }

    #expect(tracker.localListeningSessions.count == 1)
    #expect(tracker.isListening)

    // Stop playing
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .stopped) }

    #expect(tracker.localListeningSessions.count == 1)
    #expect(!tracker.isListening)

    // Start playing again
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(AnyStation.mock)) }

    #expect(tracker.localListeningSessions.count == 2)
    #expect(tracker.isListening)

    // Stop playing again
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .stopped) }

    #expect(tracker.localListeningSessions.count == 2)
    #expect(!tracker.isListening)
  }

  // MARK: - Real-time Session Duration Test

  @Test
  func testSessionDurationCalculatesCorrectly() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Start with a playing state
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(AnyStation.mock)) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    // Verify session started
    #expect(tracker.localListeningSessions.count == 1)
    #expect(tracker.isListening)

    // Get the start time
    let startTime = tracker.localListeningSessions.first?.startTime
    #expect(startTime != nil)

    // Stop playing
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .stopped) }

    // Verify session ended
    #expect(!tracker.isListening)
    let endTime = tracker.localListeningSessions.first?.endTime
    #expect(endTime != nil)

    // The duration should be very small since we're testing synchronously
    if let start = startTime, let end = endTime {
      let duration = end.timeIntervalSince(start)
      #expect(duration < 1.0)  // Should be less than 1 second
      #expect(duration >= 0)  // Should be non-negative
    }
  }
}

// swiftlint:enable redundant_optional_initialization
