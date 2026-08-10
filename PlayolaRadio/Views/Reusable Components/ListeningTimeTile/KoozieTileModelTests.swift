//
//  KoozieTileModelTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/10/26.
//

import ConcurrencyExtras
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct KoozieTileModelTests {
  private func tracker(totalMS: Int, koozieEarned: Bool? = nil, congrats: Bool? = nil)
    -> ListeningTracker
  {
    ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: totalMS, totalMSAvailableForRewards: totalMS, accurateAsOfTime: Date(),
        rewardsExperience: "koozie_only", koozieEarned: koozieEarned,
        shouldShowKoozieCongrats: congrats))
  }

  private let info = KooziePrizeInfo(prizeId: "p1", prizeName: "Playola Koozie", requiredHours: 50)

  @Test func belowThresholdIsInProgress() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 10 * 3_600_000)  // 10h of 50h
    let model = KoozieTileModel()
    model.kooziePrizeInfo = info
    model.liveTotalMS = 10 * 3_600_000
    #expect(model.mode == .inProgress)
    #expect(model.progressPercentLabel == "20%")
    #expect(model.hoursToGoLabel == "40h 0m of listening to go")
  }

  @Test func atThresholdNotEarnedIsClaimable() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 50 * 3_600_000)
    let model = KoozieTileModel()
    model.kooziePrizeInfo = info
    model.liveTotalMS = 50 * 3_600_000
    #expect(model.mode == .claimable)
  }

  @Test func redeemTappedShowsAddressFormAndBackReturns() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 50 * 3_600_000)
    let model = KoozieTileModel()
    model.kooziePrizeInfo = info
    model.liveTotalMS = 50 * 3_600_000
    model.redeemTapped()
    #expect(model.mode == .addressForm)
    model.backTapped()
    #expect(model.mode == .claimable)
  }

  @Test func earnedWithCongratsIsCongrats() {
    @Shared(.listeningTracker) var lt = tracker(
      totalMS: 60 * 3_600_000, koozieEarned: true, congrats: true)
    let model = KoozieTileModel()
    model.kooziePrizeInfo = info
    model.liveTotalMS = 60 * 3_600_000
    #expect(model.mode == .congrats)
    #expect(model.congratsMessage == "You've earned a Playola Koozie! Thanks for listening!")
  }

  @Test func earnedWithoutCongratsIsEarned() {
    @Shared(.listeningTracker) var lt = tracker(
      totalMS: 60 * 3_600_000, koozieEarned: true, congrats: false)
    let model = KoozieTileModel()
    model.kooziePrizeInfo = info
    model.liveTotalMS = 60 * 3_600_000
    #expect(model.mode == .earned)
  }

  @Test func sendMyKoozieSuccessRefreshesToCongrats() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.listeningTracker) var lt = tracker(totalMS: 50 * 3_600_000)
    let captured = LockIsolated<KoozieShippingAddress?>(nil)
    let model = withDependencies {
      $0.api.getPrizeTiers = { [] }
      $0.api.redeemKooziePrize = { _, _, address in captured.setValue(address) }
      $0.api.getRewardsProfile = { _ in
        RewardsProfile(
          totalTimeListenedMS: 50 * 3_600_000, totalMSAvailableForRewards: 0,
          accurateAsOfTime: Date(), rewardsExperience: "koozie_only", koozieEarned: true,
          shouldShowKoozieCongrats: true)
      }
    } operation: {
      KoozieTileModel()
    }
    model.kooziePrizeInfo = info
    model.liveTotalMS = 50 * 3_600_000
    model.redeemTapped()
    model.addressForm.fullName = "Jane Doe"
    model.addressForm.addressLine1 = "123 Main St"
    model.addressForm.city = "Austin"
    model.addressForm.state = "tx"
    model.addressForm.postalCode = "78704"

    await model.sendMyKoozieTapped()

    #expect(captured.value?.state == "TX")  // uppercased
    #expect(model.mode == .congrats)
  }

  @Test func sendMyKoozieValidationErrorSurfacesInlineAndStaysOnForm() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.listeningTracker) var lt = tracker(totalMS: 50 * 3_600_000)
    let model = withDependencies {
      $0.api.redeemKooziePrize = { _, _, _ in
        throw APIError.validationError("Invalid US shipping address")
      }
    } operation: {
      KoozieTileModel()
    }
    model.kooziePrizeInfo = info
    model.liveTotalMS = 50 * 3_600_000
    model.redeemTapped()
    model.addressForm.fullName = "Jane"
    model.addressForm.addressLine1 = "1 St"
    model.addressForm.city = "Austin"
    model.addressForm.state = "TX"
    model.addressForm.postalCode = "78704"

    await model.sendMyKoozieTapped()

    #expect(model.addressForm.serverError == "Invalid US shipping address")
    #expect(model.mode == .addressForm)
  }

  @Test func startTiersLoadLaunchesSingleFetchEvenWhenCalledEveryTick() async {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 0)
    let callCount = LockIsolated(0)
    let model = withDependencies {
      $0.continuousClock = ImmediateClock()
      // Returns tiers with NO koozie slug → kooziePrizeInfo stays nil, but still a success.
      $0.api.getPrizeTiers = {
        callCount.withValue { $0 += 1 }
        return [
          PrizeTier(
            id: "t", name: "Tee", requiredListeningHours: 100, imageIconUrl: nil,
            prizes: [Prize(id: "p", name: "Tee", prizeTierId: "t", imageUrl: nil, slug: "tshirt")])
        ]
      }
    } operation: {
      KoozieTileModel()
    }

    model.startTiersLoadIfNeeded()
    model.startTiersLoadIfNeeded()
    model.startTiersLoadIfNeeded()
    await model.tiersLoadTask?.value

    #expect(callCount.value == 1)  // single task, no per-tick refetch storm
    #expect(model.kooziePrizeInfo == nil)
  }

  @Test func startTiersLoadRetriesOnFailureThenSucceeds() async {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 0)
    let callCount = LockIsolated(0)
    let model = withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.api.getPrizeTiers = {
        let attempt = callCount.withValue {
          $0 += 1
          return $0
        }
        if attempt < 3 { throw APIError.dataNotValid }
        return [
          PrizeTier(
            id: "tk", name: "Koozie", requiredListeningHours: 50, imageIconUrl: nil,
            prizes: [
              Prize(
                id: "pk", name: "Playola Koozie", prizeTierId: "tk", imageUrl: nil, slug: "koozie")
            ])
        ]
      }
    } operation: {
      KoozieTileModel()
    }

    model.startTiersLoadIfNeeded()
    await model.tiersLoadTask?.value

    #expect(callCount.value == 3)  // retried past two transient failures
    #expect(model.kooziePrizeInfo?.requiredHours == 50)
  }

  @Test func cancelTiersLoadStopsRetryingAndClearsTask() async {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 0)
    let model = withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.api.getPrizeTiers = { throw APIError.dataNotValid }  // always fails → would retry forever
    } operation: {
      KoozieTileModel()
    }

    model.startTiersLoadIfNeeded()
    let task = model.tiersLoadTask
    model.cancelTiersLoad()

    #expect(model.tiersLoadTask == nil)
    await task?.value  // terminates via cancellation; would hang forever if not cancelled
  }

  @Test func refreshOnlyUpdatesFlagsAndKeepsTimeTotal() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.listeningTracker) var lt = tracker(
      totalMS: 60 * 3_600_000, koozieEarned: true, congrats: true)
    let model = withDependencies {
      $0.api.markKoozieCongratsSeen = { _ in }
      // Server reports a DIFFERENT (much higher) total; the client must NOT adopt it mid-session,
      // or it would double-count local listening already reflected in the fresh server total.
      $0.api.getRewardsProfile = { _ in
        RewardsProfile(
          totalTimeListenedMS: 999 * 3_600_000, totalMSAvailableForRewards: 0,
          accurateAsOfTime: Date(), rewardsExperience: "koozie_only", koozieEarned: true,
          shouldShowKoozieCongrats: false)
      }
    } operation: {
      KoozieTileModel()
    }
    model.kooziePrizeInfo = info
    model.liveTotalMS = 60 * 3_600_000

    await model.dismissCongratsTapped()

    #expect(model.mode == .earned)  // flag adopted
    #expect(lt?.rewardsProfile.totalTimeListenedMS == 60 * 3_600_000)  // total NOT jumped
  }

  @Test func dismissCongratsOptimisticallyShowsEarned() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.listeningTracker) var lt = tracker(
      totalMS: 60 * 3_600_000, koozieEarned: true, congrats: true)
    let model = withDependencies {
      $0.api.markKoozieCongratsSeen = { _ in }
      $0.api.getRewardsProfile = { _ in
        RewardsProfile(
          totalTimeListenedMS: 60 * 3_600_000, totalMSAvailableForRewards: 0,
          accurateAsOfTime: Date(), rewardsExperience: "koozie_only", koozieEarned: true,
          shouldShowKoozieCongrats: false)
      }
    } operation: {
      KoozieTileModel()
    }
    model.kooziePrizeInfo = info
    model.liveTotalMS = 60 * 3_600_000

    await model.dismissCongratsTapped()

    #expect(model.mode == .earned)
  }
}
