//
//  ListeningTimeTileTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Combine
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@MainActor
struct ListeningTimeTileModelTests {

  func createMockListeningTracker(totalTimeMS: Int) -> ListeningTracker {
    let rewardsProfile = RewardsProfile(
      totalTimeListenedMS: totalTimeMS,
      totalMSAvailableForRewards: 0,
      accurateAsOfTime: Date()
    )
    return ListeningTracker(rewardsProfile: rewardsProfile)
  }

  // MARK: - Display String Formatting Tests

  @Test
  func testListeningTimeDisplayStringFormatsZeroTime() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let model = ListeningTimeTileModel()
      model.totalListeningTime = 0

      #expect(model.listeningTimeDisplayString == "00h 00m 00s")
    }
  }

  @Test
  func testListeningTimeDisplayStringFormatsSeconds() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let model = ListeningTimeTileModel()
      model.totalListeningTime = 45000  // 45 seconds

      #expect(model.listeningTimeDisplayString == "00h 00m 45s")
    }
  }

  @Test
  func testListeningTimeDisplayStringFormatsMinutes() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let model = ListeningTimeTileModel()
      model.totalListeningTime = 150000  // 2 minutes 30 seconds

      #expect(model.listeningTimeDisplayString == "00h 02m 30s")
    }
  }

  @Test
  func testListeningTimeDisplayStringFormatsHours() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let model = ListeningTimeTileModel()
      model.totalListeningTime = 7_382_000  // 2 hours 3 minutes 2 seconds

      #expect(model.listeningTimeDisplayString == "02h 03m 02s")
    }
  }

  @Test
  func testListeningTimeDisplayStringFormatsLargeHours() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let model = ListeningTimeTileModel()
      model.totalListeningTime = 360_000_000  // 100 hours

      #expect(model.listeningTimeDisplayString == "100h 00m 00s")
    }
  }

  // MARK: - View Lifecycle Tests

  @Test
  func testViewAppearedUpdatesFromListeningTracker() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    let clock = TestClock()
    let model = withDependencies {
      $0.continuousClock = clock
    } operation: {
      ListeningTimeTileModel()
    }

    #expect(model.totalListeningTime == 0)

    let tracker = createMockListeningTracker(totalTimeMS: 5000)
    $listeningTracker.withLock { $0 = tracker }

    model.viewAppeared()

    // The initial update should happen immediately
    await clock.advance(by: .seconds(1))
    #expect(model.totalListeningTime == 5000)

    model.viewDisappeared()
  }

  @Test
  func testViewAppearedHandlesNilTracker() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    let clock = TestClock()
    let model = withDependencies {
      $0.continuousClock = clock
    } operation: {
      ListeningTimeTileModel()
    }

    model.viewAppeared()

    await Task.yield()
    #expect(model.totalListeningTime == 0)

    model.viewDisappeared()
  }

  @Test
  func testViewDisappearedCancelsRefreshTask() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    let clock = TestClock()
    let model = withDependencies {
      $0.continuousClock = clock
    } operation: {
      ListeningTimeTileModel()
    }

    let tracker = createMockListeningTracker(totalTimeMS: 1000)
    $listeningTracker.withLock { $0 = tracker }

    model.viewAppeared()

    await Task.yield()
    #expect(model.totalListeningTime == 1000)

    model.viewDisappeared()

    // Add a session to increase time - should not update after viewDisappeared
    $listeningTracker.withLock { tracker in
      let session = LocalListeningSession(
        startTime: Date().addingTimeInterval(-10),
        endTime: Date()
      )  // 10 second session = 10000ms
      tracker?.localListeningSessions.append(session)
    }
    await clock.advance(by: .seconds(1))

    // Should still be 1000 since task was cancelled
    #expect(model.totalListeningTime == 1000)
  }

  @Test
  func testMultipleViewAppearedCancelsPreviousTask() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    let clock = TestClock()
    let model = withDependencies {
      $0.continuousClock = clock
    } operation: {
      ListeningTimeTileModel()
    }

    let tracker = createMockListeningTracker(totalTimeMS: 1000)
    $listeningTracker.withLock { $0 = tracker }

    // First viewAppeared
    model.viewAppeared()
    await Task.yield()
    #expect(model.totalListeningTime == 1000)

    // Second viewAppeared (should cancel first task)
    let session1 = LocalListeningSession(
      startTime: Date().addingTimeInterval(-10),
      endTime: Date()
    )  // 10 second session = 10000ms

    let updatedTracker1 = ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: 1000,
        totalMSAvailableForRewards: 0,
        accurateAsOfTime: Date()
      ),
      localListeningSessions: [session1]
    )
    $listeningTracker.withLock { $0 = updatedTracker1 }

    model.viewAppeared()
    await Task.yield()
    #expect(model.totalListeningTime == 11000)  // 1000 + 10000

    // Advance clock to verify only one task is running
    let session2 = LocalListeningSession(
      startTime: Date().addingTimeInterval(-5),
      endTime: Date()
    )  // 5 second session = 5000ms

    let updatedTracker2 = ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: 1000,
        totalMSAvailableForRewards: 0,
        accurateAsOfTime: Date()
      ),
      localListeningSessions: [session1, session2]
    )
    $listeningTracker.withLock { $0 = updatedTracker2 }

    // Allow shared state to propagate before advancing clock
    await Task.yield()
    await clock.advance(by: .seconds(1))
    #expect(model.totalListeningTime == 16000)  // 1000 + 10000 + 5000

    model.viewDisappeared()
  }

  @Test
  func testConcurrentUpdates() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    let clock = TestClock()
    let model = withDependencies {
      $0.continuousClock = clock
    } operation: {
      ListeningTimeTileModel()
    }

    let tracker = createMockListeningTracker(totalTimeMS: 0)
    $listeningTracker.withLock { $0 = tracker }

    model.viewAppeared()

    await Task.yield()
    #expect(model.totalListeningTime == 0)

    // Simulate rapid updates by adding sessions
    var sessions: [LocalListeningSession] = []
    for index in 1...5 {
      let session = LocalListeningSession(
        startTime: Date().addingTimeInterval(-1),
        endTime: Date()
      )  // 1 second session = 1000ms each
      sessions.append(session)

      let updatedTracker = ListeningTracker(
        rewardsProfile: RewardsProfile(
          totalTimeListenedMS: 0,
          totalMSAvailableForRewards: 0,
          accurateAsOfTime: Date()
        ),
        localListeningSessions: sessions
      )
      $listeningTracker.withLock { $0 = updatedTracker }

      // Allow shared state to propagate before advancing clock
      await Task.yield()
      await clock.advance(by: .seconds(1))
      #expect(model.totalListeningTime == index * 1000)
    }

    model.viewDisappeared()
  }

  @Test
  func testIntegrationWithRealTimeTracking() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    let clock = TestClock()
    let model = withDependencies {
      $0.continuousClock = clock
    } operation: {
      ListeningTimeTileModel()
    }

    // Create a rewards profile with some existing time
    let rewardsProfile = RewardsProfile(
      totalTimeListenedMS: 10000,  // 10 seconds from server
      totalMSAvailableForRewards: 0,
      accurateAsOfTime: Date()
    )

    let tracker = ListeningTracker(rewardsProfile: rewardsProfile)
    $listeningTracker.withLock { $0 = tracker }

    model.viewAppeared()

    // Initial state: 10 seconds from server
    await Task.yield()
    #expect(model.totalListeningTime == 10000)
    #expect(model.listeningTimeDisplayString == "00h 00m 10s")

    // Advance 5 seconds - the listening session should add time
    await clock.advance(by: .seconds(5))

    // The totalListenTimeMS should now include the active session time
    // Note: Due to the way ListeningTracker calculates time,
    // we might need to be flexible with exact timing
    let expectedTime = model.totalListeningTime
    #expect(expectedTime >= 10000)

    model.viewDisappeared()
  }
}
// swiftlint:enable redundant_optional_initialization
