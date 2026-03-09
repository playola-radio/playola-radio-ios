//
//  StationLibraryRequest.swift
//  PlayolaRadio
//

import Foundation

enum StationLibraryRequestType: String, Codable, Equatable {
  case add
  case remove
}

enum StationLibraryRequestStatus: String, Codable, Equatable {
  case pending
  case completed
  case dismissed
}

struct StationLibraryRequest: Codable, Identifiable, Equatable {
  let id: String
  let stationId: String
  let userId: String
  let type: StationLibraryRequestType
  let status: StationLibraryRequestStatus
  let audioBlockId: String?
  let spotifyId: String?
  let title: String
  let artist: String
  let album: String?
  let imageUrl: URL?
  let requestedAt: Date
  let completedAt: Date?
  let dismissedAt: Date?
  let createdAt: Date
  let updatedAt: Date
}

// MARK: - Request Bodies

struct CreateAddLibraryRequestBody: Encodable {
  let appleId: String
  let title: String
  let artist: String
  let album: String?
  let imageUrl: String?
}

struct CreateRemoveLibraryRequestBody: Encodable {
  let audioBlockId: String
}

// MARK: - Mock

extension StationLibraryRequest {
  static var mock: StationLibraryRequest {
    .mockWith()
  }

  static func mockWith(
    id: String = "mock-request-id",
    stationId: String = "mock-station-id",
    userId: String = "mock-user-id",
    type: StationLibraryRequestType = .add,
    status: StationLibraryRequestStatus = .pending,
    audioBlockId: String? = nil,
    spotifyId: String? = "mock-spotify-id",
    title: String = "New Song",
    artist: String = "New Artist",
    album: String? = "New Album",
    imageUrl: URL? = URL(string: "https://i.scdn.co/image/test"),
    requestedAt: Date = Date(),
    completedAt: Date? = nil,
    dismissedAt: Date? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> StationLibraryRequest {
    StationLibraryRequest(
      id: id,
      stationId: stationId,
      userId: userId,
      type: type,
      status: status,
      audioBlockId: audioBlockId,
      spotifyId: spotifyId,
      title: title,
      artist: artist,
      album: album,
      imageUrl: imageUrl,
      requestedAt: requestedAt,
      completedAt: completedAt,
      dismissedAt: dismissedAt,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  static var mockRequests: [StationLibraryRequest] {
    let now = Date()

    return [
      .mockWith(
        id: "request-1",
        type: .add,
        status: .pending,
        spotifyId: "spotify-new-1",
        title: "Watermelon Sugar",
        artist: "Harry Styles",
        album: "Fine Line",
        requestedAt: now.addingTimeInterval(-3600)
      ),
      .mockWith(
        id: "request-2",
        type: .remove,
        status: .pending,
        audioBlockId: "song-to-remove",
        spotifyId: nil,
        title: "Old Song",
        artist: "Old Artist",
        album: nil,
        requestedAt: now.addingTimeInterval(-7200)
      ),
      .mockWith(
        id: "request-3",
        type: .add,
        status: .completed,
        spotifyId: "spotify-completed",
        title: "Completed Song",
        artist: "Completed Artist",
        requestedAt: now.addingTimeInterval(-86400),
        completedAt: now.addingTimeInterval(-43200)
      ),
    ]
  }
}
