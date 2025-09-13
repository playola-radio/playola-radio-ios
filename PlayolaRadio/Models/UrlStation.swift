//
//  UrlStation.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 9/13/25.
//

import FRadioPlayer
import Foundation
import UIKit

struct UrlStation: Codable, Identifiable, Equatable, Sendable {
  static func == (lhs: UrlStation, rhs: UrlStation) -> Bool {
    lhs.id == rhs.id
  }

  var id: String
  var name: String
  var streamUrl: String
  var imageUrl: URL?
  var description: String
  var website: String?
  var location: String?
  var active: Bool?
  var createdAt: Date
  var updatedAt: Date

  // Custom coding keys to handle the imageUrl conversion
  private enum CodingKeys: String, CodingKey {
    case id, name, streamUrl, description, website, location, active, createdAt, updatedAt
    case imageUrlString = "imageUrl"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    streamUrl = try container.decode(String.self, forKey: .streamUrl)
    description = try container.decode(String.self, forKey: .description)
    website = try container.decodeIfPresent(String.self, forKey: .website)
    location = try container.decodeIfPresent(String.self, forKey: .location)
    active = try container.decodeIfPresent(Bool.self, forKey: .active)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)

    // Convert imageUrl string to URL if possible
    if let imageUrlString = try container.decodeIfPresent(String.self, forKey: .imageUrlString) {
      imageUrl = URL(string: imageUrlString)
    } else {
      imageUrl = nil
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(streamUrl, forKey: .streamUrl)
    try container.encode(description, forKey: .description)
    try container.encodeIfPresent(website, forKey: .website)
    try container.encodeIfPresent(location, forKey: .location)
    try container.encodeIfPresent(active, forKey: .active)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(updatedAt, forKey: .updatedAt)

    // Convert URL back to string for encoding
    try container.encodeIfPresent(imageUrl?.absoluteString, forKey: .imageUrlString)
  }

  // Initializer that accepts URL directly
  init(
    id: String, name: String, streamUrl: String, imageUrl: URL?, description: String,
    website: String? = nil, location: String? = nil, active: Bool? = nil,
    createdAt: Date, updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.streamUrl = streamUrl
    self.imageUrl = imageUrl
    self.description = description
    self.website = website
    self.location = location
    self.active = active
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  // Initializer that accepts string and converts to URL
  init(
    id: String, name: String, streamUrl: String, imageUrl: String, description: String,
    website: String? = nil, location: String? = nil, active: Bool? = nil,
    createdAt: Date, updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.streamUrl = streamUrl
    self.imageUrl = URL(string: imageUrl)
    self.description = description
    self.website = website
    self.location = location
    self.active = active
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension UrlStation {
  func getImage(completion: @escaping (_ image: UIImage) -> Void) {
    if let imageUrl = imageUrl {
      // load current station image from network
      UIImage.image(from: imageUrl) { image in
        // swiftlint:disable:next force_unwrapping
        completion(image ?? UIImage(named: "stationImage")!)
      }
    } else {
      // load default station image
      // swiftlint:disable:next force_unwrapping
      let image = UIImage(named: "stationImage")!
      completion(image)
    }
  }

  var trackName: String {
    FRadioPlayer.shared.currentMetadata?.trackName ?? name
  }

  var artistName: String {
    FRadioPlayer.shared.currentMetadata?.artistName ?? description
  }

  static var mock: UrlStation {
    StationList.mocks.first(where: { !$0.urlStations.isEmpty })!.urlStations.first!
  }
}
