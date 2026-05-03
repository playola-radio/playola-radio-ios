//
//  SongSeedTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

struct SongRequestTests {

  @Test
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

    expectNoDifference(songRequest, SongRequest.mockWith())
  }

  @Test
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

    #expect(songRequest.requestId == "request-abc-123")
  }

  @Test
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

    #expect(songRequest.imageUrl == nil)
  }

  @Test
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

    #expect(songRequest.imageUrl == nil)
  }

  @Test
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

    #expect(songRequest.popularity == nil)
    #expect(songRequest.isrc == nil)
    #expect(songRequest.spotifyId == nil)
    #expect(songRequest.imageUrl == nil)
  }

  @Test
  func testSongRequestMockWithReturnsValidInstance() {
    let songRequest = SongRequest.mockWith(
      title: "Custom Title",
      artist: "Custom Artist",
      appleId: "custom-apple-id"
    )

    #expect(songRequest.title == "Custom Title")
    #expect(songRequest.artist == "Custom Artist")
    #expect(songRequest.appleId == "custom-apple-id")
  }

  @Test
  func testSongRequestIdentifiableUsesAppleIdAsId() {
    let songRequest = SongRequest.mockWith(appleId: "unique-apple-id")

    #expect(songRequest.id == "unique-apple-id")
  }
}
