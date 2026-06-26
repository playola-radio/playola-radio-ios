import Foundation
import IdentifiedCollections
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@MainActor
struct UpcomingGiveawayBannerModelTests {
  private func playolaNowPlaying(id: String = "s1") -> NowPlaying {
    NowPlaying.mockWith(station: AnyStation.mockPlayola(id: id))
  }

  private func scheduled(id: String, station: String, prize: String = "Two tickets")
    -> UpcomingGiveawayInfo
  {
    UpcomingGiveawayInfo(
      stationId: station,
      event: GiveawayEvent(
        id: id, stationId: station, prizeName: prize, winningNumber: 9, status: .scheduled))
  }

  @Test func hiddenWhenNotPlayingAStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1")
    ]
    let model = UpcomingGiveawayBannerModel()
    #expect(model.isVisible == false)
    #expect(model.bannerOpacity == 0)
    #expect(model.bannerText == "")
  }

  @Test func hiddenWhenNoUpcomingForCurrentStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e2", station: "other")
    ]
    let model = UpcomingGiveawayBannerModel()
    #expect(model.isVisible == false)
  }

  @Test func visibleWithBannerTextWhenUpcomingForCurrentStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1", prize: "Two tickets")
    ]
    let model = UpcomingGiveawayBannerModel()
    #expect(model.isVisible == true)
    #expect(model.bannerOpacity == 1)
    #expect(model.bannerText == "Win a Two tickets — coming up on Mock Radio Show")
  }

  @Test func hiddenOnceContestOpensForCurrentStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = GiveawayEvent(
      id: "e1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9, status: .open)
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1")
    ]
    let model = UpcomingGiveawayBannerModel()
    #expect(model.isVisible == false)
  }

  @Test func staysVisibleWhenOpenContestIsForADifferentStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = GiveawayEvent(
      id: "eOther", stationId: "other", prizeName: "x", winningNumber: 9, status: .open)
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1")
    ]
    let model = UpcomingGiveawayBannerModel()
    #expect(model.isVisible == true)
  }
}

// swiftlint:enable redundant_optional_initialization
