import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@MainActor
struct UpcomingGiveawayBannerModelTests {
  private static let referenceNow = Date(timeIntervalSince1970: 1_800_000_000)

  private func playolaNowPlaying(id: String = "s1") -> NowPlaying {
    NowPlaying.mockWith(station: AnyStation.mockPlayola(id: id))
  }

  private func airing(id: String, endTime: Date?) -> Airing {
    Airing(
      id: id, episodeId: "ep", stationId: "s1",
      airtime: Self.referenceNow, createdAt: Self.referenceNow, updatedAt: Self.referenceNow,
      endTime: endTime)
  }

  private func playolaNowPlaying(stationId: String = "s1", airingId: String, endTime: Date?)
    -> NowPlaying
  {
    NowPlaying.mockWith(
      spin: Spin.mockWith(airing: airing(id: airingId, endTime: endTime)),
      station: AnyStation.mockPlayola(id: stationId))
  }

  private func scheduled(
    id: String, station: String, prize: String = "Two tickets", airingId: String? = nil
  ) -> UpcomingGiveawayInfo {
    UpcomingGiveawayInfo(
      event: GiveawayEvent(
        id: id, stationId: station, prizeName: prize, winningNumber: 9, status: .scheduled,
        airingId: airingId))
  }

  /// Builds the model and simulates the once-a-minute tick having fired at `referenceNow`.
  private func makeModel() -> UpcomingGiveawayBannerModel {
    let model = UpcomingGiveawayBannerModel()
    model.now = Self.referenceNow
    return model
  }

  @Test func hiddenWhenNotPlayingAStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1")
    ]
    let model = makeModel()
    #expect(model.isVisible == false)
    #expect(model.bannerOpacity == 0)
    #expect(model.bannerText == "")
  }

  @Test func hiddenWhenNoUpcomingForCurrentStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e2", station: "other")
    ]
    let model = makeModel()
    #expect(model.isVisible == false)
  }

  @Test func visibleWithBannerTextWhenUpcomingForCurrentStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1", prize: "Two tickets")
    ]
    let model = makeModel()
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
    let model = makeModel()
    #expect(model.isVisible == false)
  }

  @Test func staysVisibleWhenOpenContestIsForADifferentStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = GiveawayEvent(
      id: "eOther", stationId: "other", prizeName: "x", winningNumber: 9, status: .open)
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1")
    ]
    let model = makeModel()
    #expect(model.isVisible == true)
  }

  @Test func showsWindowPhraseWhenPrizeShowIsCurrentlyAiring() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(
      airingId: "a1", endTime: Self.referenceNow.addingTimeInterval(38 * 60))
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1", airingId: "a1")
    ]
    let model = makeModel()
    #expect(model.bannerText == "Two tickets giveaway in the next ~40 min")
  }

  @Test func roundsWindowToNearestFiveMinutes() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(
      airingId: "a1", endTime: Self.referenceNow.addingTimeInterval(43 * 60))
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1", airingId: "a1")
    ]
    let model = makeModel()
    #expect(model.bannerText == "Two tickets giveaway in the next ~45 min")
  }

  @Test func showsFewMinutesPhraseNearShowEnd() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(
      airingId: "a1", endTime: Self.referenceNow.addingTimeInterval(90))
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1", airingId: "a1")
    ]
    let model = makeModel()
    #expect(model.bannerText == "Two tickets giveaway in the next few minutes")
  }

  @Test func fallsBackToTimelessCopyWhenAiringDoesNotMatch() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(
      airingId: "other-airing", endTime: Self.referenceNow.addingTimeInterval(38 * 60))
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1", airingId: "a1")
    ]
    let model = makeModel()
    #expect(model.bannerText == "Win a Two tickets — coming up on Mock Radio Show")
  }

  @Test func fallsBackToTimelessCopyWhenEndTimeMissing() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(
      airingId: "a1", endTime: nil)
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1", airingId: "a1")
    ]
    let model = makeModel()
    #expect(model.bannerText == "Win a Two tickets — coming up on Mock Radio Show")
  }

  @Test func fallsBackToTimelessCopyWhenWindowAlreadyPassed() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(
      airingId: "a1", endTime: Self.referenceNow.addingTimeInterval(-60))
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      scheduled(id: "e1", station: "s1", airingId: "a1")
    ]
    let model = makeModel()
    #expect(model.bannerText == "Win a Two tickets — coming up on Mock Radio Show")
  }
}

// swiftlint:enable redundant_optional_initialization
