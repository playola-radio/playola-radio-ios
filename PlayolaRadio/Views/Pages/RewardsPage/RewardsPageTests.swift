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

// swiftlint:disable force_cast redundant_optional_initialization

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

  // MARK: - Prizes Loading Tests

  func testOnViewAppeared_LoadsPrizes() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(totalTimeMS: 0)
    let mockPrizes = Prize.mocks

    let model = withDependencies {
      $0.api.getPrizes = { mockPrizes }
    } operation: {
      RewardsPageModel()
    }

    XCTAssertTrue(model.prizes.isEmpty)

    await model.onViewAppeared()

    XCTAssertEqual(model.prizes.count, mockPrizes.count)
    XCTAssertEqual(model.prizes, mockPrizes)
  }

}

// swiftlint:enable force_cast redundant_optional_initialization
