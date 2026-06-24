import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@MainActor
struct GiveawayWinnerPushTests {
  @Test func parsesValidWinnerPush() {
    let push = GiveawayWinnerPush(userInfo: [
      "type": "giveaway_winner", "eventId": "evt-1", "stationId": "stn-1",
      "prizeName": "Two tickets", "winningNumber": 9, "tapNumber": 5,
      "reason": "last_tapper_fallback", "canSubmitMailingInfo": true,
    ])
    expectNoDifference(push?.eventId, "evt-1")
    expectNoDifference(push?.tapNumber, 5)
    expectNoDifference(push?.reason, "last_tapper_fallback")
    expectNoDifference(push?.canSubmitMailingInfo, true)
  }

  @Test func rejectsWrongType() {
    #expect(GiveawayWinnerPush(userInfo: ["type": "giveaway_closed", "eventId": "evt-1"]) == nil)
  }

  @Test func rejectsMissingRequiredFields() {
    #expect(GiveawayWinnerPush(userInfo: ["type": "giveaway_winner", "eventId": "evt-1"]) == nil)
  }

  @Test func submissionRequestParametersDropEmptyOptionals() {
    let request = GiveawayWinnerSubmissionRequest(
      fullName: "Jo", addressLine1: "1 Main", city: "Austin", state: "TX",
      postalCode: "78701", addressLine2: nil, country: "US", comment: nil)
    expectNoDifference(
      request.asParameters,
      [
        "fullName": "Jo", "addressLine1": "1 Main", "city": "Austin",
        "state": "TX", "postalCode": "78701", "country": "US",
      ])
  }
}
