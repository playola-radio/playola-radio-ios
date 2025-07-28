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

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    XCTAssertTrue(model.prizeTiers.isEmpty)

    await model.onViewAppeared()

    XCTAssertEqual(model.prizeTiers.count, mockPrizeTiers.count)
    XCTAssertEqual(model.prizeTiers, mockPrizeTiers)
  }

  func testOnViewAppeared_LoadsPrizesFromTiers() async {
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
}

// swiftlint:enable redundant_optional_initialization
