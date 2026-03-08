//
//  UserPrize.swift
//  PlayolaRadio
//

import Foundation

struct UserPrize: Decodable, Sendable, Identifiable, Equatable {
  let id: String
  let userId: String
  let prizeId: String
  let stationId: String?
  let redeemedAt: Date
  let createdAt: Date
  let updatedAt: Date
  let prize: Prize?

  enum CodingKeys: String, CodingKey {
    case id
    case userId
    case prizeId
    case stationId
    case redeemedAt
    case createdAt
    case updatedAt
    case prize
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    userId = try container.decode(String.self, forKey: .userId)
    prizeId = try container.decode(String.self, forKey: .prizeId)
    stationId = try container.decodeIfPresent(String.self, forKey: .stationId)
    redeemedAt = try container.decode(Date.self, forKey: .redeemedAt)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    prize = try container.decodeIfPresent(Prize.self, forKey: .prize)
  }

  init(
    id: String,
    userId: String,
    prizeId: String,
    stationId: String? = nil,
    redeemedAt: Date = Date(),
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    prize: Prize? = nil
  ) {
    self.id = id
    self.userId = userId
    self.prizeId = prizeId
    self.stationId = stationId
    self.redeemedAt = redeemedAt
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.prize = prize
  }
}
