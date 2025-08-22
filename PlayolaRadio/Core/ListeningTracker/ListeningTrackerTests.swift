//
//  ListeningTrackerTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Combine
import Foundation
import Sharing
import XCTest

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@MainActor
final class ListeningTrackerTests: XCTestCase {

  private var cancellables = Set<AnyCancellable>()

  override func setUp() {
    super.setUp()
    cancellables.removeAll()
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
  }

  override func tearDown() {
    super.tearDown()
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    cancellables.removeAll()
  }

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
      currentStation: RadioStation.mock,
      playbackStatus: playbackStatus
    )
  }

  // MARK: - Initialization Tests

  func testInit_WithEmptyLocalSessions() {
    let rewardsProfile = createMockRewardsProfile()
    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    XCTAssertEqual(tracker.localListeningSessions.count, 0)
    XCTAssertFalse(tracker.isListening)
    XCTAssertEqual(tracker.rewardsProfile.totalTimeListenedMS, 0)
  }

  func testInit_WithExistingLocalSessions() {
    let rewardsProfile = createMockRewardsProfile()
    let existingSessions = [
      LocalListeningSession(
        startTime: Date().addingTimeInterval(-100), endTime: Date().addingTimeInterval(-50))
    ]
    let tracker = ListeningTracker(
      rewardsProfile: rewardsProfile, localListeningSessions: existingSessions)

    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertFalse(tracker.isListening)
  }

  // MARK: - isListening Tests

  func testIsListening_ReturnsFalseWhenNoSessions() {
    let rewardsProfile = createMockRewardsProfile()
    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    XCTAssertFalse(tracker.isListening)
  }

  func testIsListening_ReturnsFalseWhenLastSessionEnded() {
    let rewardsProfile = createMockRewardsProfile()
    let existingSessions = [
      LocalListeningSession(
        startTime: Date().addingTimeInterval(-100), endTime: Date().addingTimeInterval(-50))
    ]
    let tracker = ListeningTracker(
      rewardsProfile: rewardsProfile, localListeningSessions: existingSessions)

    XCTAssertFalse(tracker.isListening)
  }

  func testIsListening_ReturnsTrueWhenLastSessionNotEnded() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Set playing state to match the open session
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(RadioStation.mock)) }

    let existingSessions = [
      LocalListeningSession(startTime: Date().addingTimeInterval(-100), endTime: nil)
    ]
    let tracker = ListeningTracker(
      rewardsProfile: rewardsProfile, localListeningSessions: existingSessions)

    XCTAssertTrue(tracker.isListening)
  }

  // MARK: - totalListenTimeMS Tests

  func testTotalListenTimeMS_WithOnlyServerTime() {
    let rewardsProfile = createMockRewardsProfile(totalTimeListenedMS: 5000)
    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    XCTAssertEqual(tracker.totalListenTimeMS, 5000)
  }

  func testTotalListenTimeMS_WithOnlyLocalSessions() {
    let rewardsProfile = createMockRewardsProfile(totalTimeListenedMS: 0)
    let startTime = Date()
    let endTime = startTime.addingTimeInterval(10)  // 10 seconds = 10000ms
    let existingSessions = [
      LocalListeningSession(startTime: startTime, endTime: endTime)
    ]
    let tracker = ListeningTracker(
      rewardsProfile: rewardsProfile, localListeningSessions: existingSessions)

    XCTAssertEqual(tracker.totalListenTimeMS, 10000)
  }

  func testTotalListenTimeMS_WithBothServerAndLocalTime() {
    let rewardsProfile = createMockRewardsProfile(totalTimeListenedMS: 5000)
    let startTime = Date()
    let endTime = startTime.addingTimeInterval(10)  // 10 seconds = 10000ms
    let existingSessions = [
      LocalListeningSession(startTime: startTime, endTime: endTime)
    ]
    let tracker = ListeningTracker(
      rewardsProfile: rewardsProfile, localListeningSessions: existingSessions)

    XCTAssertEqual(tracker.totalListenTimeMS, 15000)
  }

  func testTotalListenTimeMS_WithMultipleLocalSessions() {
    let rewardsProfile = createMockRewardsProfile(totalTimeListenedMS: 1000)
    let baseTime = Date()
    let existingSessions = [
      LocalListeningSession(startTime: baseTime, endTime: baseTime.addingTimeInterval(5)),  // 5000ms
      LocalListeningSession(
        startTime: baseTime.addingTimeInterval(10), endTime: baseTime.addingTimeInterval(13)),  // 3000ms
    ]
    let tracker = ListeningTracker(
      rewardsProfile: rewardsProfile, localListeningSessions: existingSessions)

    XCTAssertEqual(tracker.totalListenTimeMS, 9000)  // 1000 + 5000 + 3000
  }

  // MARK: - Playback State Change Tests

  func testPlaybackStateChange_StartsNewSessionWhenPlayingStarted() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Create tracker with initial stopped state
    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    XCTAssertEqual(tracker.localListeningSessions.count, 0)
    XCTAssertFalse(tracker.isListening)

    // Update the shared state synchronously
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(RadioStation.mock)) }

    // The publisher should have already fired synchronously
    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertTrue(tracker.isListening)
    XCTAssertNotNil(tracker.localListeningSessions.last?.startTime)
    XCTAssertNil(tracker.localListeningSessions.last?.endTime)
  }

  func testPlaybackStateChange_EndsSessionWhenPlaybackStopped() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Set initial playing state before creating tracker
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(RadioStation.mock)) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    // Verify initial state
    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertTrue(tracker.isListening)

    // Simulate playback stopping
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .stopped) }

    // The publisher should have already fired synchronously
    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertFalse(tracker.isListening)
    XCTAssertNotNil(tracker.localListeningSessions.last?.endTime)
  }

  func testPlaybackStateChange_DoesNotStartDuplicateSessionWhenAlreadyPlaying() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Set initial playing state
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(RadioStation.mock)) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertTrue(tracker.isListening)

    // Simulate another playing state (should not create new session)
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(RadioStation.mock)) }

    // Should still have only one session
    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertTrue(tracker.isListening)
  }

  func testPlaybackStateChange_HandlesLoadingStateAsNonPlaying() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Set initial playing state
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(RadioStation.mock)) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertTrue(tracker.isListening)

    // Simulate loading state (should end session)
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .loading(RadioStation.mock)) }

    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertFalse(tracker.isListening)
    XCTAssertNotNil(tracker.localListeningSessions.last?.endTime)
  }

  func testPlaybackStateChange_HandlesErrorStateAsNonPlaying() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Set initial playing state
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(RadioStation.mock)) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertTrue(tracker.isListening)

    // Simulate error state (should end session)
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .error) }

    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertFalse(tracker.isListening)
    XCTAssertNotNil(tracker.localListeningSessions.last?.endTime)
  }

  func testPlaybackStateChange_HandlesNilNowPlayingAsNonPlaying() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Set initial playing state
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(RadioStation.mock)) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertTrue(tracker.isListening)

    // Simulate nil nowPlaying (should end session)
    $nowPlaying.withLock { $0 = nil }

    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertFalse(tracker.isListening)
    XCTAssertNotNil(tracker.localListeningSessions.last?.endTime)
  }

  // MARK: - Edge Cases

  func testPlaybackStateChange_DoesNotEndSessionWhenNoSessionsExist() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Start with stopped state
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .stopped) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    XCTAssertEqual(tracker.localListeningSessions.count, 0)
    XCTAssertFalse(tracker.isListening)
  }

  func testMultiplePlaybackStateChanges() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()
    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    // Start playing
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(RadioStation.mock)) }

    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertTrue(tracker.isListening)

    // Stop playing
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .stopped) }

    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertFalse(tracker.isListening)

    // Start playing again
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(RadioStation.mock)) }

    XCTAssertEqual(tracker.localListeningSessions.count, 2)
    XCTAssertTrue(tracker.isListening)

    // Stop playing again
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .stopped) }

    XCTAssertEqual(tracker.localListeningSessions.count, 2)
    XCTAssertFalse(tracker.isListening)
  }

  // MARK: - Real-time Session Duration Test

  func testSessionDuration_CalculatesCorrectly() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    let rewardsProfile = createMockRewardsProfile()

    // Start with a playing state
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .playing(RadioStation.mock)) }

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)

    // Verify session started
    XCTAssertEqual(tracker.localListeningSessions.count, 1)
    XCTAssertTrue(tracker.isListening)

    // Get the start time
    let startTime = tracker.localListeningSessions.first?.startTime
    XCTAssertNotNil(startTime)

    // Stop playing
    $nowPlaying.withLock { $0 = createNowPlaying(playbackStatus: .stopped) }

    // Verify session ended
    XCTAssertFalse(tracker.isListening)
    let endTime = tracker.localListeningSessions.first?.endTime
    XCTAssertNotNil(endTime)

    // The duration should be very small since we're testing synchronously
    if let start = startTime, let end = endTime {
      let duration = end.timeIntervalSince(start)
      XCTAssertLessThan(duration, 1.0)  // Should be less than 1 second
      XCTAssertGreaterThanOrEqual(duration, 0)  // Should be non-negative
    }
  }
}

// swiftlint:enable redundant_optional_initialization
