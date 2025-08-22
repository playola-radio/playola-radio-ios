//
//  RewardsPageTests.swift
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
final class RewardsPageModelTests: XCTestCase {
  func createMockListeningTracker(totalTimeMS: Int) -> ListeningTracker {
    let rewardsProfile = RewardsProfile(
      totalTimeListenedMS: totalTimeMS,
      totalMSAvailableForRewards: 0,
      accurateAsOfTime: Date()
    )
    return ListeningTracker(rewardsProfile: rewardsProfile)
  }

  // MARK: - Prize Tiers Loading Tests

  func testOnViewAppeared_LoadsPrizeTiers() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(totalTimeMS: 0)
    let mockPrizeTiers = PrizeTier.mocks
    let expectedPrizeCount = mockPrizeTiers.flatMap { $0.prizes }.count

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    await model.onViewAppeared()

    XCTAssertEqual(model.prizeTiers.count, 3)  // Based on our mock data

    // Verify we have the expected tiers
    let tierNames = model.prizeTiers.map { $0.name }
    XCTAssertTrue(tierNames.contains("Koozie"))
    XCTAssertTrue(tierNames.contains("T-Shirt"))
    XCTAssertTrue(tierNames.contains("Show Tix"))
  }

  // MARK: - Analytics Tests

  func testOnViewAppeared_TracksRewardsScreenAnalytics() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(
      totalTimeMS: 54_000_000)  // 15 hours
    let mockPrizeTiers = PrizeTier.mocks
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      RewardsPageModel()
    }

    await model.onViewAppeared()

    // Verify analytics event was tracked
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 1)
    if case .viewedRewardsScreen(let currentHours) = events.first {
      XCTAssertEqual(currentHours, 15.0, accuracy: 0.1)
    } else {
      XCTFail("Expected viewedRewardsScreen event, got: \(String(describing: events.first))")
    }
  }

  func testRedeemPrize_TracksRedeemAnalytics() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(
      totalTimeMS: 108_000_000)  // 30 hours
    let mockPrizeTiers = PrizeTier.mocks
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      RewardsPageModel()
    }

    await model.redeemPrize(for: mockPrizeTiers[0])  // Redeem Koozie

    // Verify analytics event was tracked
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 1)
    if case .tappedRedeemRewards(let currentHours) = events.first {
      XCTAssertEqual(currentHours, 30.0, accuracy: 0.1)
    } else {
      XCTFail("Expected tappedRedeemRewards event, got: \(String(describing: events.first))")
    }
  }

  // MARK: - Redemption Status Tests

  func testRedemptionStatus_Redeemed() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(
      totalTimeMS: 50 * 60 * 60 * 1000)  // 50 hours
    let mockPrizeTiers = PrizeTier.mocks

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    await model.onViewAppeared()

    // Simulate the user has redeemed the first tier (Koozie - 10 hours)
    let koozieId = mockPrizeTiers[0].id
    model.redeemedPrizeTierIds.insert(koozieId)

    let status = model.redemptionStatus(for: mockPrizeTiers[0])

    if case .redeemed = status {
      // Test passes
    } else {
      XCTFail("Expected redeemed status, got \(status)")
    }
  }

  func testRedemptionStatus_Redeemable() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(
      totalTimeMS: 35 * 60 * 60 * 1000)  // 35 hours
    let mockPrizeTiers = PrizeTier.mocks

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    await model.onViewAppeared()

    // User has 35 hours, T-Shirt requires 30 hours - should be redeemable
    let tshirtTier = mockPrizeTiers[1]  // T-Shirt tier
    let status = model.redemptionStatus(for: tshirtTier)

    if case .redeemable = status {
      // Test passes
    } else {
      XCTFail("Expected redeemable status, got \(status)")
    }
  }

  func testRedemptionStatus_MoreTimeRequired() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(
      totalTimeMS: 25 * 60 * 60 * 1000)  // 25 hours
    let mockPrizeTiers = PrizeTier.mocks

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    await model.onViewAppeared()

    // User has 25 hours, Show Tix requires 70 hours - should need 45 more hours
    let showTixTier = mockPrizeTiers[2]  // Show Tix tier (70 hours required)
    let status = model.redemptionStatus(for: showTixTier)

    if case .moreTimeRequired(let hoursToGo) = status {
      XCTAssertEqual(hoursToGo, 45, "Expected 45 hours to go, got \(hoursToGo)")
    } else {
      XCTFail("Expected moreTimeRequired status, got \(status)")
    }
  }

  func testRedemptionStatus_ZeroListeningTime() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(totalTimeMS: 0)
    let mockPrizeTiers = PrizeTier.mocks

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    await model.onViewAppeared()

    // User has 0 hours, Koozie requires 10 hours - should need 10 more hours
    let koozieIdTier = mockPrizeTiers[0]  // Koozie tier (10 hours required)
    let status = model.redemptionStatus(for: koozieIdTier)

    if case .moreTimeRequired(let hoursToGo) = status {
      XCTAssertEqual(hoursToGo, 10, "Expected 10 hours to go, got \(hoursToGo)")
    } else {
      XCTFail("Expected moreTimeRequired status, got \(status)")
    }
  }

  func testRedemptionStatus_NilListeningTracker() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    let mockPrizeTiers = PrizeTier.mocks

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    await model.onViewAppeared()

    // With nil listening tracker, should default to 0 hours and need full requirement
    let koozieIdTier = mockPrizeTiers[0]  // Koozie tier (10 hours required)
    let status = model.redemptionStatus(for: koozieIdTier)

    if case .moreTimeRequired(let hoursToGo) = status {
      XCTAssertEqual(hoursToGo, 10, "Expected 10 hours to go with nil tracker, got \(hoursToGo)")
    } else {
      XCTFail("Expected moreTimeRequired status with nil tracker, got \(status)")
    }
  }
}

// swiftlint:enable redundant_optional_initialization
