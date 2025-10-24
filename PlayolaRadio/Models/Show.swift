//
//  Show.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/8/25.
//

import Foundation
import PlayolaPlayer

/// Represents a fade instruction in a show segment
struct Fade: Codable, Equatable {
  let atMS: Int
  let toVolume: Double
}

/// Represents a segment within a show
struct ShowSegment: Codable, Equatable, Identifiable {
  let id: String
  let showId: String
  let audioBlockId: String
  let offsetMS: Int
  let startingVolume: Double
  let fades: [Fade]
  let position: Int
  let createdAt: Date
  let updatedAt: Date
  let audioBlock: AudioBlock?
}

/// Represents a radio show with optional segments
struct Show: Codable, Equatable, Identifiable {
  let id: String
  let stationId: String
  let title: String
  let durationMS: Int
  let createdAt: Date
  let updatedAt: Date
  let segments: [ShowSegment]?
}

extension Show {
  static let mock: Show = .init(
    id: "theId", stationId: "theStationId", title: "On The Road with Stelly",
    durationMS: 1000 * 60 * 30, createdAt: Date(), updatedAt: Date(), segments: [])
}
