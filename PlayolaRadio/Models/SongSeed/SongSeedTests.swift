//
//  SongSeedTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import XCTest

@testable import PlayolaRadio

final class SongSeedTests: XCTestCase {

  func testSongSeed_DecodesFromJSON() throws {
    let json = """
      {
        "title": "Like a Rolling Stone",
        "artist": "Bob Dylan",
        "album": "Highway 61 Revisited",
        "durationMS": 369600,
        "popularity": 78,
        "releaseDate": "1965-08-30",
        "isrc": "USSM16500213",
        "spotifyId": "3AhXZa8sUQht0UEdBJgpGc",
        "imageUrl": "https://i.scdn.co/image/test"
      }
      """.data(using: .utf8)!

    let songSeed = try JSONDecoder().decode(SongSeed.self, from: json)

    XCTAssertEqual(songSeed.title, "Like a Rolling Stone")
    XCTAssertEqual(songSeed.artist, "Bob Dylan")
    XCTAssertEqual(songSeed.album, "Highway 61 Revisited")
    XCTAssertEqual(songSeed.durationMS, 369600)
    XCTAssertEqual(songSeed.popularity, 78)
    XCTAssertEqual(songSeed.releaseDate, "1965-08-30")
    XCTAssertEqual(songSeed.isrc, "USSM16500213")
    XCTAssertEqual(songSeed.spotifyId, "3AhXZa8sUQht0UEdBJgpGc")
    XCTAssertEqual(songSeed.imageUrl, URL(string: "https://i.scdn.co/image/test"))
  }

  func testSongSeed_DecodesWithNullImageUrl() throws {
    let json = """
      {
        "title": "Test Song",
        "artist": "Test Artist",
        "album": "Test Album",
        "durationMS": 180000,
        "popularity": 50,
        "releaseDate": "2020-01-01",
        "isrc": "TEST123",
        "spotifyId": "spotifyId123",
        "imageUrl": null
      }
      """.data(using: .utf8)!

    let songSeed = try JSONDecoder().decode(SongSeed.self, from: json)

    XCTAssertNil(songSeed.imageUrl)
  }

  func testSongSeed_DecodesWithMissingImageUrl() throws {
    let json = """
      {
        "title": "Test Song",
        "artist": "Test Artist",
        "album": "Test Album",
        "durationMS": 180000,
        "popularity": 50,
        "releaseDate": "2020-01-01",
        "isrc": "TEST123",
        "spotifyId": "spotifyId123"
      }
      """.data(using: .utf8)!

    let songSeed = try JSONDecoder().decode(SongSeed.self, from: json)

    XCTAssertNil(songSeed.imageUrl)
  }

  func testSongSeed_MockWith_ReturnsValidInstance() {
    let songSeed = SongSeed.mockWith(
      title: "Custom Title",
      artist: "Custom Artist",
      spotifyId: "custom-spotify-id"
    )

    XCTAssertEqual(songSeed.title, "Custom Title")
    XCTAssertEqual(songSeed.artist, "Custom Artist")
    XCTAssertEqual(songSeed.spotifyId, "custom-spotify-id")
  }

  func testSongSeed_Identifiable_UsesSpotifyIdAsId() {
    let songSeed = SongSeed.mockWith(spotifyId: "unique-spotify-id")

    XCTAssertEqual(songSeed.id, "unique-spotify-id")
  }
}
