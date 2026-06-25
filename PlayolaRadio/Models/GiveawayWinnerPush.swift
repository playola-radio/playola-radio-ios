import Foundation

/// The targeted "you won" push the server sends to a resolved winner's devices at close (covers the
/// last-tapper promotion and reinstall / second-device cases). Parsed from an APNs userInfo payload.
struct GiveawayWinnerPush: Equatable, Sendable {
  let eventId: String
  let stationId: String?
  let giveawayId: String?
  let prizeName: String
  let prizeDescription: String?
  let prizeImageUrl: URL?
  let winningNumber: Int
  let tapNumber: Int
  let winnerUserId: String?
  let reason: String?
  let submissionCompleted: Bool?
  let canSubmitMailingInfo: Bool?

  init?(userInfo: [String: any Sendable]) {
    guard userInfo["type"] as? String == "giveaway_winner",
      let eventId = userInfo["eventId"] as? String,
      let prizeName = userInfo["prizeName"] as? String,
      let winningNumber = userInfo["winningNumber"] as? Int,
      let tapNumber = userInfo["tapNumber"] as? Int
    else { return nil }
    self.eventId = eventId
    self.stationId = userInfo["stationId"] as? String
    self.giveawayId = userInfo["giveawayId"] as? String
    self.prizeName = prizeName
    self.prizeDescription = userInfo["prizeDescription"] as? String
    self.prizeImageUrl = (userInfo["prizeImageUrl"] as? String).flatMap(URL.init(string:))
    self.winningNumber = winningNumber
    self.tapNumber = tapNumber
    self.winnerUserId = userInfo["winnerUserId"] as? String
    self.reason = userInfo["reason"] as? String
    self.submissionCompleted = userInfo["submissionCompleted"] as? Bool
    self.canSubmitMailingInfo = userInfo["canSubmitMailingInfo"] as? Bool
  }
}
