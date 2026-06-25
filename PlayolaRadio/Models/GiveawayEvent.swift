import Foundation

enum GiveawayStatus: String, Codable, Sendable, Equatable {
  case scheduled
  case open
  case closed
  case canceled
  case unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = GiveawayStatus(rawValue: raw) ?? .unknown
  }
}

/// Per-viewer state on a giveaway event (from the authoritative `:eventId` GET).
struct GiveawayEventViewer: Decodable, Sendable, Equatable {
  let hasTapped: Bool
  let isWinner: Bool
  let canSubmitMailingInfo: Bool
  let tapNumber: Int?

  init(
    hasTapped: Bool = false, isWinner: Bool = false, canSubmitMailingInfo: Bool = false,
    tapNumber: Int? = nil
  ) {
    self.hasTapped = hasTapped
    self.isWinner = isWinner
    self.canSubmitMailingInfo = canSubmitMailingInfo
    self.tapNumber = tapNumber
  }
}

/// The per-airing giveaway contest the app works with — the `GET /v1/giveaway-events/:id`
/// projection. Its `id` is the per-airing event id (fresh every rerun); never cache it across
/// airings — always re-read from the feed / push / schedule hint.
struct GiveawayEvent: Decodable, Sendable, Identifiable, Equatable {
  let id: String
  let stationId: String
  let airingId: String?
  let giveawayId: String?
  let status: GiveawayStatus
  let prizeName: String
  let prizeDescription: String?
  let prizeImageUrl: URL?
  let winningNumber: Int
  let opensAt: Date?
  /// Server's clock at response time (`:eventId` GET only) — for clock-skew/countdown correction.
  let serverTime: Date?
  let viewer: GiveawayEventViewer?

  enum CodingKeys: String, CodingKey {
    case id, stationId, airingId, giveawayId, status, prizeName, prizeDescription, prizeImageUrl
    case winningNumber, opensAt, serverTime, viewer
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    stationId = try container.decode(String.self, forKey: .stationId)
    airingId = try container.decodeIfPresent(String.self, forKey: .airingId)
    giveawayId = try container.decodeIfPresent(String.self, forKey: .giveawayId)
    status = try container.decode(GiveawayStatus.self, forKey: .status)
    prizeName = try container.decode(String.self, forKey: .prizeName)
    prizeDescription = try container.decodeIfPresent(String.self, forKey: .prizeDescription)
    if let raw = try container.decodeIfPresent(String.self, forKey: .prizeImageUrl) {
      prizeImageUrl = URL(string: raw)
    } else {
      prizeImageUrl = nil
    }
    winningNumber = try container.decode(Int.self, forKey: .winningNumber)
    opensAt = try container.decodeIfPresent(Date.self, forKey: .opensAt)
    serverTime = try container.decodeIfPresent(Date.self, forKey: .serverTime)
    viewer = try container.decodeIfPresent(GiveawayEventViewer.self, forKey: .viewer)
  }

  init(
    id: String, stationId: String, prizeName: String, prizeDescription: String? = nil,
    prizeImageUrl: URL? = nil, winningNumber: Int, status: GiveawayStatus,
    airingId: String? = nil, giveawayId: String? = nil, opensAt: Date? = nil,
    serverTime: Date? = nil, viewer: GiveawayEventViewer? = nil
  ) {
    self.id = id
    self.stationId = stationId
    self.airingId = airingId
    self.giveawayId = giveawayId
    self.status = status
    self.prizeName = prizeName
    self.prizeDescription = prizeDescription
    self.prizeImageUrl = prizeImageUrl
    self.winningNumber = winningNumber
    self.opensAt = opensAt
    self.serverTime = serverTime
    self.viewer = viewer
  }

  /// A copy flipped to `.open`, used to reveal the tap button instantly from data already in hand
  /// (the armed event) without waiting on a confirming network round-trip.
  func openedCopy() -> GiveawayEvent {
    GiveawayEvent(
      id: id, stationId: stationId, prizeName: prizeName, prizeDescription: prizeDescription,
      prizeImageUrl: prizeImageUrl, winningNumber: winningNumber, status: .open,
      airingId: airingId, giveawayId: giveawayId, opensAt: opensAt, serverTime: serverTime,
      viewer: viewer)
  }

  static var mock: GiveawayEvent {
    GiveawayEvent(
      id: "event-1", stationId: "station-1",
      prizeName: "Two tickets to Reckless Kelly at the Heights",
      prizeDescription: "Friday night, doors at 8.",
      prizeImageUrl: URL(string: "https://example.com/prize.png"),
      winningNumber: 9, status: .open,
      airingId: "airing-1", giveawayId: "giveaway-1",
      opensAt: Date(timeIntervalSince1970: 1_781_722_800),
      serverTime: Date(timeIntervalSince1970: 1_781_722_800))
  }
}
