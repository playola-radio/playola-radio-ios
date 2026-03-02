//
//  SongRequest.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import Foundation

enum SongRequestStatus: Equatable {
  case unrequested
  case requested(Date)

  var isRequested: Bool {
    if case .requested = self { return true }
    return false
  }

  var requestedDate: Date? {
    if case .requested(let date) = self { return date }
    return nil
  }

  var displayText: String? {
    guard case .requested(let date) = self else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d"
    return "Requested \(formatter.string(from: date))"
  }
}

struct SongRequest: Codable, Identifiable, Equatable {
  let requestId: String?
  let title: String
  let artist: String
  let album: String
  let durationMS: Int
  let popularity: Int?
  let releaseDate: String
  let isrc: String?
  let appleId: String
  let spotifyId: String?
  let imageUrl: URL?
  let createdAt: Date?

  var id: String { appleId }

  var requestStatus: SongRequestStatus {
    if requestId != nil, let date = createdAt {
      return .requested(date)
    }
    return .unrequested
  }

  enum CodingKeys: String, CodingKey {
    case requestId = "id"
    case title
    case artist
    case album
    case durationMS
    case popularity
    case releaseDate
    case isrc
    case appleId
    case spotifyId
    case imageUrl
    case createdAt
  }
}

// MARK: - Mock

extension SongRequest {
  static func mockWith(
    requestId: String? = nil,
    title: String = "Like a Rolling Stone",
    artist: String = "Bob Dylan",
    album: String = "Highway 61 Revisited",
    durationMS: Int = 369600,
    popularity: Int? = 78,
    releaseDate: String = "1965-08-30",
    isrc: String? = "USSM16500213",
    appleId: String = "1440806768",
    spotifyId: String? = "3AhXZa8sUQht0UEdBJgpGc",
    imageUrl: URL? = URL(string: "https://i.scdn.co/image/test"),
    createdAt: Date? = nil
  ) -> SongRequest {
    SongRequest(
      requestId: requestId,
      title: title,
      artist: artist,
      album: album,
      durationMS: durationMS,
      popularity: popularity,
      releaseDate: releaseDate,
      isrc: isrc,
      appleId: appleId,
      spotifyId: spotifyId,
      imageUrl: imageUrl,
      createdAt: createdAt
    )
  }
}
