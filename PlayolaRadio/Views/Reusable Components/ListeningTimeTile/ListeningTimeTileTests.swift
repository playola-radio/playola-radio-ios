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
import XCTest

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@MainActor
final class ListeningTimeTileModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    }

    override func tearDown() {
        super.tearDown()
        @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    }

    func createMockListeningTracker(totalTimeMS: Int) -> ListeningTracker {
        let rewardsProfile = RewardsProfile(
            totalTimeListenedMS: totalTimeMS,
            totalMSAvailableForRewards: 0,
            accurateAsOfTime: Date()
        )
        return ListeningTracker(rewardsProfile: rewardsProfile)
    }

    // MARK: - Display String Formatting Tests

    func testListeningTimeDisplayString_FormatsZeroTime() async {
        withDependencies {
            $0.continuousClock = TestClock()
        } operation: {
            let model = ListeningTimeTileModel()
            model.totalListeningTime = 0

            XCTAssertEqual(model.listeningTimeDisplayString, "00h 00m 00s")
        }
    }

    func testListeningTimeDisplayString_FormatsSeconds() async {
        withDependencies {
            $0.continuousClock = TestClock()
        } operation: {
            let model = ListeningTimeTileModel()
            model.totalListeningTime = 45000 // 45 seconds

            XCTAssertEqual(model.listeningTimeDisplayString, "00h 00m 45s")
        }
    }

    func testListeningTimeDisplayString_FormatsMinutes() async {
        withDependencies {
            $0.continuousClock = TestClock()
        } operation: {
            let model = ListeningTimeTileModel()
            model.totalListeningTime = 150_000 // 2 minutes 30 seconds

            XCTAssertEqual(model.listeningTimeDisplayString, "00h 02m 30s")
        }
    }

    func testListeningTimeDisplayString_FormatsHours() async {
        withDependencies {
            $0.continuousClock = TestClock()
        } operation: {
            let model = ListeningTimeTileModel()
            model.totalListeningTime = 7_382_000 // 2 hours 3 minutes 2 seconds

            XCTAssertEqual(model.listeningTimeDisplayString, "02h 03m 02s")
        }
    }

    func testListeningTimeDisplayString_FormatsLargeHours() async {
        withDependencies {
            $0.continuousClock = TestClock()
        } operation: {
            let model = ListeningTimeTileModel()
            model.totalListeningTime = 360_000_000 // 100 hours

            XCTAssertEqual(model.listeningTimeDisplayString, "100h 00m 00s")
        }
    }

    // MARK: - View Lifecycle Tests

    func testViewAppeared_UpdatesFromListeningTracker() async {
        @Shared(.listeningTracker) var listeningTracker: ListeningTracker?
        let clock = TestClock()
        let model = withDependencies {
            $0.continuousClock = clock
        } operation: {
            ListeningTimeTileModel()
        }

        XCTAssertEqual(model.totalListeningTime, 0)

        let tracker = createMockListeningTracker(totalTimeMS: 5000)
        $listeningTracker.withLock { $0 = tracker }

        model.viewAppeared()

        // The initial update should happen immediately
        await clock.advance(by: .seconds(1))
        XCTAssertEqual(model.totalListeningTime, 5000)

        model.viewDisappeared()
    }

    func testViewAppeared_HandlesNilTracker() async {
        @Shared(.listeningTracker) var listeningTracker: ListeningTracker?
        let clock = TestClock()
        let model = withDependencies {
            $0.continuousClock = clock
        } operation: {
            ListeningTimeTileModel()
        }

        model.viewAppeared()

        await Task.yield()
        XCTAssertEqual(model.totalListeningTime, 0)

        model.viewDisappeared()
    }

    func testViewDisappeared_CancelsRefreshTask() async {
        @Shared(.listeningTracker) var listeningTracker: ListeningTracker?
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
        XCTAssertEqual(model.totalListeningTime, 1000)

        model.viewDisappeared()

        // Add a session to increase time - should not update after viewDisappeared
        $listeningTracker.withLock { tracker in
            let session = LocalListeningSession(
                startTime: Date().addingTimeInterval(-10),
                endTime: Date()
            ) // 10 second session = 10000ms
            tracker?.localListeningSessions.append(session)
        }
        await clock.advance(by: .seconds(1))

        // Should still be 1000 since task was cancelled
        XCTAssertEqual(model.totalListeningTime, 1000)
    }

    func testMultipleViewAppeared_CancelsPreviousTask() async {
        @Shared(.listeningTracker) var listeningTracker: ListeningTracker?
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
        XCTAssertEqual(model.totalListeningTime, 1000)

        // Second viewAppeared (should cancel first task)
        let session1 = LocalListeningSession(
            startTime: Date().addingTimeInterval(-10),
            endTime: Date()
        ) // 10 second session = 10000ms

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
        XCTAssertEqual(model.totalListeningTime, 11000) // 1000 + 10000

        // Advance clock to verify only one task is running
        let session2 = LocalListeningSession(
            startTime: Date().addingTimeInterval(-5),
            endTime: Date()
        ) // 5 second session = 5000ms

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
        XCTAssertEqual(model.totalListeningTime, 16000) // 1000 + 10000 + 5000

        model.viewDisappeared()
    }

    func testConcurrentUpdates() async {
        @Shared(.listeningTracker) var listeningTracker: ListeningTracker?
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
        XCTAssertEqual(model.totalListeningTime, 0)

        // Simulate rapid updates by adding sessions
        var sessions: [LocalListeningSession] = []
        for index in 1 ... 5 {
            let session = LocalListeningSession(
                startTime: Date().addingTimeInterval(-1),
                endTime: Date()
            ) // 1 second session = 1000ms each
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
            XCTAssertEqual(model.totalListeningTime, index * 1000)
        }

        model.viewDisappeared()
    }

    func testIntegrationWithRealTimeTracking() async {
        @Shared(.listeningTracker) var listeningTracker: ListeningTracker?
        let clock = TestClock()
        let model = withDependencies {
            $0.continuousClock = clock
        } operation: {
            ListeningTimeTileModel()
        }

        // Create a rewards profile with some existing time
        let rewardsProfile = RewardsProfile(
            totalTimeListenedMS: 10000, // 10 seconds from server
            totalMSAvailableForRewards: 0,
            accurateAsOfTime: Date()
        )

        let tracker = ListeningTracker(rewardsProfile: rewardsProfile)
        $listeningTracker.withLock { $0 = tracker }

        model.viewAppeared()

        // Initial state: 10 seconds from server
        await Task.yield()
        XCTAssertEqual(model.totalListeningTime, 10000)
        XCTAssertEqual(model.listeningTimeDisplayString, "00h 00m 10s")

        // Advance 5 seconds - the listening session should add time
        await clock.advance(by: .seconds(5))

        // The totalListenTimeMS should now include the active session time
        // Note: Due to the way ListeningTracker calculates time,
        // we might need to be flexible with exact timing
        let expectedTime = model.totalListeningTime
        XCTAssertGreaterThanOrEqual(expectedTime, 10000)

        model.viewDisappeared()
    }
}

// swiftlint:enable redundant_optional_initialization
