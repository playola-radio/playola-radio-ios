import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@MainActor
struct GiveawayParticipationTests {
  @Test func codableRoundTrips() throws {
    let participation = GiveawayParticipation(
      id: "g1", stationId: "s1", prizeName: "Tickets", winningNumber: 9,
      tapNumber: 5, status: .tappedStandby,
      tappedAt: Date(timeIntervalSince1970: 1_000_000))
    let data = try JSONEncoder().encode(participation)
    let back = try JSONDecoder().decode(GiveawayParticipation.self, from: data)
    expectNoDifference(back, participation)
  }

  @Test func terminalStatesAreHandledFlags() {
    var participation = GiveawayParticipation(
      id: "g1", stationId: "s1", prizeName: "Tickets", winningNumber: 9,
      tapNumber: 5, status: .tappedStandby, tappedAt: Date())
    #expect(!participation.isFullyHandled)

    participation.status = .resolvedLost(toastShown: false)
    #expect(!participation.isFullyHandled)
    participation.status = .resolvedLost(toastShown: true)
    #expect(participation.isFullyHandled)

    participation.status = .resolvedWon(submissionCompleted: false)
    #expect(!participation.isFullyHandled)
    participation.status = .resolvedWon(submissionCompleted: true)
    #expect(participation.isFullyHandled)

    participation.status = .canceled
    #expect(participation.isFullyHandled)
  }

  @Test func wasPromotedWinTrueWhenWonBelowWinningNumber() {
    var participation = GiveawayParticipation(
      id: "g1", stationId: "s1", prizeName: "Tickets", winningNumber: 9,
      tapNumber: 5, status: .resolvedWon(submissionCompleted: false), tappedAt: Date())
    #expect(participation.wasPromotedWin)

    participation.tapNumber = 9
    #expect(!participation.wasPromotedWin)
  }

  @Test func wasPromotedWinFalseWhenNotWon() {
    var participation = GiveawayParticipation(
      id: "g1", stationId: "s1", prizeName: "Tickets", winningNumber: 9,
      tapNumber: 5, status: .resolvedLost(toastShown: false), tappedAt: Date())
    #expect(!participation.wasPromotedWin)

    participation.status = .tappedStandby
    #expect(!participation.wasPromotedWin)
  }
}
