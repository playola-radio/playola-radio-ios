//
//  ProgrammingHealthTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 9/12/26.
//

import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ProgrammingHealthTests {
  private func decode(_ json: String) throws -> ProgrammingHealth {
    try JSONDecoder().decode(ProgrammingHealth.self, from: Data(json.utf8))
  }

  @Test func decodesDocumentedPayload() throws {
    let health = try decode(
      """
      {
        "stationId": "station-1",
        "status": "healthy",
        "freshPct": 85,
        "daysAhead": { "value": 12.4, "limitingBank": "songs" },
        "checks": [
          { "kind": "appearances", "status": "healthy",
            "progress": { "current": 3, "required": 2 },
            "window": { "start": "2026-09-01T00:00:00Z", "end": "2026-09-08T00:00:00Z" } },
          { "kind": "songCategoryFreshness", "status": "warning",
            "progress": { "current": 4, "required": 5 } },
          { "kind": "breakerCategoryFreshness", "status": "healthy",
            "progress": { "current": 3, "required": 3 } },
          { "kind": "pendingListenerQuestions", "status": "healthy",
            "progress": { "current": 0, "required": 0 } }
        ],
        "categories": [
          { "categoryId": "cat-1", "name": "Alt Rock", "audioBlockType": "song",
            "status": "warning", "activeCount": 30 }
        ]
      }
      """)

    expectNoDifference(health.stationId, "station-1")
    expectNoDifference(health.status, .healthy)
    expectNoDifference(health.freshPct, 85)
    expectNoDifference(
      health.checks.map(\.kind),
      [
        "appearances", "songCategoryFreshness", "breakerCategoryFreshness",
        "pendingListenerQuestions",
      ])
    expectNoDifference(
      health.checks.first?.progress, ProgrammingHealthCheckProgress(current: 3, required: 2))
  }

  @Test func decodesNullFreshPctAsUnmeasurable() throws {
    let health = try decode(
      """
      { "stationId": "station-1", "status": "unknown", "freshPct": null, "checks": [] }
      """)

    expectNoDifference(health.freshPct, nil)
    expectNoDifference(health.status, .unknown)
    expectNoDifference(health.checks.isEmpty, true)
  }

  @Test func decodesUnrecognizedStatusToUnknownFallback() throws {
    let health = try decode(
      """
      { "stationId": "station-1", "status": "brand_new_status", "freshPct": 50, "checks": [] }
      """)

    expectNoDifference(health.status, .unknown)
  }

  @Test func decodesUnrecognizedCheckKindAndStatusVerbatim() throws {
    let health = try decode(
      """
      {
        "stationId": "station-1", "status": "healthy", "freshPct": 90,
        "checks": [
          { "kind": "brandNewCheckKind", "status": "brand_new_status",
            "progress": { "current": 1, "required": 2 } }
        ]
      }
      """)

    expectNoDifference(health.checks.first?.kind, "brandNewCheckKind")
    expectNoDifference(health.checks.first?.status, .unknown)
  }

  @Test func decodesCheckWithoutProgress() throws {
    let health = try decode(
      """
      {
        "stationId": "station-1", "status": "healthy", "freshPct": 90,
        "checks": [ { "kind": "appearances", "status": "healthy" } ]
      }
      """)

    expectNoDifference(health.checks.first?.progress, nil)
  }
}
