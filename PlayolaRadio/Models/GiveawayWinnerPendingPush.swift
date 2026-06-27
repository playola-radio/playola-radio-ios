import Foundation

/// The owner-only `giveaway_winner_pending` push: a station owner's giveaway has a winner, so they
/// can record a congrats. Parsed from an APNs userInfo payload. (winnerName/prizeName/congratsExpiresAt
/// are structured data fields the server adds alongside the human-readable alert body.)
struct GiveawayWinnerPendingPush: Equatable, Sendable {
  let eventId: String
  let stationId: String
  let giveawayId: String?
  let winnerName: String?
  let prizeName: String?
  let congratsExpiresAt: Date?

  init?(userInfo: [String: any Sendable]) {
    guard userInfo["type"] as? String == "giveaway_winner_pending",
      let eventId = userInfo["eventId"] as? String,
      let stationId = userInfo["stationId"] as? String
    else { return nil }
    self.eventId = eventId
    self.stationId = stationId
    self.giveawayId = userInfo["giveawayId"] as? String
    self.winnerName = userInfo["winnerName"] as? String
    self.prizeName = userInfo["prizeName"] as? String
    self.congratsExpiresAt = (userInfo["congratsExpiresAt"] as? String).flatMap(Self.parseISO8601)
  }

  /// Robust ISO-8601 parse: the server sends fractional seconds, but tolerate a value without them.
  private static func parseISO8601(_ string: String) -> Date? {
    let withFractional = ISO8601DateFormatter()
    withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = withFractional.date(from: string) { return date }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: string)
  }
}
