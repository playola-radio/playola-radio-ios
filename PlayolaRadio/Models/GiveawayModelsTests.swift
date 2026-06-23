import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@MainActor
struct GiveawayModelsTests {
  private func decoder() -> JSONDecoder { JSONDecoderWithIsoFull() }

  @Test func decodesGiveawayEventProjectionWithServerTimeAndViewer() throws {
    let json = Data(
      """
      {
        "id": "evt1", "stationId": "s1", "airingId": "air1", "giveawayId": "gv1",
        "status": "scheduled", "prizeName": "Two tickets", "prizeDescription": "Friday",
        "prizeImageUrl": "https://x.test/p.png", "winningNumber": 9,
        "opensAt": "2026-07-01T12:05:00.073Z", "serverTime": "2026-07-01T12:04:58.512Z",
        "viewer": { "hasTapped": false, "isWinner": false, "canSubmitMailingInfo": false,
                    "tapNumber": null }
      }
      """.utf8)
    let event = try decoder().decode(GiveawayEvent.self, from: json)
    #expect(event.id == "evt1")
    #expect(event.airingId == "air1")
    #expect(event.giveawayId == "gv1")
    #expect(event.status == .scheduled)
    #expect(event.opensAt != nil)
    #expect(event.serverTime != nil)
    #expect(event.viewer?.hasTapped == false)
  }

  @Test func decodesActiveGiveawayWithWinningNumberAndNoTapCount() throws {
    let json = Data(
      """
      {
        "id": "g1", "stationId": "s1", "prizeName": "Two tickets",
        "prizeDescription": "Friday night", "prizeImageUrl": "https://x.test/p.png",
        "winningNumber": 9, "status": "open", "winnerUserId": null,
        "openedAt": "2026-06-13T18:00:00.000Z", "closedAt": null,
        "createdAt": "2026-06-13T17:00:00.000Z", "updatedAt": "2026-06-13T18:00:00.000Z"
      }
      """.utf8)
    let giveaway = try decoder().decode(GiveawayEvent.self, from: json)
    #expect(giveaway.id == "g1")
    #expect(giveaway.stationId == "s1")
    #expect(giveaway.prizeName == "Two tickets")
    #expect(giveaway.winningNumber == 9)
    #expect(giveaway.status == .open)
    #expect(giveaway.prizeImageUrl == URL(string: "https://x.test/p.png"))
  }

  @Test func decodesUnknownGiveawayStatusAsUnknownRatherThanThrowing() throws {
    let json = Data(
      """
      {
        "id": "g1", "stationId": "s1", "prizeName": "Two tickets",
        "winningNumber": 9, "status": "paused", "winnerUserId": null,
        "createdAt": "2026-06-13T17:00:00.000Z", "updatedAt": "2026-06-13T18:00:00.000Z"
      }
      """.utf8)
    let giveaway = try decoder().decode(GiveawayEvent.self, from: json)
    #expect(giveaway.status == .unknown)
  }

  @Test func decodesUnknownMyResultStatusAsUnknown() throws {
    let json = Data(
      #"{ "tapNumber": null, "isWinner": false, "status": "expired", "winningNumber": 9 }"#.utf8)
    let result = try decoder().decode(GiveawayMyResult.self, from: json)
    #expect(result.status == .unknown)
    #expect(result.isResolved == false)
  }

  @Test func decodesTapResponse() throws {
    let json = Data(#"{ "tapNumber": 14, "isWinner": false, "status": "open" }"#.utf8)
    let response = try decoder().decode(GiveawayTapResponse.self, from: json)
    #expect(response.tapNumber == 14)
    #expect(response.isWinner == false)
    #expect(response.status == .open)
  }

  @Test func decodesMyResultWithNullTapNumber() throws {
    let json = Data(
      #"{ "tapNumber": null, "isWinner": false, "status": "closed", "winningNumber": 9 }"#.utf8)
    let result = try decoder().decode(GiveawayMyResult.self, from: json)
    #expect(result.tapNumber == nil)
    #expect(result.status == .closed)
    #expect(result.winningNumber == 9)
  }

  @Test func decodesWinnerSubmission() throws {
    let json = Data(
      """
      { "id": "sub1", "giveawayId": "g1", "userId": "u1", "fullName": "Brian Keane",
        "addressLine1": "123 Main", "city": "Austin", "postalCode": "78701",
        "country": "US", "willingToRecord": true, "fulfillmentStatus": "pending",
        "submittedAt": "2026-06-13T19:00:00.000Z" }
      """.utf8)
    let submission = try decoder().decode(GiveawayWinnerSubmission.self, from: json)
    #expect(submission.id == "sub1")
    #expect(submission.willingToRecord == true)
    #expect(submission.fulfillmentStatus == .pending)
  }

  @Test func decodesUnknownFulfillmentStatusAsUnknown() throws {
    let json = Data(
      """
      { "id": "sub1", "giveawayId": "g1", "userId": "u1", "fullName": "X",
        "addressLine1": "1", "city": "Austin", "postalCode": "78701",
        "country": "US", "willingToRecord": false, "fulfillmentStatus": "shipped",
        "submittedAt": "2026-06-13T19:00:00.000Z" }
      """.utf8)
    let submission = try decoder().decode(GiveawayWinnerSubmission.self, from: json)
    #expect(submission.fulfillmentStatus == .unknown)
  }
}
