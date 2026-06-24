import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@MainActor
struct GiveawayOverlayModelTests {
  // giveawayId is deliberately distinct from the event id so tests pin participation keying to the
  // per-airing event id (`id`), not the stable `giveawayId`.
  private func openGiveaway(station: String = "s1", winningNumber: Int = 9) -> GiveawayEvent {
    GiveawayEvent(
      id: "g1", stationId: station, prizeName: "Two tickets", winningNumber: winningNumber,
      status: .open, giveawayId: "gv1")
  }

  private func playolaNowPlaying(id: String = "s1") -> NowPlaying {
    NowPlaying.mockWith(station: AnyStation.mockPlayola(id: id))
  }

  @Test func hiddenWhenNoActiveGiveaway() {
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    let model = GiveawayOverlayModel()
    #expect(model.isVisible == false)
    #expect(model.overlayOpacity == 0)
    #expect(model.gateDiagnostics == "hidden: no activeGiveaway")
  }

  @Test func hiddenWhenStatusNotOpen() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = GiveawayEvent(
      id: "g1", stationId: "s1", prizeName: "x", winningNumber: 9, status: .closed)
    let model = GiveawayOverlayModel()
    #expect(model.isVisible == false)
    #expect(model.gateDiagnostics == "hidden: status is closed, not open")
  }

  @Test func hiddenWhenStationMismatch() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = openGiveaway(station: "s1")
    let model = GiveawayOverlayModel()
    #expect(model.isVisible == false)
    #expect(model.gateDiagnostics == "hidden: giveaway station s1 ≠ playing nil")
  }

  @Test func visibleWhenOpenOnCurrentStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = openGiveaway()
    let model = GiveawayOverlayModel()
    #expect(model.isVisible == true)
    #expect(model.overlayOpacity == 1)
    #expect(model.prizeText == "Two tickets.")
    #expect(model.promptOrdinal == "9th")
    #expect(model.promptSuffix == " Listener to Tap the Button Below to win:")
    #expect(model.gateDiagnostics == "visible: open giveaway on the current station")
  }

  @Test func resolvedLossShowsLoserRevealAndHidesPrompt() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = openGiveaway()
    // Keyed by the event id ("g1"), which differs from the event's giveawayId ("gv1") — so this
    // fails if the overlay ever re-keys by giveawayId.
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
      "g1": GiveawayParticipation(
        id: "g1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9,
        tapNumber: 7, status: .resolvedLost(toastShown: false), tappedAt: Date())
    ]
    let model = GiveawayOverlayModel()
    #expect(model.showsLoserReveal == true)
    #expect(model.showsPrompt == false)
    #expect(model.promptOpacity == 0)
    #expect(model.loserRevealOpacity == 1)
    #expect(model.loserRevealInteractive == true)
    #expect(model.loserRevealHeadline == "You were listener #7 — good luck next time!")
  }

  @Test func resolvedWinCollapsesTheOverlay() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = openGiveaway()
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
      "g1": GiveawayParticipation(
        id: "g1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9,
        tapNumber: 9, status: .resolvedWon(submissionCompleted: false), tappedAt: Date())
    ]
    let model = GiveawayOverlayModel()
    #expect(model.showsLoserReveal == false)
    #expect(model.showsPrompt == false)
    #expect(model.isVisible == false)
  }

  @Test func loserRevealAppearedMarksToastShown() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = openGiveaway()
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
      "g1": GiveawayParticipation(
        id: "g1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9,
        tapNumber: 7, status: .resolvedLost(toastShown: false), tappedAt: Date())
    ]
    let model = GiveawayOverlayModel()
    model.loserRevealAppeared()
    #expect(
      participations["g1"]?.status == GiveawayParticipationStatus.resolvedLost(toastShown: true))
  }

  @Test func tapButtonInvokesOnTapWithTheVisibleGiveaway() async {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = openGiveaway()
    let model = GiveawayOverlayModel()
    var tapped: GiveawayEvent?
    model.onTap = { tapped = $0 }
    await model.tapButtonTapped()
    #expect(tapped?.id == "g1")
  }

  @Test func tapButtonNoOpsWhenNotVisible() async {
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = nil
    let model = GiveawayOverlayModel()
    var called = false
    model.onTap = { _ in called = true }
    await model.tapButtonTapped()
    #expect(called == false)
  }

  @Test func tapButtonRoutesThrownErrorToOnError() async {
    struct Boom: Error {}
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = openGiveaway()
    let model = GiveawayOverlayModel()
    var capturedError: (any Error)?
    model.onTap = { _ in throw Boom() }
    model.onError = { capturedError = $0 }
    await model.tapButtonTapped()
    #expect(capturedError is Boom)
  }

  @Test func promptOrdinalHandlesTeensAndOnes() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = playolaNowPlaying(id: "s1")
    @Shared(.activeGiveaway) var activeGiveaway: GiveawayEvent? = openGiveaway()
    let model = GiveawayOverlayModel()
    let cases: [(Int, String)] = [
      (1, "1st"), (2, "2nd"), (3, "3rd"), (9, "9th"), (11, "11th"), (12, "12th"), (21, "21st"),
    ]
    for (number, expected) in cases {
      $activeGiveaway.withLock { $0 = openGiveaway(winningNumber: number) }
      #expect(model.promptOrdinal == expected)
    }
  }
}

// swiftlint:enable redundant_optional_initialization
