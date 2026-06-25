import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

// Serialized: these tests mutate the file-backed `@Shared(.giveawayParticipations)` store under a
// shared key, so parallel Swift Testing could interleave across `await` points and cross-contaminate
// the on-disk state.
@MainActor
@Suite(.serialized)
struct GiveawayCoordinatorTests {
  private struct BoomError: Error {}

  private func playolaNowPlaying(id: String = "s1") -> NowPlaying {
    NowPlaying.mockWith(station: AnyStation.mockPlayola(id: id))
  }

  // MARK: - revealDelay (skew math)

  @Test func revealDelaySubtractsHalfRTT() {
    let serverTime = Date(timeIntervalSince1970: 1000)
    let opensAt = serverTime.addingTimeInterval(60)
    #expect(
      GiveawayCoordinator.revealDelay(opensAt: opensAt, serverTime: serverTime, rtt: .zero)
        == .seconds(60))
    #expect(
      GiveawayCoordinator.revealDelay(opensAt: opensAt, serverTime: serverTime, rtt: .seconds(2))
        == .seconds(59))
  }

  @Test func revealDelayFloorsAtZeroWhenAlreadyOpen() {
    let serverTime = Date(timeIntervalSince1970: 1000)
    let opensAt = serverTime.addingTimeInterval(-5)
    #expect(
      GiveawayCoordinator.revealDelay(opensAt: opensAt, serverTime: serverTime, rtt: .zero)
        == .zero)
  }

  // MARK: - selectEvent

  @Test func selectEventPrefersOpenThenSoonestScheduled() {
    let base = Date(timeIntervalSince1970: 1000)
    func event(_ id: String, _ status: GiveawayStatus, opensIn seconds: TimeInterval)
      -> GiveawayEvent
    {
      GiveawayEvent(
        id: id, stationId: "s1", prizeName: "P", winningNumber: 9, status: status,
        opensAt: base.addingTimeInterval(seconds))
    }
    // An open event wins even if a scheduled one opens sooner numerically.
    #expect(
      GiveawayCoordinator.selectEvent(from: [
        event("sched", .scheduled, opensIn: 10), event("open", .open, opensIn: 999),
      ])?.id == "open")
    // Among scheduled, the soonest opensAt wins (feed order is not meaningful).
    #expect(
      GiveawayCoordinator.selectEvent(from: [
        event("late", .scheduled, opensIn: 500), event("soon", .scheduled, opensIn: 10),
      ])?.id == "soon")
    #expect(GiveawayCoordinator.selectEvent(from: []) == nil)
  }

  // MARK: - reconcile

  @Test func reconcilePublishesOpenEventForCurrentStation() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    await withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        [
          GiveawayEvent(
            id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .open,
            opensAt: Date(timeIntervalSince1970: 1000))
        ]
      }
      $0.api.giveawayEvent = { _, id in
        GiveawayEvent(
          id: id, stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .open)
      }
    } operation: {
      await GiveawayCoordinator().reconcile()
    }
    #expect(activeGiveaway?.id == "e1")
  }

  @Test func reconcileClearsStaleCrossStationEventWhenFeedEmpty() async {
    // .mock is on "station-1"; we're playing "s1" → the stale cross-station event is dropped.
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = .mock
    await withDependencies {
      $0.api.giveawayEventsFeed = { _ in [] }
    } operation: {
      await GiveawayCoordinator().reconcile()
    }
    #expect(activeGiveaway == nil)
  }

  @Test func reconcileKeepsSameStationEventWhenFeedTransientlyEmpty() async {
    // A transient empty feed (e.g. right at the open transition) must NOT tear down a same-station
    // event that's still open — otherwise the reveal vanishes the instant it opens. The
    // authoritative GET confirms it's open, so it stays.
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = GiveawayEvent(
      id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .open)
    await withDependencies {
      $0.api.giveawayEventsFeed = { _ in [] }
      $0.api.giveawayEvent = { _, id in
        GiveawayEvent(
          id: id, stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .open)
      }
    } operation: {
      await GiveawayCoordinator().reconcile()
    }
    #expect(activeGiveaway?.id == "e1")
  }

  @Test func reconcileClearsSameStationEventOnceClosed() async {
    // A closed contest also leaves the feed; the authoritative GET says closed, so the overlay
    // must stop showing it (no lingering TAP button on a closed contest).
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = GiveawayEvent(
      id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .open)
    await withDependencies {
      $0.api.giveawayEventsFeed = { _ in [] }
      $0.api.giveawayEvent = { _, id in
        GiveawayEvent(
          id: id, stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .closed)
      }
    } operation: {
      await GiveawayCoordinator().reconcile()
    }
    #expect(activeGiveaway == nil)
  }

  @Test func reconcileClearsWhenNotOnPlayolaStation() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = .mock
    await GiveawayCoordinator().reconcile()
    #expect(activeGiveaway == nil)
  }

  @Test func reconcileKeepsLastValueWhenFeedErrors() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying()
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = .mock
    await withDependencies {
      $0.api.giveawayEventsFeed = { _ in throw BoomError() }
    } operation: {
      await GiveawayCoordinator().reconcile()
    }
    #expect(activeGiveaway != nil)
  }

  @Test func reconcileDoesNotRevealScheduledEventImmediately() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying()
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    await withDependencies {
      $0.continuousClock = TestClock()
      $0.api.giveawayEventsFeed = { _ in
        [
          GiveawayEvent(
            id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9,
            status: .scheduled, opensAt: Date(timeIntervalSince1970: 9_999_999_999))
        ]
      }
      $0.api.giveawayEvent = { _, id in
        GiveawayEvent(
          id: id, stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .scheduled,
          opensAt: Date(timeIntervalSince1970: 9_999_999_999),
          serverTime: Date(timeIntervalSince1970: 1000))
      }
    } operation: {
      await GiveawayCoordinator().reconcile()
    }
    #expect(activeGiveaway == nil)
  }

  @Test func revealFromHeldEventPublishesOpenWithoutAGet() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    let scheduled = GiveawayEvent(
      id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .scheduled)

    GiveawayCoordinator().revealFromHeldEvent(scheduled, expectedStationId: "s1")

    // Published straight from the held event, flipped to .open. The id is "e1" (not the detail GET's
    // ".mock"/"event-1"), proving the reveal did NOT make a network round-trip.
    #expect(activeGiveaway?.id == "e1")
    #expect(activeGiveaway?.status == .open)
  }

  @Test func revealFromHeldEventSkipsWhenStationChanged() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "other")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    let scheduled = GiveawayEvent(
      id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .scheduled)

    GiveawayCoordinator().revealFromHeldEvent(scheduled, expectedStationId: "s1")

    #expect(activeGiveaway == nil)
  }

  // MARK: - tap

  private func openEvent(id: String = "e1") -> GiveawayEvent {
    GiveawayEvent(
      id: id, stationId: "s1", prizeName: "Two tickets", prizeDescription: "Front row",
      winningNumber: 9, status: .open, giveawayId: "gv1")
  }

  @Test func tapPersistsResolvedLossOnNonWinningTap() async {
    await withMainSerialExecutor {
      let tappedAt = Date(timeIntervalSince1970: 1000)
      @Shared(.auth) var auth = Auth(jwt: "jwt")
      @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
      $participations.withLock { $0 = [:] }
      await withDependencies {
        $0.date = .constant(tappedAt)
        $0.api.tapGiveawayEvent = { _, _ in
          GiveawayTapResponse(tapNumber: 7, isWinner: false, status: .open)
        }
      } operation: {
        try? await GiveawayCoordinator().tap(event: openEvent())
      }
      // Resolved immediately from the tap response, keyed by the per-airing event id.
      expectNoDifference(
        participations["e1"],
        GiveawayParticipation(
          id: "e1", stationId: "s1", prizeName: "Two tickets", prizeDescription: "Front row",
          winningNumber: 9, tapNumber: 7, status: .resolvedLost(toastShown: false),
          tappedAt: tappedAt))
    }
  }

  @Test func tapPersistsResolvedWonOnWinningTap() async {
    await withMainSerialExecutor {
      let tappedAt = Date(timeIntervalSince1970: 1000)
      @Shared(.auth) var auth = Auth(jwt: "jwt")
      @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
      $participations.withLock { $0 = [:] }
      await withDependencies {
        $0.date = .constant(tappedAt)
        $0.api.tapGiveawayEvent = { _, _ in
          GiveawayTapResponse(tapNumber: 9, isWinner: true, status: .open)
        }
      } operation: {
        try? await GiveawayCoordinator().tap(event: openEvent())
      }
      expectNoDifference(
        participations["e1"],
        GiveawayParticipation(
          id: "e1", stationId: "s1", prizeName: "Two tickets", prizeDescription: "Front row",
          winningNumber: 9, tapNumber: 9, status: .resolvedWon(submissionCompleted: false),
          tappedAt: tappedAt))
    }
  }

  @Test func tapWithoutJWTIsNoOp() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth()
      @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
      $participations.withLock { $0 = [:] }
      // The default tap stub would persist a participation if the JWT guard failed to short-circuit.
      try? await GiveawayCoordinator().tap(event: openEvent())
      #expect(participations["e1"] == nil)
    }
  }

  @Test func tapIgnoredWhenAlreadyParticipating() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "jwt")
      // A sentinel tapNumber that the success stub (5) would overwrite if the dedup guard failed.
      @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
      $participations.withLock {
        $0 = [
          "e1": GiveawayParticipation(
            id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9, tapNumber: 99,
            status: .tappedStandby, tappedAt: Date(timeIntervalSince1970: 500))
        ]
      }
      await withDependencies {
        $0.api.tapGiveawayEvent = { _, _ in .mock }
      } operation: {
        try? await GiveawayCoordinator().tap(event: openEvent())
      }
      #expect(participations["e1"]?.tapNumber == 99)
    }
  }

  @Test func tapStaysSilentAndDoesNotPersistOnNotOpenYet() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "jwt")
      @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
      $participations.withLock { $0 = [:] }
      // A 400 race is surfaced by the API as `.notOpenYet`; tap swallows it silently (no rethrow).
      await withDependencies {
        $0.api.tapGiveawayEvent = { _, _ in throw GiveawayTapError.notOpenYet }
      } operation: {
        try? await GiveawayCoordinator().tap(event: openEvent())
      }
      #expect(participations["e1"] == nil)
    }
  }

  @Test func tapRethrowsUnexpectedErrorAndDoesNotPersist() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "jwt")
      @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
      $participations.withLock { $0 = [:] }
      await #expect(throws: BoomError.self) {
        try await withDependencies {
          $0.api.tapGiveawayEvent = { _, _ in throw BoomError() }
        } operation: {
          try await GiveawayCoordinator().tap(event: openEvent())
        }
      }
      #expect(participations["e1"] == nil)
    }
  }

  // MARK: - Loss Backstop

  private func lostParticipation() -> GiveawayParticipation {
    GiveawayParticipation(
      id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9, tapNumber: 5,
      status: .resolvedLost(toastShown: true), tappedAt: Date(timeIntervalSince1970: 100))
  }

  @Test func backstopFlipsLossToWinWhenPromoted() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "jwt")
      @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
      $participations.withLock { $0 = ["e1": lostParticipation()] }
      await withDependencies {
        $0.api.giveawayEventMyResult = { _, _ in
          GiveawayMyResult(tapNumber: 5, isWinner: true, status: .closed, winningNumber: 9)
        }
      } operation: {
        await GiveawayCoordinator().reconcileResolvedLoss(jwt: "jwt", eventId: "e1")
      }
      #expect(
        participations["e1"]?.status
          == GiveawayParticipationStatus.resolvedWon(submissionCompleted: false))
    }
  }

  @Test func backstopLeavesLossWhenStillLost() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "jwt")
      @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
      $participations.withLock { $0 = ["e1": lostParticipation()] }
      await withDependencies {
        $0.api.giveawayEventMyResult = { _, _ in
          GiveawayMyResult(tapNumber: 5, isWinner: false, status: .closed, winningNumber: 9)
        }
      } operation: {
        await GiveawayCoordinator().reconcileResolvedLoss(jwt: "jwt", eventId: "e1")
      }
      #expect(
        participations["e1"]?.status
          == GiveawayParticipationStatus.resolvedLost(toastShown: true))
    }
  }

  @Test func backstopIgnoresStillOpenResult() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "jwt")
      @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
      $participations.withLock { $0 = ["e1": lostParticipation()] }
      await withDependencies {
        $0.api.giveawayEventMyResult = { _, _ in
          GiveawayMyResult(tapNumber: 5, isWinner: false, status: .open, winningNumber: 9)
        }
      } operation: {
        await GiveawayCoordinator().reconcileResolvedLoss(jwt: "jwt", eventId: "e1")
      }
      #expect(
        participations["e1"]?.status
          == GiveawayParticipationStatus.resolvedLost(toastShown: true))
    }
  }

  @Test func foregroundReconcileFlipsRecentLossButSkipsStale() async {
    await withMainSerialExecutor {
      let nowDate = Date(timeIntervalSince1970: 1_000_000)
      @Shared(.auth) var auth = Auth(jwt: "jwt")
      @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
      $participations.withLock {
        $0 = [
          "recent": GiveawayParticipation(
            id: "recent", stationId: "s1", prizeName: "P", winningNumber: 9, tapNumber: 5,
            status: .resolvedLost(toastShown: true), tappedAt: nowDate.addingTimeInterval(-60)),
          "stale": GiveawayParticipation(
            id: "stale", stationId: "s1", prizeName: "P", winningNumber: 9, tapNumber: 5,
            status: .resolvedLost(toastShown: true),
            tappedAt: nowDate.addingTimeInterval(-7 * 60 * 60)),
        ]
      }
      await withDependencies {
        $0.date = .constant(nowDate)
        $0.api.giveawayEventMyResult = { _, _ in
          GiveawayMyResult(tapNumber: 5, isWinner: true, status: .closed, winningNumber: 9)
        }
      } operation: {
        await GiveawayCoordinator().reconcileRecentResolvedLosses()
      }
      #expect(
        participations["recent"]?.status
          == GiveawayParticipationStatus.resolvedWon(submissionCompleted: false))
      #expect(
        participations["stale"]?.status
          == GiveawayParticipationStatus.resolvedLost(toastShown: true))
    }
  }
}

// swiftlint:enable redundant_optional_initialization
