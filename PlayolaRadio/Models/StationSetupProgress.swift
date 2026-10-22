//
//  StationSetupProgress.swift
//  PlayolaRadio
//

import Foundation

/// A station's overall setup-completion progress, from
/// `GET /v1/stations/:stationId/setup-progress`.
struct StationSetupProgress: Codable, Equatable, Sendable {
  let stationId: String
  let progress: Double
  let displayPercentage: Int
  let factors: Factors

  struct Factors: Codable, Equatable, Sendable {
    let sourceTapes: Factor
    let welcome: Factor
    let songs: Factor
    let breakers: Factor
  }

  struct Factor: Codable, Equatable, Sendable {
    let current: Int
    let required: Int
    let progress: Double
    let weight: Double
  }
}
