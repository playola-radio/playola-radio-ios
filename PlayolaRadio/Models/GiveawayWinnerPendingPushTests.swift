import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct GiveawayWinnerPendingPushTests {
  @Test func parsesValidPendingPush() {
    let push = GiveawayWinnerPendingPush(userInfo: [
      "type": "giveaway_winner_pending", "eventId": "e1", "stationId": "s1",
      "giveawayId": "gw1", "winnerName": "Jo", "prizeName": "Two tickets",
      "congratsExpiresAt": "2026-06-25T20:00:00.000Z",
    ])
    expectNoDifference(push?.eventId, "e1")
    expectNoDifference(push?.stationId, "s1")
    expectNoDifference(push?.winnerName, "Jo")
    expectNoDifference(push?.prizeName, "Two tickets")
    #expect(push?.congratsExpiresAt != nil)
  }

  @Test func treatsEmptyWinnerAndPrizeNamesAsMissing() {
    // The server sends `winnerName: ""` when it can't resolve a name — an empty string must not be
    // treated as a real name or the UI renders a blank where the winner's name belongs.
    let push = GiveawayWinnerPendingPush(userInfo: [
      "type": "giveaway_winner_pending", "eventId": "e1", "stationId": "s1",
      "winnerName": "", "prizeName": "",
    ])
    expectNoDifference(push?.winnerName, nil)
    expectNoDifference(push?.prizeName, nil)
  }

  @Test func parsesExpiryWithoutFractionalSeconds() {
    let push = GiveawayWinnerPendingPush(userInfo: [
      "type": "giveaway_winner_pending", "eventId": "e1", "stationId": "s1",
      "congratsExpiresAt": "2026-06-25T20:00:00Z",
    ])
    #expect(push?.congratsExpiresAt != nil)
  }

  @Test func rejectsWrongTypeOrMissingIds() {
    #expect(
      GiveawayWinnerPendingPush(userInfo: ["type": "giveaway_closed", "eventId": "e1"]) == nil)
    #expect(
      GiveawayWinnerPendingPush(userInfo: ["type": "giveaway_winner_pending", "eventId": "e1"])
        == nil)  // missing stationId
    #expect(GiveawayWinnerPendingPush(userInfo: ["type": "giveaway_winner_pending"]) == nil)
  }
}
