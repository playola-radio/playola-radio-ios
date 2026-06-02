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
}
