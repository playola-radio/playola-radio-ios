import Foundation

enum GiveawayStatus: String, Codable, Sendable, Equatable {
  case scheduled
  case open
  case closed
  case canceled
}

struct Giveaway: Decodable, Sendable, Identifiable, Equatable {
  let id: String
  let stationId: String
  let prizeName: String
  let prizeDescription: String?
  let prizeImageUrl: URL?
  let winningNumber: Int
  let status: GiveawayStatus
  let winnerUserId: String?
  let openedAt: Date?
  let closedAt: Date?
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id, stationId, prizeName, prizeDescription, prizeImageUrl, winningNumber
    case status, winnerUserId, openedAt, closedAt, createdAt, updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    stationId = try container.decode(String.self, forKey: .stationId)
    prizeName = try container.decode(String.self, forKey: .prizeName)
    prizeDescription = try container.decodeIfPresent(String.self, forKey: .prizeDescription)
    if let raw = try container.decodeIfPresent(String.self, forKey: .prizeImageUrl) {
      prizeImageUrl = URL(string: raw)
    } else {
      prizeImageUrl = nil
    }
    winningNumber = try container.decode(Int.self, forKey: .winningNumber)
    status = try container.decode(GiveawayStatus.self, forKey: .status)
    winnerUserId = try container.decodeIfPresent(String.self, forKey: .winnerUserId)
    openedAt = try container.decodeIfPresent(Date.self, forKey: .openedAt)
    closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  init(
    id: String, stationId: String, prizeName: String, prizeDescription: String? = nil,
    prizeImageUrl: URL? = nil, winningNumber: Int, status: GiveawayStatus,
    winnerUserId: String? = nil, openedAt: Date? = nil, closedAt: Date? = nil,
    createdAt: Date = Date(), updatedAt: Date = Date()
  ) {
    self.id = id
    self.stationId = stationId
    self.prizeName = prizeName
    self.prizeDescription = prizeDescription
    self.prizeImageUrl = prizeImageUrl
    self.winningNumber = winningNumber
    self.status = status
    self.winnerUserId = winnerUserId
    self.openedAt = openedAt
    self.closedAt = closedAt
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  static var mock: Giveaway {
    Giveaway(
      id: "giveaway-1", stationId: "station-1",
      prizeName: "Two tickets to Reckless Kelly at the Heights",
      prizeDescription: "Friday night, doors at 8.",
      prizeImageUrl: URL(string: "https://example.com/prize.png"),
      winningNumber: 9, status: .open)
  }
}
