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
