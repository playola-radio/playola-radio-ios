//
//  Preset.swift
//  PlayolaRadio
//

import Foundation

struct Preset: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let userId: String
  let stationId: String?
  let urlStationId: String?
  var position: Int
  let createdAt: Date
  let updatedAt: Date
  let station: PresetStation?
  let urlStation: PresetUrlStation?

  /// Whichever of stationId / urlStationId is non-nil. Empty string if neither is set
  /// (should never happen for a server-returned preset).
  var embeddedStationId: String {
    stationId ?? urlStationId ?? ""
  }
}

struct PresetStation: Codable, Equatable, Sendable {
  let id: String
  let name: String
  let imageUrl: String?
}

struct PresetUrlStation: Codable, Equatable, Sendable {
  let id: String
  let name: String
  let url: String?
  let imageUrl: String?
}

// MARK: - Test helpers

extension Preset {
  static func mockPlayola(
    id: String = "preset-1",
    userId: String = "user-1",
    stationId: String = "playola-station-1",
    position: Int = 0,
    stationName: String = "Mock Playola Station",
    stationImageUrl: String? = "https://example.com/playola.jpg"
  ) -> Preset {
    Preset(
      id: id,
      userId: userId,
      stationId: stationId,
      urlStationId: nil,
      position: position,
      createdAt: Date(timeIntervalSince1970: 1_758_915_200),
      updatedAt: Date(timeIntervalSince1970: 1_758_915_200),
      station: PresetStation(
        id: stationId,
        name: stationName,
        imageUrl: stationImageUrl
      ),
      urlStation: nil
    )
  }

  static func mockUrl(
    id: String = "preset-2",
    userId: String = "user-1",
    urlStationId: String = "url-station-1",
    position: Int = 0,
    stationName: String = "Mock URL Station",
    stationUrl: String = "https://example.com/stream.aac",
    stationImageUrl: String? = "https://example.com/url.jpg"
  ) -> Preset {
    Preset(
      id: id,
      userId: userId,
      stationId: nil,
      urlStationId: urlStationId,
      position: position,
      createdAt: Date(timeIntervalSince1970: 1_758_915_200),
      updatedAt: Date(timeIntervalSince1970: 1_758_915_200),
      station: nil,
      urlStation: PresetUrlStation(
        id: urlStationId,
        name: stationName,
        url: stationUrl,
        imageUrl: stationImageUrl
      )
    )
  }
}
