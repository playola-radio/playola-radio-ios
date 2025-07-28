//
//  PrizeTier.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/28/25.
//

import Foundation

struct PrizeTier: Decodable, Sendable, Identifiable, Equatable {
  let id: String
  let name: String
  let requiredListeningHours: Int
  let imageIconUrl: URL?
  let prizes: [Prize]
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case requiredListeningHours
    case imageIconUrl
    case prizes
    case createdAt
    case updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    requiredListeningHours = try container.decode(Int.self, forKey: .requiredListeningHours)

    if let imageIconUrlStr = try container.decodeIfPresent(String.self, forKey: .imageIconUrl) {
      imageIconUrl = URL(string: imageIconUrlStr)
    } else {
      imageIconUrl = nil
    }

    prizes = try container.decode([Prize].self, forKey: .prizes)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  public init(
    id: String,
    name: String,
    requiredListeningHours: Int,
    imageIconUrl: URL?,
    prizes: [Prize],
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.requiredListeningHours = requiredListeningHours
    self.imageIconUrl = imageIconUrl
    self.prizes = prizes
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension PrizeTier {
  static var mock: PrizeTier {
    return .mocks[0]
  }

  static var mocks: [PrizeTier] {
    return [
      PrizeTier(
        id: "8e43d874-d63f-4479-8759-8258a0b63fc3",
        name: "Koozie",
        requiredListeningHours: 10,
        imageIconUrl: URL(
          string: "https://playola-static.s3.amazonaws.com/prize-images/koozieIcon-868080.svg"),
        prizes: [
          Prize(
            id: "7d03685d-1872-4bcd-a4b3-8d77f6999fd8",
            name: "Bri Bagwell's Banned Radio Koozie",
            prizeTierId: "8e43d874-d63f-4479-8759-8258a0b63fc3",
            imageUrl: nil
          ),
          Prize(
            id: "koozie-2",
            name: "Jacob Stelly's Moondog Radio Koozie",
            prizeTierId: "8e43d874-d63f-4479-8759-8258a0b63fc3",
            imageUrl: URL(string: "https://example.com/prizes/stelly-koozie.jpg")
          ),
        ],
        createdAt: Date(),
        updatedAt: Date()
      ),
      PrizeTier(
        id: "a1bb4557-4cbf-4c25-9e83-c768dee89798",
        name: "T-Shirt",
        requiredListeningHours: 30,
        imageIconUrl: URL(
          string: "https://playola-static.s3.amazonaws.com/prize-images/tshirt-icon-598371.svg"),
        prizes: [
          Prize(
            id: "tshirt-1",
            name: "Bri Bagwell's Banned Radio T-Shirt",
            prizeTierId: "a1bb4557-4cbf-4c25-9e83-c768dee89798",
            imageUrl: URL(string: "https://example.com/prizes/bri-tshirt.jpg")
          ),
          Prize(
            id: "tshirt-2",
            name: "Jacob Stelly's Moondog Radio T-Shirt",
            prizeTierId: "a1bb4557-4cbf-4c25-9e83-c768dee89798",
            imageUrl: URL(string: "https://example.com/prizes/stelly-tshirt.jpg")
          ),
          Prize(
            id: "4",
            name: "Jacob Stelly's Moondog Radio TShirt",
            prizeTierId: "a1bb4557-4cbf-4c25-9e83-c768dee89798",
            imageUrl: URL(string: "https://example.com/prizes/stelly-tshirt.jpg")
          ),
        ],
        createdAt: Date(),
        updatedAt: Date()
      ),
      PrizeTier(
        id: "fa2db5c8-107c-442c-b332-b7ffc08fe0e7",
        name: "Show Tix",
        requiredListeningHours: 70,
        imageIconUrl: URL(
          string: "https://playola-static.s3.amazonaws.com/prize-images/tix-icon-819496.svg"),
        prizes: [
          Prize(
            id: "tix-1",
            name: "Bri Bagwell Concert Tickets",
            prizeTierId: "fa2db5c8-107c-442c-b332-b7ffc08fe0e7",
            imageUrl: URL(string: "https://example.com/prizes/bri-concert-tix.jpg")
          ),
          Prize(
            id: "tix-2",
            name: "Jacob Stelly Show Tickets",
            prizeTierId: "fa2db5c8-107c-442c-b332-b7ffc08fe0e7",
            imageUrl: URL(string: "https://example.com/prizes/stelly-show-tix.jpg")
          ),
        ],
        createdAt: Date(),
        updatedAt: Date()
      ),
    ]
  }
}
