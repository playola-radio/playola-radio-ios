//
//  StationHealthTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/29/26.
//

import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct StationHealthTests {
  private func decode(_ json: String) throws -> StationHealth {
    try JSONDecoder().decode(StationHealth.self, from: Data(json.utf8))
  }

  @Test func decodesFullPayload() throws {
    let health = try decode(
      """
      {
        "score": 42,
        "band": "attention",
        "factors": [
          { "key": "appearances", "label": "Appearances", "weight": 100,
            "applicable": true, "score": 0.42 }
        ],
        "tasks": [
          { "key": "answer", "label": "Answer questions", "priority": 10,
            "factorKey": "appearances",
            "progress": { "current": 11, "total": 12,
                          "label": "11 of 12 questions answered" } }
        ]
      }
      """)

    #expect(health.score == 42)
    #expect(health.band == .attention)
    #expect(health.factors.count == 1)
    #expect(health.factors.first?.score == 0.42)
    #expect(health.tasks.count == 1)
    #expect(health.tasks.first?.progress?.label == "11 of 12 questions answered")
  }

  @Test func decodesNullScoreWithUnavailableBand() throws {
    let health = try decode(
      """
      { "score": null, "band": "unavailable", "factors": [], "tasks": [] }
      """)

    #expect(health.score == nil)
    #expect(health.band == .unavailable)
    #expect(health.factors.isEmpty)
    #expect(health.tasks.isEmpty)
  }

  @Test func decodesUnknownBandToFallback() throws {
    let health = try decode(
      """
      { "score": 50, "band": "brand_new_band", "factors": [], "tasks": [] }
      """)

    #expect(health.band == .unknown)
  }

  @Test func decodesTaskWithoutProgress() throws {
    let health = try decode(
      """
      {
        "score": 50, "band": "fair", "factors": [],
        "tasks": [
          { "key": "setup", "label": "Set up", "priority": 5, "factorKey": "appearances" }
        ]
      }
      """)

    #expect(health.tasks.first?.progress == nil)
  }

  @Test func decodesNullFactorScore() throws {
    let health = try decode(
      """
      {
        "score": null, "band": "unavailable",
        "factors": [
          { "key": "appearances", "label": "Appearances", "weight": 100,
            "applicable": false, "score": null }
        ],
        "tasks": []
      }
      """)

    #expect(health.factors.first?.applicable == false)
    #expect(health.factors.first?.score == nil)
  }

  @Test func sortedTasksOrdersByPriorityAscending() throws {
    let health = try decode(
      """
      {
        "score": 50, "band": "fair", "factors": [],
        "tasks": [
          { "key": "c", "label": "C", "priority": 30, "factorKey": "appearances" },
          { "key": "a", "label": "A", "priority": 10, "factorKey": "appearances" },
          { "key": "b", "label": "B", "priority": 20, "factorKey": "appearances" }
        ]
      }
      """)

    #expect(health.sortedTasks.map(\.key) == ["a", "b", "c"])
  }

  @Test func completedTaskCountCountsOnlyCompletedProgress() throws {
    let health = try decode(
      """
      {
        "score": 50, "band": "fair", "factors": [],
        "tasks": [
          { "key": "done", "label": "Done", "priority": 10, "factorKey": "appearances",
            "progress": { "current": 3, "total": 3, "label": "3 of 3" } },
          { "key": "partial", "label": "Partial", "priority": 20, "factorKey": "appearances",
            "progress": { "current": 1, "total": 4, "label": "1 of 4" } },
          { "key": "none", "label": "None", "priority": 30, "factorKey": "appearances" }
        ]
      }
      """)

    #expect(health.completedTaskCount == 1)
  }

  @Test func progressIsCompleteWhenCurrentReachesTotal() {
    let complete = StationHealthTaskProgress(current: 5, total: 5, label: "5 of 5")
    let incomplete = StationHealthTaskProgress(current: 2, total: 5, label: "2 of 5")

    #expect(complete.isComplete)
    #expect(!incomplete.isComplete)
  }

  @Test func progressFractionIsClampedAndGuardsZeroTotal() {
    #expect(StationHealthTaskProgress(current: 1, total: 4, label: "").fraction == 0.25)
    #expect(StationHealthTaskProgress(current: 9, total: 4, label: "").fraction == 1)
    #expect(StationHealthTaskProgress(current: 0, total: 0, label: "").fraction == 1)
  }
}
