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

  private nonisolated static let emptyActive = ActiveListeningSessionsResponse(
    summary: .init(totalSessions: 0, uniqueUsers: 0, uniqueDevices: 0, anonymousSessions: 0))

  private nonisolated static let emptyCounts = ListenerCountsResponse(
    granularity: "week", startDate: "", endDate: "", timezone: "America/Chicago", buckets: [])

  private nonisolated static func active(_ uniqueUsers: Int) -> ActiveListeningSessionsResponse {
    ActiveListeningSessionsResponse(
      summary: .init(
        totalSessions: uniqueUsers, uniqueUsers: uniqueUsers, uniqueDevices: uniqueUsers,
        anonymousSessions: 0))
  }

  private nonisolated static func bucket(
    _ bucketStart: String, uniqueUsers: Int, isLive: Bool = false
  ) -> ListenerCountsResponse.Bucket {
    ListenerCountsResponse.Bucket(
      bucketStart: bucketStart, uniqueUsers: uniqueUsers, uniqueDevices: uniqueUsers,
      totalSessions: uniqueUsers, isLive: isLive)
  }

  private nonisolated static func counts(_ buckets: [ListenerCountsResponse.Bucket])
    -> ListenerCountsResponse
  {
    ListenerCountsResponse(
      granularity: "week", startDate: "", endDate: "", timezone: "America/Chicago",
      buckets: buckets)
  }

  private let fixedCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Chicago")!
    return calendar
  }()

  private let fixedNow = Date(timeIntervalSince1970: 1_724_864_400)  // 2024-08-28T17:00:00Z

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
      $0.date = .constant(fixedNow)
      $0.calendar = fixedCalendar
      $0.api.getStationHealthScore = { _, stationId in
        captured?.setValue(stationId)
        return health
      }
      $0.api.getActiveListeningSessions = { _, _, _, _ in Self.emptyActive }
      $0.api.getListenerCounts = { _, _ in Self.emptyCounts }
    } operation: {
      let model = ArtistDashboardPageModel()
      await model.viewAppeared()
      return model
    }
  }

  private func makeBroadcastingModel(
    _ configure: (inout DependencyValues) -> Void
  ) async -> ArtistDashboardPageModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    return await withDependencies {
      $0.date = .constant(fixedNow)
      $0.calendar = fixedCalendar
      $0.api.getStationHealthScore = { _, _ in
        StationHealth(score: nil, band: .unavailable, factors: [], tasks: [])
      }
      $0.api.getActiveListeningSessions = { _, _, _, _ in Self.emptyActive }
      $0.api.getListenerCounts = { _, _ in Self.emptyCounts }
      configure(&$0)
    } operation: {
      let model = ArtistDashboardPageModel()
      await model.viewAppeared()
      return model
    }
  }

  private var rollingWeekAgo: Date { fixedCalendar.date(byAdding: .day, value: -7, to: fixedNow)! }
  private var rollingTwoWeeksAgo: Date {
    fixedCalendar.date(byAdding: .day, value: -14, to: fixedNow)!
  }

  /// Builds a loaded model whose two rolling-trend windows (`[weekAgo…now]`, `[twoWeeksAgo…weekAgo]`)
  /// resolve to the given unique-user counts. Stat-card windows fall through to `emptyActive`.
  private func makeTrendModel(trailing: Int, prior: Int) async -> ArtistDashboardPageModel {
    await makeBroadcastingModel {
      $0.api.getActiveListeningSessions = { [rollingWeekAgo, rollingTwoWeeksAgo] _, _, airtime, _ in
        if airtime == rollingWeekAgo { return Self.active(trailing) }
        if airtime == rollingTwoWeeksAgo { return Self.active(prior) }
        return Self.emptyActive
      }
    }
  }

  // MARK: - Static Placeholder Content

  @Test func displaysStaticHeaderAndEmptyDataState() {
    let model = ArtistDashboardPageModel()

    expectNoDifference(model.navigationTitle, "Dashboard")
    expectNoDifference(model.weeklyReportLabel, "Weekly report")
    expectNoDifference(model.weeklyReportTrendLabel, "")
    expectNoDifference(model.weeklyReportTrendColor, .clear)
    expectNoDifference(model.healthSectionTitle, "STATION HEALTH")
    expectNoDifference(model.listenersSectionTitle, "LISTENERS")
    expectNoDifference(model.stats.map(\.value), ["—", "—", "—"])
    expectNoDifference(model.stats.map(\.label), ["NOW", "THIS WEEK", "THIS MONTH"])
    expectNoDifference(model.weekBars.isEmpty, true)
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

  // MARK: - Improve Item Navigation

  @Test func tappingAnswerQuestionsTaskPushesListenerQuestionsList() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let health = makeHealth(
      score: 40, band: .attention,
      tasks: [
        makeTask(
          key: "answered", label: "Answer questions", priority: 10, factorKey: "appearances",
          current: 0, total: 3)
      ])

    let model = await withDependencies {
      $0.date = .constant(fixedNow)
      $0.calendar = fixedCalendar
      $0.api.getStationHealthScore = { _, _ in health }
      $0.api.getActiveListeningSessions = { _, _, _, _ in Self.emptyActive }
      $0.api.getListenerCounts = { _, _ in Self.emptyCounts }
    } operation: {
      let model = ArtistDashboardPageModel()
      await model.viewAppeared()
      return model
    }

    guard let item = model.improvementItems.first else {
      Issue.record("expected an improvement item")
      return
    }
    model.improvementItemTapped(item)

    guard
      case .broadcastersListenerQuestionPage(let pushed) =
        coordinator.artistDashboardPath.last
    else {
      Issue.record("expected broadcastersListenerQuestionPage to be pushed")
      return
    }
    expectNoDifference(pushed.stationId, testStationId)
    expectNoDifference(coordinator.artistDashboardPath.count, 1)
  }

  @Test func tappingNonAppearanceTaskDoesNotNavigate() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let health = makeHealth(
      score: 40, band: .attention,
      tasks: [
        makeTask(
          key: "intros", label: "Record intros", priority: 10, factorKey: "intros",
          current: 4, total: 12)
      ])

    let model = await withDependencies {
      $0.date = .constant(fixedNow)
      $0.calendar = fixedCalendar
      $0.api.getStationHealthScore = { _, _ in health }
      $0.api.getActiveListeningSessions = { _, _, _, _ in Self.emptyActive }
      $0.api.getListenerCounts = { _, _ in Self.emptyCounts }
    } operation: {
      let model = ArtistDashboardPageModel()
      await model.viewAppeared()
      return model
    }

    guard let item = model.improvementItems.first else {
      Issue.record("expected an improvement item")
      return
    }
    model.improvementItemTapped(item)

    expectNoDifference(coordinator.artistDashboardPath.isEmpty, true)
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
      $0.date = .constant(fixedNow)
      $0.calendar = fixedCalendar
      $0.api.getStationHealthScore = { _, _ in throw TestError.networkError }
      $0.api.getActiveListeningSessions = { _, _, _, _ in Self.emptyActive }
      $0.api.getListenerCounts = { _, _ in Self.emptyCounts }
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

  // MARK: - Listeners Stat Cards

  @Test func listenerStatsReflectServerUniqueUsers() async {
    let startOfToday = fixedCalendar.startOfDay(for: fixedNow)
    let weekStart = fixedCalendar.date(byAdding: .day, value: -7, to: startOfToday)!
    let monthStart = fixedCalendar.date(byAdding: .day, value: -30, to: startOfToday)!

    let model = await makeBroadcastingModel {
      $0.api.getActiveListeningSessions = { _, _, airtime, _ in
        if airtime == startOfToday { return Self.active(23) }
        if airtime == weekStart { return Self.active(184) }
        if airtime == monthStart { return Self.active(721) }
        return Self.emptyActive
      }
    }

    expectNoDifference(model.stats.map(\.value), ["23", "184", "721"])
  }

  @Test func activeListenerWindowsUseTrailingCompleteDays() async {
    let startOfToday = fixedCalendar.startOfDay(for: fixedNow)
    let weekStart = fixedCalendar.date(byAdding: .day, value: -7, to: startOfToday)!
    let monthStart = fixedCalendar.date(byAdding: .day, value: -30, to: startOfToday)!
    let windows = LockIsolated<[Date: Date?]>([:])

    _ = await makeBroadcastingModel {
      $0.api.getActiveListeningSessions = { _, _, airtime, endTime in
        windows.withValue { $0[airtime] = endTime }
        return Self.emptyActive
      }
    }

    expectNoDifference(windows.value[startOfToday], fixedNow)
    expectNoDifference(windows.value[weekStart], startOfToday)
    expectNoDifference(windows.value[monthStart], startOfToday)
    // Five windows total: the three stat cards above plus the two rolling weekly-trend windows
    // (asserted in `weeklyTrendUsesRollingSevenDayWindows`).
    expectNoDifference(windows.value.count, 5)
  }

  @Test func listenerCardDegradesIndependentlyOnFailure() async {
    let startOfToday = fixedCalendar.startOfDay(for: fixedNow)
    let weekStart = fixedCalendar.date(byAdding: .day, value: -7, to: startOfToday)!

    let model = await makeBroadcastingModel {
      $0.api.getActiveListeningSessions = { _, _, airtime, _ in
        if airtime == weekStart { throw TestError.networkError }
        return Self.active(50)
      }
    }

    expectNoDifference(model.stats.map(\.value), ["50", "—", "50"])
    expectNoDifference(model.presentedAlert == nil, true)
  }

  // MARK: - Weekly Bar Chart

  @Test func weekBarsMapServerBucketsWithLiveSoFarBar() async {
    let model = await makeBroadcastingModel {
      $0.api.getListenerCounts = { _, _ in
        Self.counts([
          Self.bucket("2024-07-21", uniqueUsers: 22),
          Self.bucket("2024-07-28", uniqueUsers: 44),
          Self.bucket("2024-08-11", uniqueUsers: 11, isLive: true),
        ])
      }
    }

    expectNoDifference(model.weekBars.map(\.label), ["7/21", "7/28", "SO FAR"])
    expectNoDifference(model.weekBars.map(\.heightFraction), [0.5, 1.0, 0.25])
    expectNoDifference(model.weekBars.first?.barColor, .playolaRed)
    expectNoDifference(model.weekBars.last?.barColor, Color(hex: "#FFC107"))
    expectNoDifference(model.weekBars.last?.labelColor, Color(hex: "#FFC107"))
  }

  @Test func weekBarsEmptyWhenNoBuckets() async {
    let model = await makeBroadcastingModel {
      $0.api.getListenerCounts = { _, _ in Self.counts([]) }
    }

    expectNoDifference(model.weekBars.isEmpty, true)
  }

  @Test func weekBarsUseZeroHeightWhenAllCountsZero() async {
    let model = await makeBroadcastingModel {
      $0.api.getListenerCounts = { _, _ in
        Self.counts([
          Self.bucket("2024-07-21", uniqueUsers: 0),
          Self.bucket("2024-07-28", uniqueUsers: 0),
        ])
      }
    }

    expectNoDifference(model.weekBars.map(\.heightFraction), [0, 0])
  }

  @Test func chartFailureLeavesEmptyBarsWithoutAlert() async {
    let model = await makeBroadcastingModel {
      $0.api.getListenerCounts = { _, _ in throw TestError.networkError }
    }

    expectNoDifference(model.weekBars.isEmpty, true)
    expectNoDifference(model.presentedAlert == nil, true)
  }

  @Test func weekBarsCapAtMostRecentEightWeeks() async {
    let model = await makeBroadcastingModel {
      $0.api.getListenerCounts = { _, _ in
        Self.counts([
          Self.bucket("2024-06-02", uniqueUsers: 1),
          Self.bucket("2024-06-09", uniqueUsers: 2),
          Self.bucket("2024-06-16", uniqueUsers: 3),
          Self.bucket("2024-06-23", uniqueUsers: 4),
          Self.bucket("2024-06-30", uniqueUsers: 5),
          Self.bucket("2024-07-07", uniqueUsers: 6),
          Self.bucket("2024-07-14", uniqueUsers: 7),
          Self.bucket("2024-07-21", uniqueUsers: 8),
          Self.bucket("2024-07-28", uniqueUsers: 9),
          Self.bucket("2024-08-04", uniqueUsers: 10, isLive: true),
        ])
      }
    }

    expectNoDifference(model.weekBars.count, 8)
    expectNoDifference(
      model.weekBars.map(\.label),
      ["6/16", "6/23", "6/30", "7/7", "7/14", "7/21", "7/28", "SO FAR"])
    expectNoDifference(model.weekBars.last?.heightFraction, 1.0)
  }

  @Test func chartSectionTitleMatchesVisibleWeekCap() {
    let model = ArtistDashboardPageModel()

    expectNoDifference(model.chartSectionTitle, "LAST 8 WEEKS")
  }

  @Test func weekBarsClampNegativeCountsToZeroHeight() async {
    let model = await makeBroadcastingModel {
      $0.api.getListenerCounts = { _, _ in
        Self.counts([
          Self.bucket("2024-07-21", uniqueUsers: -5),
          Self.bucket("2024-07-28", uniqueUsers: 40),
        ])
      }
    }

    expectNoDifference(model.weekBars.map(\.heightFraction), [0, 1.0])
  }

  // MARK: - Weekly Report Trend

  @Test func weeklyTrendShowsUpPercentWhenTrailingWeekHigher() async {
    let model = await makeTrendModel(trailing: 120, prior: 100)

    expectNoDifference(model.weeklyReportTrendLabel, "↑ 20%")
    expectNoDifference(model.weeklyReportTrendColor, Color(hex: "#34C759"))
  }

  @Test func weeklyTrendShowsDownPercentWhenTrailingWeekLower() async {
    let model = await makeTrendModel(trailing: 80, prior: 100)

    expectNoDifference(model.weeklyReportTrendLabel, "↓ 20%")
    expectNoDifference(model.weeklyReportTrendColor, .playolaRed)
  }

  @Test func weeklyTrendShowsZeroPercentWhenFlat() async {
    let model = await makeTrendModel(trailing: 100, prior: 100)

    expectNoDifference(model.weeklyReportTrendLabel, "0%")
    expectNoDifference(model.weeklyReportTrendColor, .playolaGray)
  }

  @Test func weeklyTrendRoundsToNearestPercent() async {
    let model = await makeTrendModel(trailing: 125, prior: 120)  // +4.166% → 4%

    expectNoDifference(model.weeklyReportTrendLabel, "↑ 4%")
  }

  @Test func weeklyTrendHiddenWhenPriorWeekHasNoListeners() async {
    let model = await makeTrendModel(trailing: 50, prior: 0)

    expectNoDifference(model.weeklyReportTrendLabel, "")
    expectNoDifference(model.weeklyReportTrendColor, .clear)
  }

  @Test func weeklyTrendHiddenWhenWindowFailsWithoutAlert() async {
    let model = await makeBroadcastingModel {
      $0.api.getActiveListeningSessions = { [rollingWeekAgo] _, _, airtime, _ in
        if airtime == rollingWeekAgo { throw TestError.networkError }
        return Self.active(100)
      }
    }

    expectNoDifference(model.weeklyReportTrendLabel, "")
    expectNoDifference(model.weeklyReportTrendColor, .clear)
    expectNoDifference(model.presentedAlert == nil, true)
  }

  @Test func weeklyTrendUsesRollingSevenDayWindows() async {
    let windows = LockIsolated<[Date: Date?]>([:])

    _ = await makeBroadcastingModel {
      $0.api.getActiveListeningSessions = { _, _, airtime, endTime in
        windows.withValue { $0[airtime] = endTime }
        return Self.emptyActive
      }
    }

    expectNoDifference(windows.value[rollingWeekAgo], fixedNow)
    expectNoDifference(windows.value[rollingTwoWeeksAgo], rollingWeekAgo)
  }

  // MARK: - Chart Loading Indicator

  @Test func chartSpinnerReflectsLoadingWhenNoBucketsYet() {
    let model = ArtistDashboardPageModel()
    model.isLoading = true

    expectNoDifference(model.isChartLoading, true)
    expectNoDifference(model.chartSpinnerOpacity, 1)
  }

  @Test func chartSpinnerHiddenAfterBucketsLoad() async {
    let model = await makeBroadcastingModel {
      $0.api.getListenerCounts = { _, _ in
        Self.counts([Self.bucket("2024-07-21", uniqueUsers: 5)])
      }
    }

    expectNoDifference(model.isChartLoading, false)
    expectNoDifference(model.chartSpinnerOpacity, 0)
  }

  @Test func chartSpinnerVisibleDuringInitialLoadThenHidden() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let release = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
    let started = AsyncStream.makeStream(of: Void.self)

    let model = withDependencies {
      $0.date = .constant(fixedNow)
      $0.calendar = fixedCalendar
      $0.api.getStationHealthScore = { _, _ in
        StationHealth(score: nil, band: .unavailable, factors: [], tasks: [])
      }
      $0.api.getActiveListeningSessions = { _, _, _, _ in Self.emptyActive }
      $0.api.getListenerCounts = { _, _ in
        started.continuation.yield()
        await withCheckedContinuation { release.setValue($0) }
        return Self.counts([Self.bucket("2024-07-21", uniqueUsers: 5)])
      }
    } operation: {
      ArtistDashboardPageModel()
    }

    let task = Task { await model.viewAppeared() }
    var iterator = started.stream.makeAsyncIterator()
    await iterator.next()

    expectNoDifference(model.isChartLoading, true)
    expectNoDifference(model.chartSpinnerOpacity, 1)

    release.value?.resume()
    await task.value

    expectNoDifference(model.isChartLoading, false)
    expectNoDifference(model.chartSpinnerOpacity, 0)
    expectNoDifference(model.weekBars.count, 1)
  }

  // MARK: - Reload Staleness & Cancellation

  @Test func healthReloadFailureClearsStaleScore() async {
    let shouldFail = LockIsolated(false)
    let health = makeHealth(score: 88, band: .good)
    let model = await makeBroadcastingModel {
      $0.api.getStationHealthScore = { _, _ in
        if shouldFail.value { throw TestError.networkError }
        return health
      }
    }

    expectNoDifference(model.healthScoreLabel, "88")

    shouldFail.setValue(true)
    await model.viewAppeared()

    expectNoDifference(model.healthScoreLabel, "—")
    expectNoDifference(model.presentedAlert != nil, true)
  }

  @Test func countsReloadFailureClearsStaleBuckets() async {
    let shouldFail = LockIsolated(false)
    let model = await makeBroadcastingModel {
      $0.api.getListenerCounts = { _, _ in
        if shouldFail.value { throw TestError.networkError }
        return Self.counts([Self.bucket("2024-07-21", uniqueUsers: 12)])
      }
    }

    expectNoDifference(model.weekBars.count, 1)

    shouldFail.setValue(true)
    await model.viewAppeared()

    expectNoDifference(model.weekBars.isEmpty, true)
  }

  @Test func cancelledReloadKeepsStateWithoutAlert() async {
    let shouldCancel = LockIsolated(false)
    let health = makeHealth(score: 88, band: .good)
    let model = await makeBroadcastingModel {
      $0.api.getStationHealthScore = { _, _ in
        if shouldCancel.value { throw CancellationError() }
        return health
      }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        if shouldCancel.value { throw CancellationError() }
        return Self.active(23)
      }
      $0.api.getListenerCounts = { _, _ in
        if shouldCancel.value { throw CancellationError() }
        return Self.counts([Self.bucket("2024-07-21", uniqueUsers: 12)])
      }
    }

    expectNoDifference(model.healthScoreLabel, "88")
    expectNoDifference(model.stats.map(\.value), ["23", "23", "23"])
    expectNoDifference(model.weekBars.count, 1)

    shouldCancel.setValue(true)
    await model.viewAppeared()

    expectNoDifference(model.healthScoreLabel, "88")
    expectNoDifference(model.stats.map(\.value), ["23", "23", "23"])
    expectNoDifference(model.weekBars.count, 1)
    expectNoDifference(model.presentedAlert == nil, true)
  }

  @Test func stationSwitchClearsStaleCardsEvenWhenNewLoadCancels() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: "station-A")

    let model = await withDependencies {
      $0.date = .constant(fixedNow)
      $0.calendar = fixedCalendar
      $0.api.getStationHealthScore = { _, _ in
        StationHealth(score: nil, band: .unavailable, factors: [], tasks: [])
      }
      $0.api.getActiveListeningSessions = { _, stationId, _, _ in
        if stationId == "station-B" { throw CancellationError() }
        return Self.active(23)
      }
      $0.api.getListenerCounts = { _, _ in Self.emptyCounts }
    } operation: {
      let model = ArtistDashboardPageModel()
      await model.viewAppeared()
      return model
    }

    expectNoDifference(model.stats.map(\.value), ["23", "23", "23"])

    coordinator.switchToBroadcastMode(stationId: "station-B")
    await model.viewAppeared()

    expectNoDifference(model.stats.map(\.value), ["—", "—", "—"])
  }

  @Test func staleInFlightLoadDoesNotClobberNewerStationData() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: "station-A")

    let releaseA = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
    let aStarted = AsyncStream.makeStream(of: Void.self)

    let model = withDependencies {
      $0.date = .constant(fixedNow)
      $0.calendar = fixedCalendar
      $0.api.getStationHealthScore = { _, stationId in
        if stationId == "station-A" {
          aStarted.continuation.yield()
          await withCheckedContinuation { releaseA.setValue($0) }
          return StationHealth(score: 11, band: .attention, factors: [], tasks: [])
        }
        return StationHealth(score: 99, band: .good, factors: [], tasks: [])
      }
      $0.api.getActiveListeningSessions = { _, _, _, _ in Self.emptyActive }
      $0.api.getListenerCounts = { _, _ in Self.emptyCounts }
    } operation: {
      ArtistDashboardPageModel()
    }

    // Station A's health load starts and blocks mid-flight (generation 1).
    let taskA = Task { await model.viewAppeared() }
    var iterator = aStarted.stream.makeAsyncIterator()
    await iterator.next()

    // Switch to station B and let its load finish fully (generation 2).
    coordinator.switchToBroadcastMode(stationId: "station-B")
    await model.viewAppeared()
    expectNoDifference(model.healthScoreLabel, "99")

    // A's now-stale request returns last; the generation guard must drop its write.
    releaseA.value?.resume()
    await taskA.value

    expectNoDifference(model.healthScoreLabel, "99")
  }

  // MARK: - Decoding Tolerance

  @Test func bucketDefaultsIsLiveFalseWhenServerOmitsIt() throws {
    let json = Data(
      """
      {"bucketStart": "2024-07-21", "uniqueUsers": 5}
      """.utf8)

    let bucket = try JSONDecoder().decode(ListenerCountsResponse.Bucket.self, from: json)

    expectNoDifference(bucket.bucketStart, "2024-07-21")
    expectNoDifference(bucket.uniqueUsers, 5)
    expectNoDifference(bucket.isLive, false)
  }

  @Test func listenerCountsDecodesWithOnlyBucketsPresent() throws {
    let json = Data(
      """
      {"buckets": [{"bucketStart": "2024-07-21", "uniqueUsers": 5, "isLive": true}]}
      """.utf8)

    let response = try JSONDecoder().decode(ListenerCountsResponse.self, from: json)

    expectNoDifference(response.buckets.map(\.bucketStart), ["2024-07-21"])
    expectNoDifference(response.buckets.map(\.isLive), [true])
  }

  @Test func activeSessionsDecodesWithOnlyUniqueUsersPresent() throws {
    let json = Data(
      """
      {"summary": {"uniqueUsers": 12}}
      """.utf8)

    let response = try JSONDecoder().decode(ActiveListeningSessionsResponse.self, from: json)

    expectNoDifference(response.summary.uniqueUsers, 12)
  }
}

private enum TestError: Error {
  case networkError
}
