import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@MainActor
struct GiveawayOverlayModelTests {
  private func openGiveaway(station: String = "s1") -> Giveaway {
    Giveaway(
      id: "g1", stationId: station, prizeName: "Two tickets", winningNumber: 9, status: .open)
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
    #expect(model.prizeName == "Two tickets")
    #expect(model.promptText == "Be the 9th listener to tap the button below to win:")
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

  @Test func ordinalStringHandlesTeensAndOnes() {
    #expect(1.ordinalString == "1st")
    #expect(2.ordinalString == "2nd")
    #expect(3.ordinalString == "3rd")
    #expect(9.ordinalString == "9th")
    #expect(11.ordinalString == "11th")
    #expect(12.ordinalString == "12th")
    #expect(21.ordinalString == "21st")
  }
}

// swiftlint:enable redundant_optional_initialization
