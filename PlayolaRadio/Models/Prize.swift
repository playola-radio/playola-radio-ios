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
  let tier: Int
  let requiredListeningHours: Int
  let imageUrl: URL?
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case tier
    case requiredListeningHours
    case imageUrl
    case createdAt
    case updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    tier = try container.decode(Int.self, forKey: .tier)
    requiredListeningHours = try container.decode(
      Int.self,
      forKey: .requiredListeningHours
    )
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)

    if let imageUrlString = try container.decodeIfPresent(
      String.self,
      forKey: .imageUrl
    ) {
      imageUrl = URL(string: imageUrlString)
    } else {
      imageUrl = nil
    }
  }

  init(
    id: String,
    name: String,
    tier: Int,
    requiredListeningHours: Int,
    imageUrl: URL?,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.tier = tier
    self.requiredListeningHours = requiredListeningHours
    self.imageUrl = imageUrl
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension Prize {
  static var mock: Prize {
    return .mocks[0]
  }
  static var mocks: [Prize] {
    return [
      Prize(
        id: "1",
        name: "Bri Bagwell's Banned Radio Koozie",
        tier: 1,
        requiredListeningHours: 10,
        imageUrl: URL(string: "https://example.com/prizes/koozie-black.jpg")!
      ),
      Prize(
        id: "2",
        name: "Jacob Stelly's Moondog Radio Koozie",
        tier: 1,
        requiredListeningHours: 10,
        imageUrl: URL(string: "https://example.com/prizes/stelly-koozie.jpg")!
      ),
      Prize(
        id: "3",
        name: "Bri Bagwell's Banned Radio TShirt",
        tier: 2,
        requiredListeningHours: 30,
        imageUrl: URL(string: "https://example.com/prizes/stelly-tshirt.jpg")!
      ),
      Prize(
        id: "4",
        name: "Jacob Stelly's Moondog Radio TShirt",
        tier: 2,
        requiredListeningHours: 30,
        imageUrl: URL(string: "https://example.com/prizes/stelly-tshirt.jpg")!
      ),
      Prize(
        id: "5",
        name: "Bri Bagwell's Banned Radio TShirt",
        tier: 3,
        requiredListeningHours: 70,
        imageUrl: URL(string: "https://example.com/prizes/stelly-tshirt.jpg")!
      ),
      Prize(
        id: "6",
        name: "Jacob Stelly's Moondog Radio TShirt",
        tier: 3,
        requiredListeningHours: 70,
        imageUrl: URL(string: "https://example.com/prizes/stelly-tshirt.jpg")!
      ),
      Prize(
        id: "7",
        name: "Bri Bagwell Meet & Greet",
        tier: 4,
        requiredListeningHours: 150,
        imageUrl: URL(string: "https://example.com/prizes/stelly-tshirt.jpg")!
      ),
      Prize(
        id: "8",
        name: "Jacob Stelly Meet & Greet",
        tier: 4,
        requiredListeningHours: 150,
        imageUrl: URL(string: "https://example.com/prizes/stelly-tshirt.jpg")!
      ),
    ]
  }
}
