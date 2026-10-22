//
//  SongSuggestionTests.swift
//  PlayolaRadio
//

import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct SongSuggestionTests {
  private func decoder() -> JSONDecoder { JSONDecoderWithIsoFull() }

  private let sample = Data(
    """
    [
      {
        "audioBlock": {
          "id": "9f8e", "type": "song", "title": "Cosmic Highway",
          "artist": "The Wanderers", "album": "Neon Dreams", "durationMS": 214000,
          "s3Key": "songs/9f8e.m4a", "s3BucketName": "playola-audio",
          "downloadUrl": "https://audio.test/9f8e.m4a",
          "imageUrl": "https://img.test/9f8e.jpg",
          "spotifyId": "sp9f8e", "appleId": "111", "isrc": "USABC0000001",
          "popularity": 55, "youTubeId": 42, "releaseDate": "2024-05-01",
          "endOfMessageMS": 214000, "endOfIntroMS": 8000,
          "beginningOfOutroMS": 200000, "lengthOfOutroMS": 14000,
          "createdAt": "2026-01-01T00:00:00.000Z",
          "updatedAt": "2026-01-02T00:00:00.000Z"
        }
      },
      {
        "audioBlock": {
          "id": "1a2b", "type": "song", "title": "Slow Burn",
          "artist": "Marigold", "album": null, "durationMS": 187000,
          "s3Key": "songs/1a2b.m4a", "s3BucketName": "playola-audio",
          "downloadUrl": "https://audio.test/1a2b.m4a",
          "imageUrl": null, "spotifyId": "sp1a2b", "appleId": null,
          "isrc": "USABC0000002", "popularity": 12, "youTubeId": null,
          "releaseDate": null, "endOfMessageMS": 187000, "endOfIntroMS": 5000,
          "beginningOfOutroMS": 175000, "lengthOfOutroMS": 12000,
          "createdAt": "2026-01-03T00:00:00.000Z",
          "updatedAt": "2026-01-04T00:00:00.000Z"
        }
      }
    ]
    """.utf8)

  @Test func decodesBothEntriesIncludingNullableFields() throws {
    let suggestions = try decoder().decode([SongSuggestion].self, from: sample)

    #expect(suggestions.count == 2)

    let first = suggestions[0]
    #expect(first.audioBlock.id == "9f8e")
    #expect(first.audioBlock.title == "Cosmic Highway")
    #expect(first.audioBlock.album == "Neon Dreams")
    #expect(first.audioBlock.appleId == "111")
    #expect(first.audioBlock.downloadUrl != nil)
    #expect(first.audioBlock.imageUrl != nil)

    let second = suggestions[1]
    #expect(second.audioBlock.id == "1a2b")
    #expect(second.audioBlock.album == nil)
    #expect(second.audioBlock.appleId == nil)
    #expect(second.audioBlock.imageUrl == nil)
    #expect(second.audioBlock.downloadUrl != nil)
  }

  @Test func decodesEmptyArray() throws {
    let suggestions = try decoder().decode([SongSuggestion].self, from: Data("[]".utf8))
    #expect(suggestions.isEmpty)
  }

  @Test func toleratesUnknownSiblingFields() throws {
    let json = Data(
      """
      [
        {
          "audioBlock": {
            "id": "x1", "type": "song", "title": "T", "artist": "A",
            "durationMS": 1000, "s3Key": "k", "s3BucketName": "b",
            "downloadUrl": "https://audio.test/x1.m4a",
            "endOfMessageMS": 1000, "endOfIntroMS": 100,
            "beginningOfOutroMS": 900, "lengthOfOutroMS": 100,
            "createdAt": "2026-01-01T00:00:00.000Z",
            "updatedAt": "2026-01-01T00:00:00.000Z"
          },
          "heardSpins": 1,
          "reason": "least-recently-played"
        }
      ]
      """.utf8)

    let suggestions = try decoder().decode([SongSuggestion].self, from: json)
    #expect(suggestions.count == 1)
    #expect(suggestions[0].audioBlock.id == "x1")
  }
}
