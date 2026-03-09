//
//  LibrarySong.swift
//  PlayolaRadio
//

import Foundation

struct LibrarySong: Codable, Identifiable, Equatable {
  let id: String
  let title: String
  let artist: String
  let album: String?
  let imageUrl: URL?
  let durationMS: Int
  let spotifyId: String?
}

// MARK: - Library Response

struct LibraryResponse: Codable, Equatable {
  let songs: [LibrarySong]
  let songIdsWithSongIntros: [String]
}

extension LibraryResponse {
  static func mockWith(
    songs: [LibrarySong] = [],
    songIdsWithSongIntros: [String] = []
  ) -> LibraryResponse {
    LibraryResponse(songs: songs, songIdsWithSongIntros: songIdsWithSongIntros)
  }
}

// MARK: - Mock

extension LibrarySong {
  static var mock: LibrarySong {
    .mockWith()
  }

  static func mockWith(
    id: String = "mock-song-id",
    title: String = "Like a Rolling Stone",
    artist: String = "Bob Dylan",
    album: String? = "Highway 61 Revisited",
    imageUrl: URL? = URL(string: "https://i.scdn.co/image/test"),
    durationMS: Int = 369600,
    spotifyId: String? = "3AhXZa8sUQht0UEdBJgpGc"
  ) -> LibrarySong {
    LibrarySong(
      id: id,
      title: title,
      artist: artist,
      album: album,
      imageUrl: imageUrl,
      durationMS: durationMS,
      spotifyId: spotifyId
    )
  }

  static var mockSongs: [LibrarySong] {
    [
      .mockWith(
        id: "song-1",
        title: "Bohemian Rhapsody",
        artist: "Queen",
        album: "A Night at the Opera",
        durationMS: 354000,
        spotifyId: "spotify-1"
      ),
      .mockWith(
        id: "song-2",
        title: "Hotel California",
        artist: "Eagles",
        album: "Hotel California",
        durationMS: 390000,
        spotifyId: "spotify-2"
      ),
      .mockWith(
        id: "song-3",
        title: "Stairway to Heaven",
        artist: "Led Zeppelin",
        album: "Led Zeppelin IV",
        durationMS: 482000,
        spotifyId: "spotify-3"
      ),
    ]
  }
}
