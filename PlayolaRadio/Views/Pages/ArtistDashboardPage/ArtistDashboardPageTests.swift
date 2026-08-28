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
  @Test func displaysPlaceholderHeader() {
    let model = ArtistDashboardPageModel()

    expectNoDifference(model.navigationTitle, "Dashboard")
    expectNoDifference(model.weeklyReportLabel, "Weekly report")
    expectNoDifference(model.weeklyReportTrendLabel, "↑ 12%")
  }

  @Test func displaysPlaceholderHealthScore() {
    let model = ArtistDashboardPageModel()

    expectNoDifference(model.healthSectionTitle, "STATION HEALTH")
    expectNoDifference(model.healthScoreLabel, "92")
    expectNoDifference(model.healthStatusLabel, "Your station is in good shape")
    #expect(model.healthRingProgress > 0 && model.healthRingProgress <= 1)
  }

  @Test func displaysPlaceholderListenerStats() {
    let model = ArtistDashboardPageModel()

    expectNoDifference(model.listenersSectionTitle, "LISTENERS")
    expectNoDifference(model.stats.map(\.value), ["23", "184", "721"])
    expectNoDifference(model.stats.map(\.label), ["NOW", "THIS WEEK", "THIS MONTH"])
  }

  @Test func displaysPlaceholderWeeklyChart() {
    let model = ArtistDashboardPageModel()

    expectNoDifference(model.chartSectionTitle, "LAST 6 WEEKS")
    expectNoDifference(model.chartLinkLabel, "Stats ›")
    expectNoDifference(
      model.weekBars.map(\.label), ["7/20", "7/27", "8/3", "8/10", "8/17", "SO FAR"])
    #expect(model.weekBars.allSatisfy { $0.heightFraction > 0 && $0.heightFraction <= 1 })
  }

  @Test func displaysPlaceholderImprovementItems() {
    let model = ArtistDashboardPageModel()

    expectNoDifference(model.improveSectionTitle, "IMPROVE YOUR STATION")
    expectNoDifference(model.improveCountLabel, "1 OF 5 DONE")
    expectNoDifference(
      model.improvementItems.map(\.title),
      [
        "Record 12 missing intros",
        "Approve a song request",
        "AMA show Saturday",
        "Add 8 songs to your library",
        "Answer Sarah's question",
      ])
    expectNoDifference(
      model.improvementItems.map(\.subtitle),
      [
        "4 of 12 intros recorded",
        "0 of 1 request reviewed",
        "2 of 3 setup steps ready",
        "3 of 8 songs added",
        "1 of 1 complete · just now",
      ])
    #expect(model.improvementItems.allSatisfy { $0.progress >= 0 && $0.progress <= 1 })
  }
}
