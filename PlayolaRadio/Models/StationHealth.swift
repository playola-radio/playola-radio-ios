//
//  StationHealth.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/29/26.
//

import Foundation

/// A station's health score plus the server-owned "improve your station" task list, from
/// `GET /v1/stations/:stationId/health-score`.
///
/// The server owns all display copy — task `label`s and fully-composed, pluralized progress
/// strings (`progress.label`). The client renders them verbatim and never assembles its own
/// vocabulary per factor, so new factors can appear without a client change.
struct StationHealth: Codable, Equatable, Sendable {
  /// Overall score 0–100, or `nil` when no factor applies (pairs with `.unavailable`). Render a
  /// neutral/empty state for `nil` — never fall back to `0`.
  let score: Int?
  let band: StationHealthBand
  let factors: [StationHealthFactor]
  let tasks: [StationHealthTask]

  /// Tasks in server-defined display order (`priority` ascending).
  var sortedTasks: [StationHealthTask] {
    tasks.sorted { $0.priority < $1.priority }
  }

  /// The `X` in "X of Y done": tasks whose progress has reached completion. A task with no
  /// progress is not counted as done.
  var completedTaskCount: Int {
    tasks.filter { $0.progress?.isComplete ?? false }.count
  }
}

/// Coarse health band driving the ring color and status copy. Decodes unknown server values to
/// `.unknown` so a new band never crashes decoding or silently hides the section.
enum StationHealthBand: String, Codable, Sendable {
  case good
  case fair
  case attention
  case unavailable
  case unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = StationHealthBand(rawValue: raw) ?? .unknown
  }
}

/// One weighted input to the overall score. Modeled as an array so more factors (library depth,
/// voicetracks, …) appear without a contract change. `score` is `nil` when `applicable` is false.
struct StationHealthFactor: Codable, Equatable, Sendable {
  let key: String
  let label: String
  let weight: Int
  let applicable: Bool
  let score: Double?
}

/// A single "improve your station" task card. `progress` is optional; when absent the task has no
/// subtitle or bar.
struct StationHealthTask: Codable, Equatable, Sendable, Identifiable {
  let key: String
  let label: String
  let priority: Int
  let factorKey: String
  let progress: StationHealthTaskProgress?

  var id: String { key }
}

/// Task progress. `label` is a fully-composed, pluralized string owned by the server — render it
/// verbatim, never rebuild it from `current`/`total`.
struct StationHealthTaskProgress: Codable, Equatable, Sendable {
  let current: Int
  let total: Int
  let label: String

  /// A task is complete when `current == total` (per the server contract). Completed tasks stay
  /// in the list, shown checked.
  var isComplete: Bool { current >= total }

  /// A `0...1` fill for the progress bar, guarded against a zero total.
  var fraction: Double {
    guard total > 0 else { return isComplete ? 1 : 0 }
    return min(1, max(0, Double(current) / Double(total)))
  }
}
