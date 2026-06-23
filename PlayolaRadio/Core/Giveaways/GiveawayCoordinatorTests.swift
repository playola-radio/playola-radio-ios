import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@MainActor
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
    // event that's already published — otherwise the reveal vanishes the instant it opens.
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = GiveawayEvent(
      id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .open)
    await withDependencies {
      $0.api.giveawayEventsFeed = { _ in [] }
    } operation: {
      await GiveawayCoordinator().reconcile()
    }
    #expect(activeGiveaway?.id == "e1")
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
}

// swiftlint:enable redundant_optional_initialization
