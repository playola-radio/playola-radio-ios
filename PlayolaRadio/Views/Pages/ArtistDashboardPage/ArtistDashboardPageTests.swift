//
//  ArtistDashboardPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import CustomDump
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ArtistDashboardPageTests {
  @Test func displaysPlaceholderHealthScore() {
    let model = ArtistDashboardPageModel()

    expectNoDifference(model.navigationTitle, "Dashboard")
    expectNoDifference(model.healthScoreLabel, "92")
    expectNoDifference(model.healthStatusLabel, "In good shape")
    expectNoDifference(
      model.healthWeakestLabel, "Weakest: intro coverage · 12 songs missing intros")
    #expect(model.healthRingProgress > 0 && model.healthRingProgress <= 1)
  }

  @Test func displaysPlaceholderStats() {
    let model = ArtistDashboardPageModel()

    expectNoDifference(model.stats.map(\.value), ["23", "11h 20m", "6"])
    expectNoDifference(
      model.stats.map(\.label), ["LISTENERS NOW", "LISTENER HOURS", "NEW THIS WEEK"])
  }

  @Test func displaysPlaceholderReportRow() {
    let model = ArtistDashboardPageModel()

    expectNoDifference(model.reportRowTitle, "This week")
    expectNoDifference(model.reportTrendLabel, "↑ 12%")
  }
}
