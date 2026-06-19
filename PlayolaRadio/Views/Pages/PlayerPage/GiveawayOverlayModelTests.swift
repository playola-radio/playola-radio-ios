import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@MainActor
struct GiveawayOverlayModelTests {
  private func openGiveaway(station: String = "s1", winningNumber: Int = 9) -> Giveaway {
    Giveaway(
      id: "g1", stationId: station, prizeName: "Two tickets", winningNumber: winningNumber,
      status: .open)
  }

  @Test func hiddenWhenNoActiveGiveaway() {
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = nil
    let model = GiveawayOverlayModel()
    #expect(model.isVisible == false)
    #expect(model.overlayOpacity == 0)
    #expect(model.gateDiagnostics == "hidden: no activeGiveaway")
  }

  @Test func hiddenWhenStatusNotOpen() {
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = Giveaway(
      id: "g1", stationId: "s1", prizeName: "x", winningNumber: 9, status: .closed)
    let model = GiveawayOverlayModel()
    model.debugForceVisible = true
    #expect(model.isVisible == false)
    #expect(model.gateDiagnostics == "hidden: status is closed, not open")
  }

  @Test func hiddenWhenStationMismatchWithoutDebugForce() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = openGiveaway(station: "s1")
    let model = GiveawayOverlayModel()
    #expect(model.isVisible == false)
    #expect(model.gateDiagnostics == "hidden: giveaway station s1 ≠ playing nil")
  }

  @Test func visibleWhenDebugForceVisibleAndOpen() {
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = openGiveaway()
    let model = GiveawayOverlayModel()
    model.debugForceVisible = true
    #expect(model.isVisible == true)
    #expect(model.overlayOpacity == 1)
    #expect(model.prizeText == "Two tickets.")
    #expect(model.promptOrdinal == "9th")
    #expect(model.promptSuffix == " Listener to Tap the Button Below to win:")
    #expect(model.gateDiagnostics == "visible: debug force-visible (station check bypassed)")
  }

  @Test func tappedFlipsPromptToStandby() {
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = openGiveaway()
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
      "g1": GiveawayParticipation(
        id: "g1", stationId: "s1", prizeName: "Two tickets", winningNumber: 9,
        tapNumber: 7, status: .tappedStandby, tappedAt: Date())
    ]
    let model = GiveawayOverlayModel()
    model.debugForceVisible = true
    #expect(model.hasTapped == true)
    #expect(model.promptOpacity == 0)
    #expect(model.standbyOpacity == 1)
    #expect(model.standbyInteractive == true)
  }

  @Test func tapButtonInvokesOnTapWithTheVisibleGiveaway() async {
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = openGiveaway()
    let model = GiveawayOverlayModel()
    model.debugForceVisible = true
    var tapped: Giveaway?
    model.onTap = { tapped = $0 }
    await model.tapButtonTapped()
    #expect(tapped?.id == "g1")
  }

  @Test func tapButtonNoOpsWhenNotVisible() async {
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = nil
    let model = GiveawayOverlayModel()
    var called = false
    model.onTap = { _ in called = true }
    await model.tapButtonTapped()
    #expect(called == false)
  }

  @Test func promptOrdinalHandlesTeensAndOnes() {
    @Shared(.activeGiveaway) var activeGiveaway: Giveaway? = openGiveaway()
    let model = GiveawayOverlayModel()
    model.debugForceVisible = true
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
