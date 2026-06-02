//
//  ArtistSuggestionTests.swift
//  PlayolaRadio
//

import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

struct ArtistSuggestionStatusTests {

  @Test
  func decodesKnownStatuses() throws {
    let json = Data(#"["suggested", "in_development", "streaming"]"#.utf8)

    let statuses = try JSONDecoder().decode([ArtistSuggestionStatus].self, from: json)

    expectNoDifference(statuses, [.suggested, .inDevelopment, .streaming])
  }

  @Test
  func decodesUnrecognizedStatusAsUnknown() throws {
    let json = Data(#"["archived"]"#.utf8)

    let statuses = try JSONDecoder().decode([ArtistSuggestionStatus].self, from: json)

    expectNoDifference(statuses, [.unknown])
  }

  @Test
  func decodesMissingStatusAsSuggested() throws {
    let json = Data(
      #"""
      {
        "id": "s1",
        "artistName": "Bri Bagwell",
        "createdByUserId": "u1",
        "voteCount": 3,
        "hasVoted": false,
        "createdAt": 0,
        "updatedAt": 0
      }
      """#.utf8)

    let suggestion = try JSONDecoder().decode(ArtistSuggestion.self, from: json)

    expectNoDifference(suggestion.status, .suggested)
  }
}
