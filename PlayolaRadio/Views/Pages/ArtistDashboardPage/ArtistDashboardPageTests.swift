//
//  ArtistDashboardPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Sharing
import SwiftUI
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ArtistDashboardPageTests {

  // MARK: - Test Helpers

  private let testStationId = "station-abc"

  private func makeHealth(
    score: Int?,
    band: StationHealthBand,
    tasks: [StationHealthTask] = []
  ) -> StationHealth {
    StationHealth(
      score: score,
      band: band,
      factors: [
        StationHealthFactor(
          key: "appearances", label: "Appearances", weight: 100, applicable: true, score: 0.4)
      ],
      tasks: tasks)
  }

  private func makeTask(
    key: String,
    label: String,
    priority: Int,
    factorKey: String = "appearances",
    current: Int?,
    total: Int?,
    progressLabel: String? = nil
  ) -> StationHealthTask {
    var progress: StationHealthTaskProgress?
    if let current, let total {
      progress = StationHealthTaskProgress(
        current: current, total: total, label: progressLabel ?? "\(current) of \(total)")
    }
    return StationHealthTask(
      key: key, label: label, priority: priority, factorKey: factorKey, progress: progress)
  }

  private func makeModel(
    returning health: StationHealth,
    capturingStationId captured: LockIsolated<String?>? = nil
  ) async -> ArtistDashboardPageModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    return await withDependencies {
      $0.api.getStationHealthScore = { _, stationId in
        captured?.setValue(stationId)
        return health
      }
    } operation: {
      let model = ArtistDashboardPageModel()
      await model.viewAppeared()
      return model
    }
  }

  // MARK: - Static Placeholder Content

  @Test func displaysStaticHeaderAndPlaceholders() {
    let model = ArtistDashboardPageModel()

    expectNoDifference(model.navigationTitle, "Dashboard")
    expectNoDifference(model.weeklyReportLabel, "Weekly report")
    expectNoDifference(model.healthSectionTitle, "STATION HEALTH")
    expectNoDifference(model.listenersSectionTitle, "LISTENERS")
    expectNoDifference(model.stats.map(\.value), ["23", "184", "721"])
    expectNoDifference(
      model.weekBars.map(\.label), ["7/20", "7/27", "8/3", "8/10", "8/17", "SO FAR"])
    expectNoDifference(model.improveSectionTitle, "IMPROVE YOUR STATION")
  }

  // MARK: - Health Ring

  @Test func healthScoreAndRingReflectServerScore() async {
    let model = await makeModel(returning: makeHealth(score: 92, band: .good))

    expectNoDifference(model.healthScoreLabel, "92")
    expectNoDifference(model.healthRingProgress, 0.92)
    expectNoDifference(model.healthRingColor, Color(hex: "#34C759"))
    expectNoDifference(model.healthStatusLabel, "Your station is in good shape")
  }

  @Test func fairBandUsesAmberRingAndCopy() async {
    let model = await makeModel(returning: makeHealth(score: 60, band: .fair))

    expectNoDifference(model.healthRingColor, Color(hex: "#FFC107"))
    expectNoDifference(model.healthStatusLabel, "Your station could use a little attention")
  }

  @Test func attentionBandUsesRedRingAndCopy() async {
    let model = await makeModel(returning: makeHealth(score: 30, band: .attention))

    expectNoDifference(model.healthRingColor, .playolaRed)
    expectNoDifference(model.healthStatusLabel, "Your station needs some attention")
  }

  @Test func nullScoreRendersNeutralEmptyState() async {
    let model = await makeModel(returning: makeHealth(score: nil, band: .unavailable))

    expectNoDifference(model.healthScoreLabel, "—")
    expectNoDifference(model.healthRingProgress, 0)
    expectNoDifference(model.healthRingColor, Color(hex: "#999999"))
    expectNoDifference(model.healthStatusLabel, "Station health isn't available yet")
  }

  @Test func unknownBandFallsBackToNeutral() async {
    let model = await makeModel(returning: makeHealth(score: nil, band: .unknown))

    expectNoDifference(model.healthRingColor, Color(hex: "#999999"))
    expectNoDifference(model.healthStatusLabel, "Station health isn't available yet")
  }

  // MARK: - Improve Your Station

  @Test func improvementItemsSortByPriorityAscending() async {
    let health = makeHealth(
      score: 50,
      band: .fair,
      tasks: [
        makeTask(key: "c", label: "Third", priority: 30, current: 0, total: 2),
        makeTask(key: "a", label: "First", priority: 10, current: 0, total: 2),
        makeTask(key: "b", label: "Second", priority: 20, current: 0, total: 2),
      ])
    let model = await makeModel(returning: health)

    expectNoDifference(model.improvementItems.map(\.title), ["First", "Second", "Third"])
  }

  @Test func improveCountCountsCompletedTasks() async {
    let health = makeHealth(
      score: 50,
      band: .fair,
      tasks: [
        makeTask(key: "done", label: "Done", priority: 10, current: 3, total: 3),
        makeTask(key: "partial", label: "Partial", priority: 20, current: 1, total: 4),
        makeTask(key: "no-progress", label: "No progress", priority: 30, current: nil, total: nil),
      ])
    let model = await makeModel(returning: health)

    expectNoDifference(model.improveCountLabel, "1 OF 3 DONE")
  }

  @Test func incompleteItemUsesServerSubtitleAndFractionalProgress() async {
    let health = makeHealth(
      score: 50,
      band: .fair,
      tasks: [
        makeTask(
          key: "intros", label: "Record intros", priority: 10, current: 4, total: 12,
          progressLabel: "4 of 12 intros recorded")
      ])
    let model = await makeModel(returning: health)

    let item = model.improvementItems.first
    expectNoDifference(item?.title, "Record intros")
    expectNoDifference(item?.subtitle, "4 of 12 intros recorded")
    expectNoDifference(item?.progress, 4.0 / 12.0)
    expectNoDifference(item?.titleColor, .white)
    expectNoDifference(item?.progressColor, .playolaRed)
  }

  @Test func completedItemUsesCheckedStyling() async {
    let health = makeHealth(
      score: 90,
      band: .good,
      tasks: [
        makeTask(
          key: "answered", label: "Answer questions", priority: 10, current: 12, total: 12,
          progressLabel: "12 of 12 questions answered")
      ])
    let model = await makeModel(returning: health)

    let item = model.improvementItems.first
    expectNoDifference(item?.icon, "checkmark")
    expectNoDifference(item?.progress, 1)
    expectNoDifference(item?.titleColor, Color(hex: "#999999"))
    expectNoDifference(item?.subtitleColor, Color(hex: "#34C759"))
    expectNoDifference(item?.progressColor, Color(hex: "#34C759"))
  }

  @Test func taskWithoutProgressHasEmptySubtitleAndNoFill() async {
    let health = makeHealth(
      score: 50,
      band: .fair,
      tasks: [makeTask(key: "x", label: "Setup", priority: 10, current: nil, total: nil)])
    let model = await makeModel(returning: health)

    let item = model.improvementItems.first
    expectNoDifference(item?.subtitle, "")
    expectNoDifference(item?.progress, 0)
    expectNoDifference(item?.progressTrackColor, .clear)
  }

  @Test func taskWithProgressShowsVisibleTrack() async {
    let health = makeHealth(
      score: 50,
      band: .fair,
      tasks: [makeTask(key: "x", label: "Do it", priority: 10, current: 1, total: 4)])
    let model = await makeModel(returning: health)

    expectNoDifference(model.improvementItems.first?.progressTrackColor, Color(hex: "#5E5F5F"))
  }

  @Test func ringProgressClampsOutOfRangeScore() async {
    let model = await makeModel(returning: makeHealth(score: 140, band: .good))

    expectNoDifference(model.healthRingProgress, 1)
  }

  // MARK: - Loading Behavior

  @Test func viewAppearedRequestsBroadcastingStationId() async {
    let captured = LockIsolated<String?>(nil)
    _ = await makeModel(
      returning: makeHealth(score: 80, band: .good), capturingStationId: captured)

    expectNoDifference(captured.value, testStationId)
  }

  @Test func loadFailureLeavesNeutralHealthState() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let model = await withDependencies {
      $0.api.getStationHealthScore = { _, _ in throw TestError.networkError }
    } operation: {
      let model = ArtistDashboardPageModel()
      await model.viewAppeared()
      return model
    }

    expectNoDifference(model.healthScoreLabel, "—")
    expectNoDifference(model.improvementItems.isEmpty, true)
    expectNoDifference(model.improveCountLabel, "0 OF 0 DONE")
    expectNoDifference(model.presentedAlert != nil, true)
    expectNoDifference(model.isLoading, false)
  }

  @Test func successfulLoadClearsLoadingAndPresentsNoAlert() async {
    let model = await makeModel(returning: makeHealth(score: 80, band: .good))

    expectNoDifference(model.isLoading, false)
    expectNoDifference(model.presentedAlert == nil, true)
  }

  @Test func skipsLoadWhenNotBroadcasting() async {
    let captured = LockIsolated<String?>(nil)
    let health = makeHealth(score: 80, band: .good)
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = await withDependencies {
      $0.api.getStationHealthScore = { _, stationId in
        captured.setValue(stationId)
        return health
      }
    } operation: {
      let model = ArtistDashboardPageModel()
      await model.viewAppeared()
      return model
    }

    expectNoDifference(captured.value, nil)
    expectNoDifference(model.healthScoreLabel, "—")
  }
}

private enum TestError: Error {
  case networkError
}
