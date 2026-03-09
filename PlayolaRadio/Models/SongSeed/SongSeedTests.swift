//
//  SongSeedTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import XCTest

@testable import PlayolaRadio

final class SongRequestTests: XCTestCase {

  func testSongRequestDecodesFromJSON() throws {
    let jsonString = """
      {
        "title": "Like a Rolling Stone",
        "artist": "Bob Dylan",
        "album": "Highway 61 Revisited",
        "durationMS": 369600,
        "popularity": 78,
        "releaseDate": "1965-08-30",
        "isrc": "USSM16500213",
        "appleId": "1440806768",
        "spotifyId": "3AhXZa8sUQht0UEdBJgpGc",
        "imageUrl": "https://i.scdn.co/image/test"
      }
      """
    let json = Data(jsonString.utf8)

    let songRequest = try JSONDecoder().decode(SongRequest.self, from: json)

    XCTAssertEqual(songRequest.title, "Like a Rolling Stone")
    XCTAssertEqual(songRequest.artist, "Bob Dylan")
    XCTAssertEqual(songRequest.album, "Highway 61 Revisited")
    XCTAssertEqual(songRequest.durationMS, 369600)
    XCTAssertEqual(songRequest.popularity, 78)
    XCTAssertEqual(songRequest.releaseDate, "1965-08-30")
    XCTAssertEqual(songRequest.isrc, "USSM16500213")
    XCTAssertEqual(songRequest.appleId, "1440806768")
    XCTAssertEqual(songRequest.spotifyId, "3AhXZa8sUQht0UEdBJgpGc")
    XCTAssertEqual(songRequest.imageUrl, URL(string: "https://i.scdn.co/image/test"))
    XCTAssertNil(songRequest.requestId)
  }

  func testSongRequestDecodesWithRequestId() throws {
    let jsonString = """
      {
        "id": "request-abc-123",
        "title": "Like a Rolling Stone",
        "artist": "Bob Dylan",
        "album": "Highway 61 Revisited",
        "durationMS": 369600,
        "popularity": 78,
        "releaseDate": "1965-08-30",
        "isrc": "USSM16500213",
        "appleId": "1440806768",
        "spotifyId": "3AhXZa8sUQht0UEdBJgpGc",
        "imageUrl": "https://i.scdn.co/image/test"
      }
      """
    let json = Data(jsonString.utf8)

    let songRequest = try JSONDecoder().decode(SongRequest.self, from: json)

    XCTAssertEqual(songRequest.requestId, "request-abc-123")
  }

  func testSongRequestDecodesWithNullImageUrl() throws {
    let jsonString = """
      {
        "title": "Test Song",
        "artist": "Test Artist",
        "album": "Test Album",
        "durationMS": 180000,
        "popularity": 50,
        "releaseDate": "2020-01-01",
        "isrc": "TEST123",
        "appleId": "1440806768",
        "imageUrl": null
      }
      """
    let json = Data(jsonString.utf8)

    let songRequest = try JSONDecoder().decode(SongRequest.self, from: json)

    XCTAssertNil(songRequest.imageUrl)
  }

  func testSongRequestDecodesWithMissingImageUrl() throws {
    let jsonString = """
      {
        "title": "Test Song",
        "artist": "Test Artist",
        "album": "Test Album",
        "durationMS": 180000,
        "popularity": 50,
        "releaseDate": "2020-01-01",
        "isrc": "TEST123",
        "appleId": "1440806768"
      }
      """
    let json = Data(jsonString.utf8)

    let songRequest = try JSONDecoder().decode(SongRequest.self, from: json)

    XCTAssertNil(songRequest.imageUrl)
  }

  func testSongRequestDecodesWithNullOptionalFields() throws {
    let jsonString = """
      {
        "title": "Test Song",
        "artist": "Test Artist",
        "album": "Test Album",
        "durationMS": 180000,
        "releaseDate": "2020-01-01",
        "appleId": "1440806768"
      }
      """
    let json = Data(jsonString.utf8)

    let songRequest = try JSONDecoder().decode(SongRequest.self, from: json)

    XCTAssertNil(songRequest.popularity)
    XCTAssertNil(songRequest.isrc)
    XCTAssertNil(songRequest.spotifyId)
    XCTAssertNil(songRequest.imageUrl)
  }

  func testSongRequestMockWithReturnsValidInstance() {
    let songRequest = SongRequest.mockWith(
      title: "Custom Title",
      artist: "Custom Artist",
      appleId: "custom-apple-id"
    )

    XCTAssertEqual(songRequest.title, "Custom Title")
    XCTAssertEqual(songRequest.artist, "Custom Artist")
    XCTAssertEqual(songRequest.appleId, "custom-apple-id")
  }

  func testSongRequestIdentifiableUsesAppleIdAsId() {
    let songRequest = SongRequest.mockWith(appleId: "unique-apple-id")

    XCTAssertEqual(songRequest.id, "unique-apple-id")
  }
}
