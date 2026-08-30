//
//  ListenerAnalytics.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/29/26.
//

import Foundation

/// Response for `GET /v1/stations/:stationId/listening-sessions/active`. Only the summary is
/// decoded — the headline for each Listeners card is `summary.uniqueUsers`, which the server
/// computes over all matching rows regardless of pagination. The other summary fields aren't used
/// by the dashboard, so they're optional: server schema drift on them must not fail the whole card.
struct ActiveListeningSessionsResponse: Decodable, Equatable, Sendable {
  struct Summary: Decodable, Equatable, Sendable {
    var totalSessions: Int?
    let uniqueUsers: Int
    var uniqueDevices: Int?
    var anonymousSessions: Int?
  }

  let summary: Summary
}

/// Response for `GET /v1/stations/:stationId/listener-counts`. Buckets are server-owned
/// (Sunday-anchored, America/Chicago, DST-safe, release-clamped); render `bucketStart` as given
/// and flag `isLive` as the "SO FAR" bar. Only `bucketStart`, `uniqueUsers`, and `isLive` drive the
/// chart, so the rest is optional and `isLive` defaults to `false` — a bucket that omits it renders
/// as an ordinary (non-"SO FAR") bar rather than emptying the whole chart.
struct ListenerCountsResponse: Decodable, Equatable, Sendable {
  struct Bucket: Equatable, Sendable, Identifiable {
    var id: String { bucketStart }
    let bucketStart: String
    let uniqueUsers: Int
    var uniqueDevices: Int?
    var totalSessions: Int?
    var isLive: Bool = false
  }

  var granularity: String?
  var startDate: String?
  var endDate: String?
  var timezone: String?
  let buckets: [Bucket]
}

extension ListenerCountsResponse.Bucket: Decodable {
  private enum CodingKeys: String, CodingKey {
    case bucketStart, uniqueUsers, uniqueDevices, totalSessions, isLive
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    bucketStart = try container.decode(String.self, forKey: .bucketStart)
    uniqueUsers = try container.decode(Int.self, forKey: .uniqueUsers)
    uniqueDevices = try container.decodeIfPresent(Int.self, forKey: .uniqueDevices)
    totalSessions = try container.decodeIfPresent(Int.self, forKey: .totalSessions)
    isLive = try container.decodeIfPresent(Bool.self, forKey: .isLive) ?? false
  }
}
