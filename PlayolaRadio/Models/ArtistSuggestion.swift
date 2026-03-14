//
//  ArtistSuggestion.swift
//  PlayolaRadio
//

import Foundation

struct ArtistSuggestion: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let artistName: String
  let createdByUserId: String
  let voteCount: Int
  let hasVoted: Bool
  let createdAt: Date
  let updatedAt: Date
}
