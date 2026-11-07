// swiftlint:disable file_length
import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

// Serialized: these tests mutate the file-backed `@Shared(.giveawayParticipations)` store under a
// shared key, so parallel Swift Testing could interleave across `await` points and cross-contaminate
// the on-disk state.
@MainActor
@Suite(.serialized, .freshSharedState)
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

  @Test func reconcileClearsActiveButKeepsUpcomingWhenNotOnPlayolaStation() async {
    // Not on a Playola station: the open event is torn down, but the all-stations "coming up"
    // projection must still populate so badges show while browsing the list without playback.
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = .mock
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = []
    await withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        [
          GiveawayEvent(
            id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9,
            status: .scheduled, opensAt: Date(timeIntervalSince1970: 1000))
        ]
      }
    } operation: {
      await GiveawayCoordinator().reconcile()
    }
    #expect(activeGiveaway == nil)
    #expect(upcomingGiveaways[id: "s1"]?.event.id == "e1")
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

  // MARK: - upcoming projection

  @Test func reconcileProjectsSoonestScheduledPerStationExcludingNonScheduled() async {
    // The feed mixes statuses across stations. The projection keeps exactly one entry per station —
    // the soonest-opening scheduled event — and excludes open/closed/canceled/unknown entirely.
    let base = Date(timeIntervalSince1970: 1000)
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = []
    await withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        [
          GiveawayEvent(
            id: "s1-late", stationId: "s1", prizeName: "P", winningNumber: 9, status: .scheduled,
            opensAt: base.addingTimeInterval(500)),
          GiveawayEvent(
            id: "s1-soon", stationId: "s1", prizeName: "P", winningNumber: 9, status: .scheduled,
            opensAt: base.addingTimeInterval(10)),
          GiveawayEvent(
            id: "s1-open", stationId: "s1", prizeName: "P", winningNumber: 9, status: .open,
            opensAt: base),
          GiveawayEvent(
            id: "s2-sched", stationId: "s2", prizeName: "P", winningNumber: 9, status: .scheduled,
            opensAt: base.addingTimeInterval(60)),
          GiveawayEvent(
            id: "s3-closed", stationId: "s3", prizeName: "P", winningNumber: 9, status: .closed,
            opensAt: base),
        ]
      }
      $0.api.giveawayEvent = { _, id in
        GiveawayEvent(id: id, stationId: "s1", prizeName: "P", winningNumber: 9, status: .open)
      }
    } operation: {
      await GiveawayCoordinator().reconcile()
    }
    #expect(upcomingGiveaways.count == 2)
    #expect(upcomingGiveaways[id: "s1"]?.event.id == "s1-soon")
    #expect(upcomingGiveaways[id: "s2"]?.event.id == "s2-sched")
    #expect(upcomingGiveaways[id: "s3"] == nil)
  }

  @Test func reconcileClearsUpcomingOnAuthLoss() async {
    @Shared(.auth) var auth = Auth()
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = .mock
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      UpcomingGiveawayInfo(
        event: GiveawayEvent(
          id: "e1", stationId: "s1", prizeName: "P", winningNumber: 9, status: .scheduled))
    ]
    await GiveawayCoordinator().reconcile()
    #expect(activeGiveaway == nil)
    #expect(upcomingGiveaways.isEmpty)
  }

  @Test func revealReDerivesNextScheduledWhenStationHasTwoUpcoming() async {
    // A station with two scheduled airings: when the soonest opens, the badge must immediately show
    // the next-soonest (re-derived from the last feed) instead of vanishing until the next poll.
    await withMainSerialExecutor {
      let base = Date(timeIntervalSince1970: 1000)
      @Shared(.auth) var auth = Auth(jwt: "jwt")
      @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
      @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
      @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> =
        []
      let coordinator = GiveawayCoordinator()
      await withDependencies {
        $0.continuousClock = TestClock()
        $0.api.giveawayEventsFeed = { _ in
          [
            GiveawayEvent(
              id: "e1", stationId: "s1", prizeName: "P", winningNumber: 9, status: .scheduled,
              opensAt: base.addingTimeInterval(10)),
            GiveawayEvent(
              id: "e2", stationId: "s1", prizeName: "P", winningNumber: 9, status: .scheduled,
              opensAt: base.addingTimeInterval(500)),
          ]
        }
        $0.api.giveawayEvent = { _, id in
          GiveawayEvent(
            id: id, stationId: "s1", prizeName: "P", winningNumber: 9, status: .scheduled,
            opensAt: base.addingTimeInterval(10), serverTime: base)
        }
      } operation: {
        await coordinator.reconcile()
        // e1 is the soonest, so it's the published "coming up" entry; lastFeed holds both.
        #expect(upcomingGiveaways[id: "s1"]?.event.id == "e1")
        coordinator.revealFromHeldEvent(
          GiveawayEvent(
            id: "e1", stationId: "s1", prizeName: "P", winningNumber: 9, status: .scheduled),
          expectedStationId: "s1")
      }
      #expect(activeGiveaway?.id == "e1")
      #expect(upcomingGiveaways[id: "s1"]?.event.id == "e2")
    }
  }

  @Test func revealFromHeldEventRemovesUpcomingEntryForThatStation() async {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      UpcomingGiveawayInfo(
        event: GiveawayEvent(
          id: "e1", stationId: "s1", prizeName: "P", winningNumber: 9, status: .scheduled)),
      UpcomingGiveawayInfo(
        event: GiveawayEvent(
          id: "e2", stationId: "s2", prizeName: "P", winningNumber: 9, status: .scheduled)),
    ]
    let held = GiveawayEvent(
      id: "e1", stationId: "s1", prizeName: "P", winningNumber: 9, status: .scheduled)

    GiveawayCoordinator().revealFromHeldEvent(held, expectedStationId: "s1")

    #expect(activeGiveaway?.id == "e1")
    #expect(upcomingGiveaways[id: "s1"] == nil)
    #expect(upcomingGiveaways[id: "s2"]?.event.id == "e2")
  }

  @Test func stopKeepsUpcoming() {
    // Backgrounding (stop) must NOT clear the badges — they survive to the next foreground so the
    // list/Home don't flicker; `reconcile()` refreshes them then.
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      UpcomingGiveawayInfo(
        event: GiveawayEvent(
          id: "e1", stationId: "s1", prizeName: "P", winningNumber: 9, status: .scheduled))
    ]
    GiveawayCoordinator().stop()
    #expect(upcomingGiveaways[id: "s1"]?.event.id == "e1")
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

  private func lostParticipation(id: String = "e1") -> GiveawayParticipation {
    GiveawayParticipation(
      id: id, stationId: "s1", prizeName: "Two tickets", winningNumber: 9, tapNumber: 5,
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

  // MARK: - Overlapping feed fetches

}

extension GiveawayCoordinatorTests {

  @Test func reconcileAppliesOlderFeedWhenNewerFeedFails() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = []
    let (olderFeedStarted, olderFeedStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseOlderFeed, releaseOlderFeedContinuation) = AsyncStream.makeStream(of: Void.self)
    let feedCount = LockIsolated(0)
    let upcomingEvent = GiveawayEvent(
      id: "e1", stationId: "s2", prizeName: "P", winningNumber: 9, status: .scheduled,
      opensAt: Date(timeIntervalSince1970: 2000))
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        let isOlderFeed = feedCount.withValue {
          $0 += 1
          return $0 == 1
        }
        if !isOlderFeed { throw BoomError() }
        olderFeedStartedContinuation.yield(())
        var releaseOlderFeedIterator = releaseOlderFeed.makeAsyncIterator()
        _ = await releaseOlderFeedIterator.next()
        return [upcomingEvent]
      }
    } operation: {
      GiveawayCoordinator()
    }

    let olderReconcile = Task { await coordinator.reconcile() }
    var olderFeedStartedIterator = olderFeedStarted.makeAsyncIterator()
    _ = await olderFeedStartedIterator.next()
    await coordinator.reconcile()
    releaseOlderFeedContinuation.yield(())
    releaseOlderFeedContinuation.finish()
    await olderReconcile.value

    expectNoDifference(upcomingGiveaways.map(\.event.id), ["e1"])
  }

  @Test func reconcileOlderFeedFinishingLastDoesNotRestoreExpiredUpcomingBadge() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = []
    let (feedStarted, feedStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseOlderFeed, releaseOlderFeedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseNewerFeed, releaseNewerFeedContinuation) = AsyncStream.makeStream(of: Void.self)
    let feedCount = LockIsolated(0)
    let expiredEvent = GiveawayEvent(
      id: "e1", stationId: "s2", prizeName: "P", winningNumber: 9, status: .scheduled,
      opensAt: Date(timeIntervalSince1970: 2000))
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        let isOlderFeed = feedCount.withValue {
          $0 += 1
          return $0 == 1
        }
        feedStartedContinuation.yield(())
        var releaseIterator =
          (isOlderFeed ? releaseOlderFeed : releaseNewerFeed).makeAsyncIterator()
        _ = await releaseIterator.next()
        return isOlderFeed ? [expiredEvent] : []
      }
    } operation: {
      GiveawayCoordinator()
    }

    let olderReconcile = Task { await coordinator.reconcile() }
    var feedStartedIterator = feedStarted.makeAsyncIterator()
    _ = await feedStartedIterator.next()
    let newerReconcile = Task { await coordinator.reconcile() }
    _ = await feedStartedIterator.next()
    releaseNewerFeedContinuation.yield(())
    releaseNewerFeedContinuation.finish()
    await newerReconcile.value
    releaseOlderFeedContinuation.yield(())
    releaseOlderFeedContinuation.finish()
    await olderReconcile.value

    expectNoDifference(upcomingGiveaways, [])
  }

  // MARK: - Account switch mid-fetch

  @Test func reconcileDiscardsFeedWhenSignedOutDuringFetch() async {
    @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = []
    let (feedStarted, feedStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseFeed, releaseFeedContinuation) = AsyncStream.makeStream(of: Void.self)
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        feedStartedContinuation.yield(())
        var releaseFeedIterator = releaseFeed.makeAsyncIterator()
        _ = await releaseFeedIterator.next()
        return [
          GiveawayEvent(
            id: "e1", stationId: "s2", prizeName: "P", winningNumber: 9, status: .scheduled)
        ]
      }
    } operation: {
      GiveawayCoordinator()
    }

    let reconcile = Task { await coordinator.reconcile() }
    var feedStartedIterator = feedStarted.makeAsyncIterator()
    _ = await feedStartedIterator.next()
    $auth.withLock { $0 = Auth() }
    releaseFeedContinuation.yield(())
    releaseFeedContinuation.finish()
    await reconcile.value

    expectNoDifference(upcomingGiveaways, [])
  }

  @Test func reconcileDiscardsFeedWhenAccountSwitchesDuringFetch() async {
    @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = []
    let (feedStarted, feedStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseFeed, releaseFeedContinuation) = AsyncStream.makeStream(of: Void.self)
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        feedStartedContinuation.yield(())
        var releaseFeedIterator = releaseFeed.makeAsyncIterator()
        _ = await releaseFeedIterator.next()
        return [
          GiveawayEvent(
            id: "e1", stationId: "s2", prizeName: "P", winningNumber: 9, status: .scheduled)
        ]
      }
    } operation: {
      GiveawayCoordinator()
    }

    let reconcile = Task { await coordinator.reconcile() }
    var feedStartedIterator = feedStarted.makeAsyncIterator()
    _ = await feedStartedIterator.next()
    $auth.withLock { $0 = Auth(jwt: "account-b-jwt") }
    releaseFeedContinuation.yield(())
    releaseFeedContinuation.finish()
    await reconcile.value

    expectNoDifference(upcomingGiveaways, [])
  }

  @Test func revealDiscardsEventWhenAccountSwitchesDuringFetch() async {
    @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    let (eventFetchStarted, eventFetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseEventFetch, releaseEventFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let event = openEvent()
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in [event] }
      $0.api.giveawayEvent = { _, _ in
        eventFetchStartedContinuation.yield(())
        var releaseEventFetchIterator = releaseEventFetch.makeAsyncIterator()
        _ = await releaseEventFetchIterator.next()
        return event
      }
    } operation: {
      GiveawayCoordinator()
    }

    let reconcile = Task { await coordinator.reconcile() }
    var eventFetchStartedIterator = eventFetchStarted.makeAsyncIterator()
    _ = await eventFetchStartedIterator.next()
    $auth.withLock { $0 = Auth(jwt: "account-b-jwt") }
    releaseEventFetchContinuation.yield(())
    releaseEventFetchContinuation.finish()
    await reconcile.value

    expectNoDifference(activeGiveaway, nil)
  }

  @Test func armDiscardsEventWhenAccountSwitchesDuringFetch() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
      @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
      @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
      let (eventFetchStarted, eventFetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
      let (releaseEventFetch, releaseEventFetchContinuation) = AsyncStream.makeStream(of: Void.self)
      let event = openEvent()
      let coordinator = withDependencies {
        $0.continuousClock = TestClock()
        $0.api.giveawayEventsFeed = { _ in
          [
            GiveawayEvent(
              id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9,
              status: .scheduled, opensAt: Date(timeIntervalSince1970: 2000))
          ]
        }
        $0.api.giveawayEvent = { _, _ in
          eventFetchStartedContinuation.yield(())
          var releaseEventFetchIterator = releaseEventFetch.makeAsyncIterator()
          _ = await releaseEventFetchIterator.next()
          return event
        }
      } operation: {
        GiveawayCoordinator()
      }

      await coordinator.reconcile()
      var eventFetchStartedIterator = eventFetchStarted.makeAsyncIterator()
      _ = await eventFetchStartedIterator.next()
      $auth.withLock { $0 = Auth(jwt: "account-b-jwt") }
      releaseEventFetchContinuation.yield(())
      releaseEventFetchContinuation.finish()
      await Task.megaYield()

      expectNoDifference(activeGiveaway, nil)
    }
  }

  @Test func armDiscardsRevealWhenAccountSwitchesDuringWait() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
      @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
      @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
      let clock = TestClock()
      let coordinator = withDependencies {
        $0.continuousClock = clock
        $0.api.giveawayEventsFeed = { _ in
          [
            GiveawayEvent(
              id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9,
              status: .scheduled, opensAt: Date(timeIntervalSince1970: 1060))
          ]
        }
        $0.api.giveawayEvent = { _, id in
          GiveawayEvent(
            id: id, stationId: "s1", prizeName: "Two tickets", winningNumber: 9,
            status: .scheduled, opensAt: Date(timeIntervalSince1970: 1060),
            serverTime: Date(timeIntervalSince1970: 1000))
        }
      } operation: {
        GiveawayCoordinator()
      }

      await coordinator.reconcile()
      await Task.megaYield()
      $auth.withLock { $0 = Auth(jwt: "account-b-jwt") }
      await clock.advance(by: .seconds(60))
      await Task.megaYield()

      expectNoDifference(activeGiveaway, nil)
    }
  }

  @Test func clearActiveDiscardsResultWhenAccountSwitchesDuringFetch() async {
    @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = openEvent()
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
      "e1": lostParticipation()
    ]
    let (eventFetchStarted, eventFetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseEventFetch, releaseEventFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let coordinator = withDependencies {
      $0.api.giveawayEvent = { _, id in
        eventFetchStartedContinuation.yield(())
        var releaseEventFetchIterator = releaseEventFetch.makeAsyncIterator()
        _ = await releaseEventFetchIterator.next()
        return GiveawayEvent(
          id: id, stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .closed)
      }
      $0.api.giveawayEventMyResult = { _, _ in
        GiveawayMyResult(tapNumber: 5, isWinner: true, status: .closed, winningNumber: 9)
      }
    } operation: {
      GiveawayCoordinator()
    }

    let clearActive = Task {
      await coordinator.clearActiveIfNoLongerOpen(
        jwt: "account-a-jwt", event: openEvent(), stationId: "s1")
    }
    var eventFetchStartedIterator = eventFetchStarted.makeAsyncIterator()
    _ = await eventFetchStartedIterator.next()
    $auth.withLock { $0 = Auth(jwt: "account-b-jwt") }
    releaseEventFetchContinuation.yield(())
    releaseEventFetchContinuation.finish()
    await clearActive.value

    expectNoDifference(activeGiveaway?.id, "e1")
    expectNoDifference(participations["e1"], lostParticipation())
  }

  @Test func backstopDiscardsResultWhenAccountSwitchesDuringFetch() async {
    @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
      "e1": lostParticipation()
    ]
    let (resultFetchStarted, resultFetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseResultFetch, releaseResultFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let coordinator = withDependencies {
      $0.api.giveawayEventMyResult = { _, _ in
        resultFetchStartedContinuation.yield(())
        var releaseResultFetchIterator = releaseResultFetch.makeAsyncIterator()
        _ = await releaseResultFetchIterator.next()
        return GiveawayMyResult(tapNumber: 5, isWinner: true, status: .closed, winningNumber: 9)
      }
    } operation: {
      GiveawayCoordinator()
    }

    let backstop = Task {
      await coordinator.reconcileResolvedLoss(jwt: "account-a-jwt", eventId: "e1")
    }
    var resultFetchStartedIterator = resultFetchStarted.makeAsyncIterator()
    _ = await resultFetchStartedIterator.next()
    $auth.withLock { $0 = Auth(jwt: "account-b-jwt") }
    releaseResultFetchContinuation.yield(())
    releaseResultFetchContinuation.finish()
    await backstop.value

    expectNoDifference(participations["e1"], lostParticipation())
  }

  @Test func tapDiscardsResponseWhenAccountSwitchesDuringRequest() async {
    @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
    let (tapStarted, tapStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseTap, releaseTapContinuation) = AsyncStream.makeStream(of: Void.self)
    let coordinator = withDependencies {
      $0.api.tapGiveawayEvent = { _, _ in
        tapStartedContinuation.yield(())
        var releaseTapIterator = releaseTap.makeAsyncIterator()
        _ = await releaseTapIterator.next()
        return GiveawayTapResponse(tapNumber: 7, isWinner: true, status: .open)
      }
    } operation: {
      GiveawayCoordinator()
    }

    let tap = Task { try? await coordinator.tap(event: openEvent()) }
    var tapStartedIterator = tapStarted.makeAsyncIterator()
    _ = await tapStartedIterator.next()
    $auth.withLock { $0 = Auth(jwt: "account-b-jwt") }
    releaseTapContinuation.yield(())
    releaseTapContinuation.finish()
    await tap.value

    expectNoDifference(participations["e1"], nil)
  }

  @Test func tapPersistsResponseWhenSameAccountRefreshesTokenDuringRequest() async {
    let user = LoggedInUser(id: "account-a", firstName: "A", email: "a@example.com")
    @Shared(.auth) var auth = Auth(currentUser: user, jwt: "token-before")
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
    let (started, startedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (release, releaseContinuation) = AsyncStream.makeStream(of: Void.self)
    let coordinator = withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.tapGiveawayEvent = { _, _ in
        startedContinuation.yield(())
        var iterator = release.makeAsyncIterator()
        _ = await iterator.next()
        return GiveawayTapResponse(tapNumber: 7, isWinner: true, status: .open)
      }
    } operation: {
      GiveawayCoordinator()
    }

    let tap = Task { try? await coordinator.tap(event: openEvent()) }
    var startedIterator = started.makeAsyncIterator()
    _ = await startedIterator.next()
    $auth.withLock { $0 = Auth(currentUser: user, jwt: "token-after") }
    releaseContinuation.yield(())
    releaseContinuation.finish()
    await tap.value

    expectNoDifference(participations["e1"]?.tapNumber, 7)
    expectNoDifference(
      participations["e1"]?.status,
      GiveawayParticipationStatus.resolvedWon(submissionCompleted: false))
  }

  @Test func revealFromOlderFeedStillPublishesWhenNewerSameEventDetailFetchFails() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    let (olderDetailFetchStarted, olderDetailFetchStartedContinuation) = AsyncStream.makeStream(
      of: Void.self)
    let (releaseOlderDetailFetch, releaseOlderDetailFetchContinuation) = AsyncStream.makeStream(
      of: Void.self)
    let event = openEvent(id: "e1")
    let detailFetchCount = LockIsolated(0)
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in [event] }
      $0.api.giveawayEvent = { _, _ in
        let isOlderDetailFetch = detailFetchCount.withValue {
          $0 += 1
          return $0 == 1
        }
        if isOlderDetailFetch {
          olderDetailFetchStartedContinuation.yield(())
          var iterator = releaseOlderDetailFetch.makeAsyncIterator()
          _ = await iterator.next()
          return event
        }
        throw BoomError()
      }
    } operation: {
      GiveawayCoordinator()
    }

    let olderReconcile = Task { await coordinator.reconcile() }
    var olderDetailFetchStartedIterator = olderDetailFetchStarted.makeAsyncIterator()
    _ = await olderDetailFetchStartedIterator.next()
    await coordinator.reconcile()
    releaseOlderDetailFetchContinuation.yield(())
    releaseOlderDetailFetchContinuation.finish()
    await olderReconcile.value

    expectNoDifference(activeGiveaway?.id, "e1")
  }

  @Test func revealFromOlderFeedDoesNotReplaceNewerSameEventDetails() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    let (olderDetailFetchStarted, olderDetailFetchStartedContinuation) = AsyncStream.makeStream(
      of: Void.self)
    let (releaseOlderDetailFetch, releaseOlderDetailFetchContinuation) = AsyncStream.makeStream(
      of: Void.self)
    let feedEvent = openEvent(id: "e1")
    let detailFetchCount = LockIsolated(0)
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in [feedEvent] }
      $0.api.giveawayEvent = { _, id in
        let isOlderDetailFetch = detailFetchCount.withValue {
          $0 += 1
          return $0 == 1
        }
        if isOlderDetailFetch {
          olderDetailFetchStartedContinuation.yield(())
          var iterator = releaseOlderDetailFetch.makeAsyncIterator()
          _ = await iterator.next()
          return GiveawayEvent(
            id: id, stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .open)
        }
        return GiveawayEvent(
          id: id, stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .closed)
      }
    } operation: {
      GiveawayCoordinator()
    }

    let olderReconcile = Task { await coordinator.reconcile() }
    var olderDetailFetchStartedIterator = olderDetailFetchStarted.makeAsyncIterator()
    _ = await olderDetailFetchStartedIterator.next()
    await coordinator.reconcile()
    releaseOlderDetailFetchContinuation.yield(())
    releaseOlderDetailFetchContinuation.finish()
    await olderReconcile.value

    expectNoDifference(activeGiveaway?.status, .closed)
  }

  @Test func revealFromOlderFeedFinishingLastDoesNotReplaceNewerEvent() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    let (olderEventFetchStarted, olderEventFetchStartedContinuation) = AsyncStream.makeStream(
      of: Void.self)
    let (releaseOlderEventFetch, releaseOlderEventFetchContinuation) = AsyncStream.makeStream(
      of: Void.self)
    let olderEvent = openEvent(id: "e1")
    let newerEvent = openEvent(id: "e2")
    let feedCount = LockIsolated(0)
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        let isOlderFeed = feedCount.withValue {
          $0 += 1
          return $0 == 1
        }
        return [isOlderFeed ? olderEvent : newerEvent]
      }
      $0.api.giveawayEvent = { _, id in
        guard id == olderEvent.id else { return newerEvent }
        olderEventFetchStartedContinuation.yield(())
        var releaseOlderEventFetchIterator = releaseOlderEventFetch.makeAsyncIterator()
        _ = await releaseOlderEventFetchIterator.next()
        return olderEvent
      }
    } operation: {
      GiveawayCoordinator()
    }

    let olderReconcile = Task { await coordinator.reconcile() }
    var olderEventFetchStartedIterator = olderEventFetchStarted.makeAsyncIterator()
    _ = await olderEventFetchStartedIterator.next()
    await coordinator.reconcile()
    releaseOlderEventFetchContinuation.yield(())
    releaseOlderEventFetchContinuation.finish()
    await olderReconcile.value

    expectNoDifference(activeGiveaway?.id, "e2")
  }

  @Test func revealFromOlderFeedStillPublishesWhenNewerFeedFails() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    let (eventFetchStarted, eventFetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseEventFetch, releaseEventFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let event = openEvent(id: "e1")
    let feedCount = LockIsolated(0)
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        let isOlderFeed = feedCount.withValue {
          $0 += 1
          return $0 == 1
        }
        guard isOlderFeed else { throw URLError(.notConnectedToInternet) }
        return [event]
      }
      $0.api.giveawayEvent = { _, _ in
        eventFetchStartedContinuation.yield(())
        var releaseEventFetchIterator = releaseEventFetch.makeAsyncIterator()
        _ = await releaseEventFetchIterator.next()
        return event
      }
    } operation: {
      GiveawayCoordinator()
    }

    let olderReconcile = Task { await coordinator.reconcile() }
    var eventFetchStartedIterator = eventFetchStarted.makeAsyncIterator()
    _ = await eventFetchStartedIterator.next()
    await coordinator.reconcile()
    releaseEventFetchContinuation.yield(())
    releaseEventFetchContinuation.finish()
    await olderReconcile.value

    expectNoDifference(activeGiveaway?.id, "e1")
  }

  @Test func revealFromOlderFeedStillPublishesWhenNewerFeedIsEmpty() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    let (eventFetchStarted, eventFetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseEventFetch, releaseEventFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let event = openEvent(id: "e1")
    let feedCount = LockIsolated(0)
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        let isOlderFeed = feedCount.withValue {
          $0 += 1
          return $0 == 1
        }
        return isOlderFeed ? [event] : []
      }
      $0.api.giveawayEvent = { _, _ in
        eventFetchStartedContinuation.yield(())
        var releaseEventFetchIterator = releaseEventFetch.makeAsyncIterator()
        _ = await releaseEventFetchIterator.next()
        return event
      }
    } operation: {
      GiveawayCoordinator()
    }

    let olderReconcile = Task { await coordinator.reconcile() }
    var eventFetchStartedIterator = eventFetchStarted.makeAsyncIterator()
    _ = await eventFetchStartedIterator.next()
    await coordinator.reconcile()
    releaseEventFetchContinuation.yield(())
    releaseEventFetchContinuation.finish()
    await olderReconcile.value

    expectNoDifference(activeGiveaway?.id, "e1")
  }

  @Test func closeCheckFromOlderFeedFinishingLastDoesNotClearNewerEvent() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = openEvent(id: "e1")
    let (closeCheckStarted, closeCheckStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseCloseCheck, releaseCloseCheckContinuation) = AsyncStream.makeStream(of: Void.self)
    let newerEvent = openEvent(id: "e2")
    let feedCount = LockIsolated(0)
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        let isOlderFeed = feedCount.withValue {
          $0 += 1
          return $0 == 1
        }
        return isOlderFeed ? [] : [newerEvent]
      }
      $0.api.giveawayEvent = { _, id in
        guard id == "e1" else { return newerEvent }
        closeCheckStartedContinuation.yield(())
        var releaseCloseCheckIterator = releaseCloseCheck.makeAsyncIterator()
        _ = await releaseCloseCheckIterator.next()
        return GiveawayEvent(
          id: id, stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .closed)
      }
    } operation: {
      GiveawayCoordinator()
    }

    let olderReconcile = Task { await coordinator.reconcile() }
    var closeCheckStartedIterator = closeCheckStarted.makeAsyncIterator()
    _ = await closeCheckStartedIterator.next()
    await coordinator.reconcile()
    releaseCloseCheckContinuation.yield(())
    releaseCloseCheckContinuation.finish()
    await olderReconcile.value

    expectNoDifference(activeGiveaway?.id, "e2")
  }

  @Test func closeCheckStillPromotesWinnerWhenNewerFeedSelectsAnotherEvent() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = openEvent(id: "e1")
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
      "e1": lostParticipation()
    ]
    let (closeCheckStarted, closeCheckStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseCloseCheck, releaseCloseCheckContinuation) = AsyncStream.makeStream(of: Void.self)
    let newerEvent = openEvent(id: "e2")
    let feedCount = LockIsolated(0)
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        let isOlderFeed = feedCount.withValue {
          $0 += 1
          return $0 == 1
        }
        return isOlderFeed ? [] : [newerEvent]
      }
      $0.api.giveawayEvent = { _, id in
        guard id == "e1" else { return newerEvent }
        closeCheckStartedContinuation.yield(())
        var releaseCloseCheckIterator = releaseCloseCheck.makeAsyncIterator()
        _ = await releaseCloseCheckIterator.next()
        return GiveawayEvent(
          id: id, stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .closed)
      }
      $0.api.giveawayEventMyResult = { _, _ in
        GiveawayMyResult(tapNumber: 5, isWinner: true, status: .closed, winningNumber: 9)
      }
    } operation: {
      GiveawayCoordinator()
    }

    let olderReconcile = Task { await coordinator.reconcile() }
    var closeCheckStartedIterator = closeCheckStarted.makeAsyncIterator()
    _ = await closeCheckStartedIterator.next()
    await coordinator.reconcile()
    releaseCloseCheckContinuation.yield(())
    releaseCloseCheckContinuation.finish()
    await olderReconcile.value

    expectNoDifference(
      participations["e1"]?.status,
      GiveawayParticipationStatus.resolvedWon(submissionCompleted: false))
    expectNoDifference(activeGiveaway?.id, "e2")
  }

  @Test func closeCheckCancelsAnOlderArmForTheSameEvent() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = openEvent(id: "e1")
    let (armStarted, armStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseArm, releaseArmContinuation) = AsyncStream.makeStream(of: Void.self)
    let event = openEvent(id: "e1")
    let feedCount = LockIsolated(0)
    let coordinator = withDependencies {
      $0.api.giveawayEventsFeed = { _ in
        let isOlderFeed = feedCount.withValue {
          $0 += 1
          return $0 == 1
        }
        return isOlderFeed
          ? [
            GiveawayEvent(
              id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9,
              status: .scheduled)
          ]
          : []
      }
      $0.api.giveawayEvent = { _, _ in
        let isArm = feedCount.value == 1
        if isArm {
          armStartedContinuation.yield(())
          var releaseArmIterator = releaseArm.makeAsyncIterator()
          _ = await releaseArmIterator.next()
          return event
        }
        return GiveawayEvent(
          id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .closed)
      }
    } operation: {
      GiveawayCoordinator()
    }

    await coordinator.reconcile()
    var armStartedIterator = armStarted.makeAsyncIterator()
    _ = await armStartedIterator.next()
    await coordinator.reconcile()
    releaseArmContinuation.yield(())
    releaseArmContinuation.finish()
    await Task.megaYield()

    expectNoDifference(activeGiveaway, nil)
  }

  @Test func armRearmsForNewAccountWhileOldArmIsWaiting() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
      @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
      @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
      let clock = TestClock()
      let coordinator = withDependencies {
        $0.continuousClock = clock
        $0.api.giveawayEventsFeed = { _ in
          [
            GiveawayEvent(
              id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9,
              status: .scheduled, opensAt: Date(timeIntervalSince1970: 1060))
          ]
        }
        $0.api.giveawayEvent = { _, id in
          GiveawayEvent(
            id: id, stationId: "s1", prizeName: "Two tickets", winningNumber: 9,
            status: .scheduled, opensAt: Date(timeIntervalSince1970: 1060),
            serverTime: Date(timeIntervalSince1970: 1000))
        }
      } operation: {
        GiveawayCoordinator()
      }

      await coordinator.reconcile()
      await Task.megaYield()
      $auth.withLock { $0 = Auth(jwt: "account-b-jwt") }
      await coordinator.reconcile()
      await Task.megaYield()
      await clock.advance(by: .seconds(60))
      await Task.megaYield()

      expectNoDifference(activeGiveaway?.id, "e1")
    }
  }

  @Test func recentLossesStopCheckingWhenAccountSwitchesBetweenChecks() async {
    @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
      "e1": lostParticipation(id: "e1"), "e2": lostParticipation(id: "e2"),
    ]
    let (resultFetchStarted, resultFetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseResultFetch, releaseResultFetchContinuation) = AsyncStream.makeStream(of: Void.self)
    let resultFetchCount = LockIsolated(0)
    let coordinator = withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 200)
      $0.api.giveawayEventMyResult = { _, _ in
        let isFirstFetch = resultFetchCount.withValue {
          $0 += 1
          return $0 == 1
        }
        if isFirstFetch {
          resultFetchStartedContinuation.yield(())
          var releaseResultFetchIterator = releaseResultFetch.makeAsyncIterator()
          _ = await releaseResultFetchIterator.next()
        }
        return GiveawayMyResult(tapNumber: 5, isWinner: true, status: .closed, winningNumber: 9)
      }
    } operation: {
      GiveawayCoordinator()
    }

    let reconcileLosses = Task { await coordinator.reconcileRecentResolvedLosses() }
    var resultFetchStartedIterator = resultFetchStarted.makeAsyncIterator()
    _ = await resultFetchStartedIterator.next()
    $auth.withLock { $0 = Auth(jwt: "account-b-jwt") }
    releaseResultFetchContinuation.yield(())
    releaseResultFetchContinuation.finish()
    await reconcileLosses.value

    expectNoDifference(
      participations, ["e1": lostParticipation(id: "e1"), "e2": lostParticipation(id: "e2")])
  }
}

// swiftlint:enable redundant_optional_initialization
