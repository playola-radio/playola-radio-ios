import Foundation

/// A row from the cross-station discovery feed (`GET /v1/giveaway-events?status=open,scheduled`).
/// Drives the in-app banner and pre-arm discovery. Carries `opensAt` but not `serverTime` — skew
/// is computed from the `:eventId` GET at arm time.
struct GiveawayEventFeedItem: Decodable, Sendable, Identifiable, Equatable {
  let eventId: String
  let stationId: String
  let stationName: String
  let stationImageUrl: URL?
  let prizeName: String
  let prizeImageUrl: URL?
  let winningNumber: Int
  let opensAt: Date?
  let status: GiveawayStatus

  var id: String { eventId }

  enum CodingKeys: String, CodingKey {
    case eventId, stationId, stationName, stationImageUrl, prizeName, prizeImageUrl
    case winningNumber, opensAt, status
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    eventId = try container.decode(String.self, forKey: .eventId)
    stationId = try container.decode(String.self, forKey: .stationId)
    stationName = try container.decode(String.self, forKey: .stationName)
    if let raw = try container.decodeIfPresent(String.self, forKey: .stationImageUrl) {
      stationImageUrl = URL(string: raw)
    } else {
      stationImageUrl = nil
    }
    prizeName = try container.decode(String.self, forKey: .prizeName)
    if let raw = try container.decodeIfPresent(String.self, forKey: .prizeImageUrl) {
      prizeImageUrl = URL(string: raw)
    } else {
      prizeImageUrl = nil
    }
    winningNumber = try container.decode(Int.self, forKey: .winningNumber)
    opensAt = try container.decodeIfPresent(Date.self, forKey: .opensAt)
    status = try container.decode(GiveawayStatus.self, forKey: .status)
  }

  init(
    eventId: String, stationId: String, stationName: String, stationImageUrl: URL? = nil,
    prizeName: String, prizeImageUrl: URL? = nil, winningNumber: Int, opensAt: Date? = nil,
    status: GiveawayStatus
  ) {
    self.eventId = eventId
    self.stationId = stationId
    self.stationName = stationName
    self.stationImageUrl = stationImageUrl
    self.prizeName = prizeName
    self.prizeImageUrl = prizeImageUrl
    self.winningNumber = winningNumber
    self.opensAt = opensAt
    self.status = status
  }

  static var mock: GiveawayEventFeedItem {
    GiveawayEventFeedItem(
      eventId: "event-1", stationId: "station-1", stationName: "Reckless Radio",
      prizeName: "Two tickets to Reckless Kelly at the Heights", winningNumber: 9,
      opensAt: Date(timeIntervalSince1970: 1_781_722_800), status: .open)
  }
}
