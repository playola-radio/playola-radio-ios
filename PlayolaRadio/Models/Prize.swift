//
//  Prize.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/27/25.
//

import Foundation

struct Prize: Decodable, Sendable, Identifiable, Equatable {
  let id: String
  let name: String
  let prizeTierId: String
  let imageUrl: URL?
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case prizeTierId
    case imageUrl
    case createdAt
    case updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    prizeTierId = try container.decode(String.self, forKey: .prizeTierId)

    if let imageUrlStr = try container.decodeIfPresent(String.self, forKey: .imageUrl) {
      imageUrl = URL(string: imageUrlStr)
    } else {
      imageUrl = nil
    }

    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  public init(
    id: String,
    name: String,
    prizeTierId: String,
    imageUrl: URL?,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.prizeTierId = prizeTierId
    self.imageUrl = imageUrl
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension Prize {
  public static var mocks: [Prize] {
    return PrizeTier.mocks.flatMap { $0.prizes }
  }
  public static var mock: Prize {
    return .mocks.first!
  }
}
