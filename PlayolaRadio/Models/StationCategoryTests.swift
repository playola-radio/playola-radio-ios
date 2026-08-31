//
//  StationCategoryTests.swift
//  PlayolaRadio
//

import CustomDump
import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct StationCategoryTests {

  private func makeJSON(id: String, name: String, audioBlockType: String) -> Data {
    let json = """
      {
        "id": "\(id)",
        "name": "\(name)",
        "audioBlockType": "\(audioBlockType)",
        "audioBlocks": [],
        "createdAt": "2026-01-01T00:00:00.000+0000",
        "updatedAt": "2026-01-01T00:00:00.000+0000"
      }
      """
    return Data(json.utf8)
  }

  @Test func decodesKnownAudioBlockType() throws {
    let json = makeJSON(id: "cat-1", name: "Station IDs", audioBlockType: "audioimage")

    let category = try JSONDecoderWithIsoFull().decode(StationCategory.self, from: json)

    expectNoDifference(category.id, "cat-1")
    expectNoDifference(category.name, "Station IDs")
    expectNoDifference(category.audioBlockType, .audioimage)
  }

  @Test func decodesUnrecognizedAudioBlockTypeAsUnknown() throws {
    let json = makeJSON(id: "cat-2", name: "Mystery", audioBlockType: "somethingBrandNew")

    let category = try JSONDecoderWithIsoFull().decode(StationCategory.self, from: json)

    expectNoDifference(category.audioBlockType, .unknown)
  }

  @Test func isSongTrueOnlyForSongType() {
    let songCategory = StationCategory.mockWith(audioBlockType: .song)
    let commercialCategory = StationCategory.mockWith(audioBlockType: .commercialblock)

    #expect(songCategory.isSong)
    #expect(!commercialCategory.isSong)
  }
}
