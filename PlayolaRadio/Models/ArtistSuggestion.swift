//
//  ArtistSuggestion.swift
//  PlayolaRadio
//

import Foundation

enum ArtistSuggestionStatus: String, Codable, Equatable, Sendable {
  case suggested
  case inDevelopment = "in_development"
  case streaming
  case unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = ArtistSuggestionStatus(rawValue: raw) ?? .unknown
  }
}

struct ArtistSuggestion: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let artistName: String
  let createdByUserId: String
  let voteCount: Int
  let hasVoted: Bool
  let status: ArtistSuggestionStatus
  let createdAt: Date
  let updatedAt: Date
}

extension ArtistSuggestion {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    artistName = try container.decode(String.self, forKey: .artistName)
    createdByUserId = try container.decode(String.self, forKey: .createdByUserId)
    voteCount = try container.decode(Int.self, forKey: .voteCount)
    hasVoted = try container.decode(Bool.self, forKey: .hasVoted)
    status =
      try container.decodeIfPresent(ArtistSuggestionStatus.self, forKey: .status) ?? .suggested
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }
}
