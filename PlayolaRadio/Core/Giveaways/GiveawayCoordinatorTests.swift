import Dependencies
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

  @Test func pollPublishesOpenGiveawayForCurrentPlayolaStation() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = nil
    await withDependencies {
      $0.api.activeGiveaway = { _, stationId in
        Giveaway(
          id: "g1", stationId: stationId, prizeName: "Two tickets", winningNumber: 9,
          status: .open)
      }
    } operation: {
      await GiveawayCoordinator().pollActiveGiveaway()
    }
    #expect(activeGiveaway?.id == "g1")
    #expect(activeGiveaway?.stationId == "s1")
  }

  @Test func pollClearsWhenServerReturnsNil() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying()
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = .mock
    await withDependencies {
      $0.api.activeGiveaway = { _, _ in nil }
    } operation: {
      await GiveawayCoordinator().pollActiveGiveaway()
    }
    #expect(activeGiveaway == nil)
  }

  @Test func pollClearsWhenNotOnAPlayolaStation() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = .mock
    await GiveawayCoordinator().pollActiveGiveaway()
    #expect(activeGiveaway == nil)
  }

  @Test func pollKeepsLastValueWhenServerErrors() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying()
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = .mock
    await withDependencies {
      $0.api.activeGiveaway = { _, _ in throw BoomError() }
    } operation: {
      await GiveawayCoordinator().pollActiveGiveaway()
    }
    #expect(activeGiveaway != nil)
  }

  @Test func pollNoOpsWhenSignedOut() async {
    @Shared(.auth) var auth = Auth()
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying()
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = .mock
    await GiveawayCoordinator().pollActiveGiveaway()
    #expect(activeGiveaway != nil)
  }
}

// swiftlint:enable redundant_optional_initialization
