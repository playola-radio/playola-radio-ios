//
//  ProgrammingHealth.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 9/12/26.
//

import Foundation

/// A station's programming health, from `GET /v1/stations/:stationId/programming-health`.
/// Computed from the published (live) station version only.
///
/// `freshPct` is the server-owned, weighted freshness composite (0-100, rounded) that drives the
/// health ring directly. `status` is derived from `freshPct` on the server, so the two never
/// contradict each other. Only the fields the dashboard renders are decoded here — tolerant
/// decoding means `daysAhead`/`categories` can be added later without a contract change.
struct ProgrammingHealth: Codable, Equatable, Sendable {
  let stationId: String
  let status: ProgrammingHealthStatus
  /// Weighted freshness composite, 0-100, or `nil` when unmeasurable. Render a neutral/empty
  /// ring for `nil` — never fall back to `0`.
  let freshPct: Int?
  let checks: [ProgrammingHealthCheck]
}

/// Coarse health status driving the ring color and status copy. Decodes unknown server values to
/// `.unknown` so a new status never crashes decoding or silently hides the section.
enum ProgrammingHealthStatus: String, Codable, Sendable {
  case healthy
  case warning
  case unhealthy
  case unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = ProgrammingHealthStatus(rawValue: raw) ?? .unknown
  }
}

/// One "improve your station" check. `kind` is kept as a raw server string (not an enum) so new
/// kinds pass through decoding untouched; the client only renders the kinds it recognizes.
/// `window` is intentionally not decoded — the client's copy for each kind is timeless.
struct ProgrammingHealthCheck: Codable, Equatable, Sendable {
  let kind: String
  let status: ProgrammingHealthStatus
  let progress: ProgrammingHealthCheckProgress?
}

struct ProgrammingHealthCheckProgress: Codable, Equatable, Sendable {
  let current: Int
  let required: Int
}
