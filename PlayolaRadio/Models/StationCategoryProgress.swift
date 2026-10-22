//
//  StationCategoryProgress.swift
//  PlayolaRadio
//

import Foundation

/// Draft category progress for a station in setup, from
/// `GET /v1/stations/:stationId/station-categories?version=draft`.
struct StationCategoryProgressResponse: Codable, Equatable, Sendable {
  let usesCategoryProgress: Bool
  let readiness: Double?
  let categories: [StationCategoryProgress]
}

/// One category's fill progress toward its minimum audio-block count. Categories arrive from the
/// server sorted by `sortOrder` ascending.
struct StationCategoryProgress: Codable, Equatable, Sendable, Identifiable {
  let id: String
  let name: String
  let audioBlockType: AudioBlockCategoryType
  let minimumCount: Int
  let burnoutCount: Int?
  let audioBlockCount: Int
  let sortOrder: Int
}
