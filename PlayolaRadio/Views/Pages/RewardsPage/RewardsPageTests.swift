//
//  RewardsPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Combine
import ConcurrencyExtras
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@Suite(.freshSharedState)
@MainActor
struct RewardsPageModelTests {
  func createMockListeningTracker(totalTimeMS: Int) -> ListeningTracker {
    let rewardsProfile = RewardsProfile(
      totalTimeListenedMS: totalTimeMS,
      totalMSAvailableForRewards: 0,
      accurateAsOfTime: Date()
    )
    return ListeningTracker(rewardsProfile: rewardsProfile)
  }

  private var emptyTier: PrizeTier {
    PrizeTier(id: "empty", name: "Empty", requiredListeningHours: 0, imageIconUrl: nil, prizes: [])
  }

  // MARK: - Prize Tiers Loading Tests

  @Test
  func testOnViewAppearedLoadsPrizeTiers() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(totalTimeMS: 0)
    let mockPrizeTiers = PrizeTier.mocks

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    await model.viewAppeared()

    #expect(model.prizeTiers.count == 3)

    let tierNames = model.prizeTiers.map { $0.name }
    #expect(tierNames.contains("Koozie"))
    #expect(tierNames.contains("T-Shirt"))
    #expect(tierNames.contains("Show Tix"))
  }

  // MARK: - Analytics Tests

  @Test
  func testOnViewAppearedTracksRewardsScreenAnalytics() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(
      totalTimeMS: 54_000_000)
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

    await model.viewAppeared()

    let events = capturedEvents.value
    #expect(events.count == 1)
    if case .viewedRewardsScreen(let currentHours) = events.first {
      #expect(abs(currentHours - 15.0) < 0.1)
    } else {
      Issue.record("Expected viewedRewardsScreen event, got: \(String(describing: events.first))")
    }
  }

  @Test
  func testRedeemPrizeTracksRedeemAnalytics() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(
      totalTimeMS: 108_000_000)
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()
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

    await model.redeemPrizeTapped(for: mockPrizeTiers[0])

    let events = capturedEvents.value
    #expect(events.count == 1)
    if case .tappedRedeemRewards(let currentHours) = events.first {
      #expect(abs(currentHours - 30.0) < 0.1)
    } else {
      Issue.record("Expected tappedRedeemRewards event, got: \(String(describing: events.first))")
    }
  }

  @Test
  func testRedeemOpensClaimSheetForTiersSinglePrize() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = RewardsPageModel()

    await model.redeemPrizeTapped(for: .mock)

    guard case .claim(let sheet) = coordinator.presentedSheet else {
      Issue.record("expected claim sheet")
      return
    }
    #expect(sheet.phase == .notYetClaimed)
    #expect(sheet.prizeTitle == PrizeTier.mock.prizes[0].name)
  }

  @Test
  func testClaimMarksTierRedeemed() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = withDependencies {
      $0.api.createRewardRedemption = { _, _ in .mock(source: .reward, giveawayEventId: nil) }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      RewardsPageModel()
    }
    await model.redeemPrizeTapped(for: .mock)
    guard case .claim(let sheet) = coordinator.presentedSheet else {
      Issue.record("expected claim sheet")
      return
    }

    await sheet.claimItTapped()

    #expect(model.redemptionStatus(for: .mock) == .redeemed)
  }

  @Test
  func testClosingClaimSheetDismissesIt() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = RewardsPageModel()
    await model.redeemPrizeTapped(for: .mock)
    guard case .claim(let sheet) = coordinator.presentedSheet else {
      Issue.record("expected claim sheet")
      return
    }

    sheet.laterTapped()

    #expect(coordinator.presentedSheet == nil)
  }

  @Test
  func testClosingClaimSheetLeavesADifferentSheetPresented() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = RewardsPageModel()
    await model.redeemPrizeTapped(for: .mock)
    guard case .claim(let sheet) = coordinator.presentedSheet else {
      Issue.record("expected claim sheet")
      return
    }
    let other = PlayolaSheet.share(ShareSheetModel(items: []))
    $coordinator.withLock { $0.presentedSheet = other }

    sheet.laterTapped()

    #expect(coordinator.presentedSheet == other)
  }

  @Test
  func testRedeemWithoutPrizeDoesNotPresentASheet() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = RewardsPageModel()

    await model.redeemPrizeTapped(for: emptyTier)

    #expect(coordinator.presentedSheet == nil)
  }

  @Test
  func testTierWithoutPrizeIsUnavailable() {
    let model = RewardsPageModel()
    #expect(model.redemptionStatus(for: emptyTier) == .unavailable)
  }

  @Test
  func testRedeemedTakesPrecedenceOverUnavailable() {
    let model = RewardsPageModel()
    model.redeemedPrizeTierIds.insert(emptyTier.id)
    #expect(model.redemptionStatus(for: emptyTier) == .redeemed)
  }

  @Test
  func testLoadUserPrizesPopulatesRedeemedTierIds() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(totalTimeMS: 0)
    @Shared(.auth) var auth = Auth(jwt: "test-token")
    let mockPrizeTiers = PrizeTier.mocks
    let mockPrize = mockPrizeTiers[0].prizes[0]
    let mockUserPrizes = [
      UserPrize(
        id: "up-1", userId: "user-1", prizeId: mockPrize.id, prize: mockPrize)
    ]

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
      $0.api.getUserPrizes = { _ in mockUserPrizes }
    } operation: {
      RewardsPageModel()
    }

    await model.viewAppeared()

    #expect(model.redeemedPrizeTierIds.contains(mockPrizeTiers[0].id))
  }

  // MARK: - Redemption Status Tests

  @Test
  func testRedemptionStatusRedeemed() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(
      totalTimeMS: 50 * 60 * 60 * 1000)
    let mockPrizeTiers = PrizeTier.mocks

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    await model.viewAppeared()

    let koozieId = mockPrizeTiers[0].id
    model.redeemedPrizeTierIds.insert(koozieId)

    let status = model.redemptionStatus(for: mockPrizeTiers[0])

    if case .redeemed = status {
      // Test passes
    } else {
      Issue.record("Expected redeemed status, got \(status)")
    }
  }

  @Test
  func testRedemptionStatusRedeemable() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(
      totalTimeMS: 35 * 60 * 60 * 1000)
    let mockPrizeTiers = PrizeTier.mocks

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    await model.viewAppeared()

    let tshirtTier = mockPrizeTiers[1]
    let status = model.redemptionStatus(for: tshirtTier)

    if case .redeemable = status {
      // Test passes
    } else {
      Issue.record("Expected redeemable status, got \(status)")
    }
  }

  @Test
  func testRedemptionStatusMoreTimeRequired() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(
      totalTimeMS: 25 * 60 * 60 * 1000)
    let mockPrizeTiers = PrizeTier.mocks

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    await model.viewAppeared()

    let showTixTier = mockPrizeTiers[2]
    let status = model.redemptionStatus(for: showTixTier)

    if case .moreTimeRequired(let hoursToGo) = status {
      #expect(hoursToGo == 45, "Expected 45 hours to go, got \(hoursToGo)")
    } else {
      Issue.record("Expected moreTimeRequired status, got \(status)")
    }
  }

  @Test
  func testRedemptionStatusZeroListeningTime() async {
    @Shared(.listeningTracker) var listeningTracker = createMockListeningTracker(totalTimeMS: 0)
    let mockPrizeTiers = PrizeTier.mocks

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    await model.viewAppeared()

    let koozieIdTier = mockPrizeTiers[0]
    let status = model.redemptionStatus(for: koozieIdTier)

    if case .moreTimeRequired(let hoursToGo) = status {
      #expect(hoursToGo == 10, "Expected 10 hours to go, got \(hoursToGo)")
    } else {
      Issue.record("Expected moreTimeRequired status, got \(status)")
    }
  }

  @Test
  func testRedemptionStatusNilListeningTracker() async {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = nil
    let mockPrizeTiers = PrizeTier.mocks

    let model = withDependencies {
      $0.api.getPrizeTiers = { mockPrizeTiers }
    } operation: {
      RewardsPageModel()
    }

    await model.viewAppeared()

    let koozieIdTier = mockPrizeTiers[0]
    let status = model.redemptionStatus(for: koozieIdTier)

    if case .moreTimeRequired(let hoursToGo) = status {
      #expect(hoursToGo == 10, "Expected 10 hours to go with nil tracker, got \(hoursToGo)")
    } else {
      Issue.record("Expected moreTimeRequired status with nil tracker, got \(status)")
    }
  }
}

// swiftlint:enable redundant_optional_initialization
