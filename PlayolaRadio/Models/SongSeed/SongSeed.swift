//
//  SongSeed.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import Foundation

struct SongSeed: Codable, Identifiable, Equatable {
  let title: String
  let artist: String
  let album: String
  let durationMS: Int
  let popularity: Int
  let releaseDate: String
  let isrc: String
  let spotifyId: String
  let imageUrl: URL?

  var id: String { spotifyId }
}

// MARK: - Mock

extension SongSeed {
  static func mockWith(
    title: String = "Like a Rolling Stone",
    artist: String = "Bob Dylan",
    album: String = "Highway 61 Revisited",
    durationMS: Int = 369600,
    popularity: Int = 78,
    releaseDate: String = "1965-08-30",
    isrc: String = "USSM16500213",
    spotifyId: String = "3AhXZa8sUQht0UEdBJgpGc",
    imageUrl: URL? = URL(string: "https://i.scdn.co/image/test")
  ) -> SongSeed {
    SongSeed(
      title: title,
      artist: artist,
      album: album,
      durationMS: durationMS,
      popularity: popularity,
      releaseDate: releaseDate,
      isrc: isrc,
      spotifyId: spotifyId,
      imageUrl: imageUrl
    )
  }
}
