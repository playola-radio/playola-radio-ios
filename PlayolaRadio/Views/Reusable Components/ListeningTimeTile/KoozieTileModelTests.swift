//
//  KoozieTileModelTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/10/26.
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct KoozieTileModelTests {
  private func tracker(totalMS: Int, koozieEarned: Bool? = nil)
    -> ListeningTracker
  {
    // ListeningTracker subscribes to @Shared(.nowPlaying) in init; seed it locally (in the
    // test's fresh scope) so no leaked playback state can start a session and skew totals.
    // swiftlint:disable:next redundant_optional_initialization
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    return ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: totalMS, totalMSAvailableForRewards: totalMS, accurateAsOfTime: Date(),
        rewardsExperience: "koozie_only", koozieEarned: koozieEarned))
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

  @Test func claimedLocallyShowsEarnedBeforeProfileCatchesUp() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 51 * 3_600_000)
    let model = KoozieTileModel()
    model.kooziePrizeInfo = info
    model.liveTotalMS = 51 * 3_600_000
    #expect(model.mode == .claimable)
    model.markClaimed()
    #expect(model.mode == .earned)
    #expect(!model.isClaimable)
  }

  @Test func earnedProfileIsNotClaimable() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 60 * 3_600_000, koozieEarned: true)
    let model = KoozieTileModel()
    model.kooziePrizeInfo = info
    model.liveTotalMS = 60 * 3_600_000
    #expect(model.mode == .earned)
    #expect(!model.isClaimable)
  }

  @Test func belowThresholdIsNotClaimable() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 10 * 3_600_000)
    let model = KoozieTileModel()
    model.kooziePrizeInfo = info
    model.liveTotalMS = 10 * 3_600_000
    #expect(!model.isClaimable)
  }

  @Test func rewardClaimIsBuiltFromKooziePrizeInfoWhenClaimable() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 50 * 3_600_000)
    let model = KoozieTileModel()
    model.kooziePrizeInfo = info
    model.liveTotalMS = 50 * 3_600_000
    expectNoDifference(
      model.rewardClaim,
      RewardClaim(
        prizeId: "p1", prizeSlug: "koozie", prizeTitle: "Playola Koozie", prizeImageUrl: nil,
        requiredHours: 50))
  }

  @Test func rewardClaimIsNilWhenNotClaimable() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 10 * 3_600_000)
    let model = KoozieTileModel()
    model.kooziePrizeInfo = info
    model.liveTotalMS = 10 * 3_600_000
    #expect(model.rewardClaim == nil)
  }

  @Test func copy() {
    let model = KoozieTileModel()
    #expect(model.claimableTitle == "You earned a koozie!")
    #expect(model.claimableSubtitle == "Claim it from your prize tile above.")
    #expect(model.earnedText == "Koozie claimed — thanks for listening!")
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
    await withMainSerialExecutor {
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
                  id: "pk", name: "Playola Koozie", prizeTierId: "tk", imageUrl: nil, slug: "koozie"
                )
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
    @Shared(.listeningTracker) var lt = tracker(totalMS: 50 * 3_600_000)
    let model = withDependencies {
      // Server reports a DIFFERENT (much higher) total; the client must NOT adopt it mid-session,
      // or it would double-count local listening already reflected in the fresh server total.
      $0.api.getRewardsProfile = { _ in
        RewardsProfile(
          totalTimeListenedMS: 999 * 3_600_000, totalMSAvailableForRewards: 0,
          accurateAsOfTime: Date(), rewardsExperience: "koozie_only", koozieEarned: true)
      }
    } operation: {
      KoozieTileModel()
    }
    model.kooziePrizeInfo = info
    model.liveTotalMS = 50 * 3_600_000

    await model.refreshProfile()

    #expect(model.mode == .earned)
    #expect(lt?.rewardsProfile.totalTimeListenedMS == 50 * 3_600_000)
  }

  @Test func claimedOverrideSurvivesStaleOrFailedRefresh() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.listeningTracker) var lt = tracker(totalMS: 50 * 3_600_000)
    let refreshResult = LockIsolated<Result<RewardsProfile, APIError>>(.failure(.dataNotValid))
    let model = withDependencies {
      $0.api.getRewardsProfile = { _ in try refreshResult.value.get() }
    } operation: {
      KoozieTileModel()
    }
    model.kooziePrizeInfo = info
    model.liveTotalMS = 50 * 3_600_000

    model.markClaimed()
    await model.refreshProfile()
    #expect(model.mode == .earned)
    #expect(!model.isClaimable)

    refreshResult.setValue(
      .success(
        RewardsProfile(
          totalTimeListenedMS: 50 * 3_600_000, totalMSAvailableForRewards: 0,
          accurateAsOfTime: Date(), rewardsExperience: "koozie_only", koozieEarned: false)))
    await model.refreshProfile()
    #expect(model.mode == .earned)
    #expect(!model.isClaimable)
  }
}
