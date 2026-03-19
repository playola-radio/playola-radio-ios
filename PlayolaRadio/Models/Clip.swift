//
//  Clip.swift
//  PlayolaRadio
//

import Foundation

enum ClipStatus: String, Codable, Equatable, Sendable {
  case pending
  case processing
  case completed
  case failed
}

struct ClipTrack: Codable, Equatable, Sendable {
  let title: String
  let artist: String
  let type: String
  let startsAtMS: Int
  let durationMS: Int
  let listenerQuestionAiringId: String?
}

struct Clip: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let stationId: String
  let userId: String
  let startTime: Date
  let endTime: Date
  let status: ClipStatus
  let url: String?
  let errorMessage: String?
  let tracks: [ClipTrack]?
  let durationMS: Int?
  let firstSpinId: String?
  let lastSpinId: String?
  let prerollMS: Int?
  let postrollMS: Int?
  let createdAt: Date?
  let updatedAt: Date?
}

struct SpinSummary: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let artist: String
  let type: String
  let airtime: Date
  let durationMS: Int
}

struct AiringSpinsResponse: Codable, Equatable, Sendable {
  let airingSpins: [SpinSummary]
  let contextSpins: [SpinSummary]
}

// MARK: - Mock

extension Clip {
  static var mock: Clip {
    .mockWith()
  }

  static func mockWith(
    id: String = "mock-clip-id",
    stationId: String = "mock-station-id",
    userId: String = "mock-user-id",
    startTime: Date = Date().addingTimeInterval(-300),
    endTime: Date = Date(),
    status: ClipStatus = .completed,
    url: String? = "https://example.com/clip.m4a",
    errorMessage: String? = nil,
    tracks: [ClipTrack]? = [
      ClipTrack(
        title: "Test Song",
        artist: "Test Artist",
        type: "song",
        startsAtMS: 0,
        durationMS: 180_000,
        listenerQuestionAiringId: nil
      )
    ],
    durationMS: Int? = 300_000,
    firstSpinId: String? = "mock-first-spin-id",
    lastSpinId: String? = "mock-last-spin-id",
    prerollMS: Int? = 0,
    postrollMS: Int? = 0,
    createdAt: Date? = Date(),
    updatedAt: Date? = Date()
  ) -> Clip {
    Clip(
      id: id,
      stationId: stationId,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      status: status,
      url: url,
      errorMessage: errorMessage,
      tracks: tracks,
      durationMS: durationMS,
      firstSpinId: firstSpinId,
      lastSpinId: lastSpinId,
      prerollMS: prerollMS,
      postrollMS: postrollMS,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
