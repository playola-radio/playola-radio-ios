// swiftlint:disable file_length
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
    freshPct: Int?,
    status: ProgrammingHealthStatus,
    checks: [ProgrammingHealthCheck] = []
  ) -> ProgrammingHealth {
    ProgrammingHealth(stationId: testStationId, status: status, freshPct: freshPct, checks: checks)
  }

  private func makeCheck(
    kind: String,
    status: ProgrammingHealthStatus,
    current: Int?,
    required: Int?
  ) -> ProgrammingHealthCheck {
    var progress: ProgrammingHealthCheckProgress?
    if let current, let required {
      progress = ProgrammingHealthCheckProgress(current: current, required: required)
    }
    return ProgrammingHealthCheck(kind: kind, status: status, progress: progress)
  }

  private func makeModel(
    returning health: ProgrammingHealth,
    capturingStationId captured: LockIsolated<String?>? = nil
  ) async -> ArtistDashboardPageModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    return await withDependencies {
      $0.date = .constant(fixedNow)
      $0.calendar = fixedCalendar
      $0.api.getProgrammingHealth = { _, stationId in
        captured?.setValue(stationId)
        return health
      }
      $0.api.getActiveListeningSessions = { _, _, _, _ in Self.emptyActive }
      $0.api.getListenerCounts = { _, _, _, _ in Self.emptyCounts }
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
      $0.api.getProgrammingHealth = { _, _ in
        ProgrammingHealth(
          stationId: self.testStationId, status: .unknown, freshPct: nil, checks: [])
      }
      $0.api.getActiveListeningSessions = { _, _, _, _ in Self.emptyActive }
      $0.api.getListenerCounts = { _, _, _, _ in Self.emptyCounts }
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

  @Test func healthScoreAndRingReflectServerFreshPct() async {
    let model = await makeModel(returning: makeHealth(freshPct: 92, status: .healthy))

    expectNoDifference(model.healthScoreLabel, "92")
    expectNoDifference(model.healthRingProgress, 0.92)
    expectNoDifference(model.healthRingColor, Color(hex: "#34C759"))
    expectNoDifference(model.healthStatusLabel, "Your station is in good shape")
  }

  @Test func warningStatusUsesAmberRingAndCopy() async {
    let model = await makeModel(returning: makeHealth(freshPct: 80, status: .warning))

    expectNoDifference(model.healthRingColor, Color(hex: "#FFC107"))
    expectNoDifference(model.healthStatusLabel, "Your station could use a little attention")
  }

  @Test func unhealthyStatusUsesRedRingAndCopy() async {
    let model = await makeModel(returning: makeHealth(freshPct: 40, status: .unhealthy))

    expectNoDifference(model.healthRingColor, .playolaRed)
    expectNoDifference(model.healthStatusLabel, "Your station needs some attention")
  }

  @Test func nullFreshPctRendersNeutralEmptyStateNeverZero() async {
    let model = await makeModel(returning: makeHealth(freshPct: nil, status: .unknown))

    expectNoDifference(model.healthScoreLabel, "—")
    expectNoDifference(model.healthRingProgress, 0)
    expectNoDifference(model.healthRingColor, Color(hex: "#999999"))
    expectNoDifference(model.healthStatusLabel, "Station health isn't available yet")
  }

  @Test func ringProgressClampsOutOfRangeFreshPct() async {
    let model = await makeModel(returning: makeHealth(freshPct: 140, status: .healthy))

    expectNoDifference(model.healthRingProgress, 1)
  }

  // MARK: - Improve Your Station: Known Kinds & Copy

  @Test func unknownCheckKindsAreHiddenAndExcludedFromCount() async {
    let health = makeHealth(
      freshPct: 50, status: .warning,
      checks: [
        makeCheck(kind: "appearances", status: .healthy, current: 2, required: 2),
        makeCheck(kind: "brandNewKind", status: .healthy, current: 1, required: 1),
      ])
    let model = await makeModel(returning: health)

    expectNoDifference(model.improvementItems.map(\.title), ["Make DJ appearances"])
    expectNoDifference(model.improveCountLabel, "1 OF 1 DONE")
  }

  @Test func improveCountCountsChecksWithHealthyStatus() async {
    let health = makeHealth(
      freshPct: 50, status: .warning,
      checks: [
        makeCheck(kind: "appearances", status: .healthy, current: 3, required: 3),
        makeCheck(kind: "songCategoryFreshness", status: .warning, current: 1, required: 4),
        makeCheck(
          kind: "breakerCategoryFreshness", status: .unhealthy, current: nil, required: nil),
      ])
    let model = await makeModel(returning: health)

    expectNoDifference(model.improveCountLabel, "1 OF 3 DONE")
  }

  @Test func completionCountsAreNeverRederivedFromProgress() async {
    // status says healthy even though current < required — status is the single source of
    // truth for completion, never re-derived from progress client-side.
    let health = makeHealth(
      freshPct: 90, status: .healthy,
      checks: [
        makeCheck(kind: "appearances", status: .healthy, current: 1, required: 5)
      ])
    let model = await makeModel(returning: health)

    expectNoDifference(model.improveCountLabel, "1 OF 1 DONE")
    expectNoDifference(model.improvementItems.first?.icon, "checkmark")
  }

  @Test func appearancesSubtitleReadsCurrentOfRequired() async {
    let health = makeHealth(
      freshPct: 50, status: .warning,
      checks: [makeCheck(kind: "appearances", status: .warning, current: 1, required: 3)])
    let model = await makeModel(returning: health)

    expectNoDifference(model.improvementItems.first?.subtitle, "1 of 3")
  }

  @Test func categoryFreshnessSubtitleAppendsCategoriesFresh() async {
    let health = makeHealth(
      freshPct: 50, status: .warning,
      checks: [
        makeCheck(kind: "songCategoryFreshness", status: .warning, current: 4, required: 5)
      ])
    let model = await makeModel(returning: health)

    expectNoDifference(model.improvementItems.first?.subtitle, "4 of 5 categories fresh")
  }

  @Test func breakerCategoryFreshnessSubtitleAppendsCategoriesFresh() async {
    let health = makeHealth(
      freshPct: 50, status: .warning,
      checks: [
        makeCheck(kind: "breakerCategoryFreshness", status: .healthy, current: 3, required: 3)
      ])
    let model = await makeModel(returning: health)

    expectNoDifference(model.improvementItems.first?.subtitle, "3 of 3 categories fresh")
  }

  @Test func pendingQuestionsSubtitleReadsWaitingCountNotZeroOfZero() async {
    let health = makeHealth(
      freshPct: 50, status: .warning,
      checks: [
        makeCheck(kind: "pendingListenerQuestions", status: .warning, current: 4, required: 0)
      ])
    let model = await makeModel(returning: health)

    expectNoDifference(model.improvementItems.first?.subtitle, "4 waiting")
  }

  @Test func pendingQuestionsSubtitleReadsAllCaughtUpWhenZero() async {
    let health = makeHealth(
      freshPct: 90, status: .healthy,
      checks: [
        makeCheck(kind: "pendingListenerQuestions", status: .healthy, current: 0, required: 0)
      ])
    let model = await makeModel(returning: health)

    expectNoDifference(model.improvementItems.first?.subtitle, "All caught up")
    // Never "0 of 0".
    expectNoDifference(model.improvementItems.first?.subtitle.contains("of"), false)
  }

  @Test func requiredZeroHidesProgressBarButKeepsSubtitle() async {
    let health = makeHealth(
      freshPct: 50, status: .warning,
      checks: [
        makeCheck(kind: "pendingListenerQuestions", status: .warning, current: 2, required: 0)
      ])
    let model = await makeModel(returning: health)

    let item = model.improvementItems.first
    expectNoDifference(item?.subtitle, "2 waiting")
    expectNoDifference(item?.progress, 0)
    expectNoDifference(item?.progressTrackColor, .clear)
  }

  @Test func currentGreaterThanRequiredShowsVerbatimWithCappedBar() async {
    let health = makeHealth(
      freshPct: 50, status: .warning,
      checks: [makeCheck(kind: "appearances", status: .healthy, current: 3, required: 2)])
    let model = await makeModel(returning: health)

    let item = model.improvementItems.first
    expectNoDifference(item?.subtitle, "3 of 2")
    expectNoDifference(item?.progress, 1)
  }

  @Test func progressNilShowsTitleOnlyNoSubtitleNoBar() async {
    let health = makeHealth(
      freshPct: 50, status: .warning,
      checks: [makeCheck(kind: "appearances", status: .warning, current: nil, required: nil)])
    let model = await makeModel(returning: health)

    let item = model.improvementItems.first
    expectNoDifference(item?.subtitle, "")
    expectNoDifference(item?.progress, 0)
    expectNoDifference(item?.progressTrackColor, .clear)
  }

  @Test func incompleteItemUsesFractionalProgress() async {
    let health = makeHealth(
      freshPct: 50, status: .warning,
      checks: [makeCheck(kind: "songCategoryFreshness", status: .warning, current: 4, required: 12)]
    )
    let model = await makeModel(returning: health)

    let item = model.improvementItems.first
    expectNoDifference(item?.title, "Keep song categories fresh")
    expectNoDifference(item?.subtitle, "4 of 12 categories fresh")
    expectNoDifference(item?.progress, 4.0 / 12.0)
    expectNoDifference(item?.titleColor, .white)
    expectNoDifference(item?.progressColor, .playolaRed)
  }

  @Test func completedItemUsesCheckedStyling() async {
    let health = makeHealth(
      freshPct: 90, status: .healthy,
      checks: [
        makeCheck(kind: "pendingListenerQuestions", status: .healthy, current: 0, required: 0)
      ])
    let model = await makeModel(returning: health)

    let item = model.improvementItems.first
    expectNoDifference(item?.icon, "checkmark")
    expectNoDifference(item?.progress, 1)
    expectNoDifference(item?.titleColor, Color(hex: "#999999"))
    expectNoDifference(item?.subtitleColor, Color(hex: "#34C759"))
    expectNoDifference(item?.progressColor, Color(hex: "#34C759"))
  }

  @Test func taskWithProgressShowsVisibleTrack() async {
    let health = makeHealth(
      freshPct: 50, status: .warning,
      checks: [makeCheck(kind: "appearances", status: .warning, current: 1, required: 4)])
    let model = await makeModel(returning: health)

    expectNoDifference(model.improvementItems.first?.progressTrackColor, Color(hex: "#5E5F5F"))
  }

  // MARK: - Improve Item Navigation

  @Test func tappingAppearancesRowPushesListenerQuestionsList() async {
    let health = makeHealth(
      freshPct: 40, status: .unhealthy,
      checks: [makeCheck(kind: "appearances", status: .warning, current: 0, required: 3)])
    let model = await makeModel(returning: health)

    guard let item = model.improvementItems.first else {
      Issue.record("expected an improvement item")
      return
    }
    expectNoDifference(item.isTappable, true)
    expectNoDifference(item.chevronOpacity, 1)

    model.improvementItemTapped(item)

    @Shared(.mainContainerNavigationCoordinator) var coordinator
    guard
      case .broadcastersListenerQuestionPage(let pushed) = coordinator.artistDashboardPath.last
    else {
      Issue.record("expected broadcastersListenerQuestionPage to be pushed")
      return
    }
    expectNoDifference(pushed.stationId, testStationId)
    expectNoDifference(coordinator.artistDashboardPath.count, 1)
  }

  @Test func tappingPendingQuestionsRowPushesListenerQuestionsList() async {
    let health = makeHealth(
      freshPct: 40, status: .unhealthy,
      checks: [
        makeCheck(kind: "pendingListenerQuestions", status: .warning, current: 2, required: 0)
      ])
    let model = await makeModel(returning: health)

    guard let item = model.improvementItems.first else {
      Issue.record("expected an improvement item")
      return
    }
    model.improvementItemTapped(item)

    @Shared(.mainContainerNavigationCoordinator) var coordinator
    guard
      case .broadcastersListenerQuestionPage(let pushed) = coordinator.artistDashboardPath.last
    else {
      Issue.record("expected broadcastersListenerQuestionPage to be pushed")
      return
    }
    expectNoDifference(pushed.stationId, testStationId)
  }

  @Test func tappingFreshnessRowDoesNotNavigateAndHasNoChevron() async {
    let health = makeHealth(
      freshPct: 40, status: .unhealthy,
      checks: [
        makeCheck(kind: "songCategoryFreshness", status: .warning, current: 4, required: 12)
      ])
    let model = await makeModel(returning: health)

    guard let item = model.improvementItems.first else {
      Issue.record("expected an improvement item")
      return
    }
    expectNoDifference(item.isTappable, false)
    expectNoDifference(item.chevronOpacity, 0)

    model.improvementItemTapped(item)

    @Shared(.mainContainerNavigationCoordinator) var coordinator
    expectNoDifference(coordinator.artistDashboardPath.isEmpty, true)
  }

  // MARK: - Loading Behavior

  @Test func viewAppearedRequestsBroadcastingStationId() async {
    let captured = LockIsolated<String?>(nil)
    _ = await makeModel(
      returning: makeHealth(freshPct: 80, status: .healthy), capturingStationId: captured)

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
      $0.api.getProgrammingHealth = { _, _ in throw TestError.networkError }
      $0.api.getActiveListeningSessions = { _, _, _, _ in Self.emptyActive }
      $0.api.getListenerCounts = { _, _, _, _ in Self.emptyCounts }
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
    let model = await makeModel(returning: makeHealth(freshPct: 80, status: .healthy))

    expectNoDifference(model.isLoading, false)
    expectNoDifference(model.presentedAlert == nil, true)
  }

  @Test func skipsLoadWhenNotBroadcasting() async {
    let captured = LockIsolated<String?>(nil)
    let health = makeHealth(freshPct: 80, status: .healthy)
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = await withDependencies {
      $0.api.getProgrammingHealth = { _, stationId in
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
        if airtime == fixedNow { return Self.active(23) }
        if airtime == weekStart { return Self.active(184) }
        if airtime == monthStart { return Self.active(721) }
        return Self.emptyActive
      }
    }

    expectNoDifference(model.stats.map(\.value), ["23", "184", "721"])
  }

  @Test func nowCardRequestsPointInTimeWindowNotTodaySoFar() async {
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

    // NOW: airtime == now, endTime == nil ("listening right now"), not
    // airtime == startOfToday / endTime == now ("listened at any point today").
    expectNoDifference(windows.value[fixedNow] ?? .some(nil), .some(nil))
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
      $0.api.getListenerCounts = { _, _, _, _ in
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
      $0.api.getListenerCounts = { _, _, _, _ in Self.counts([]) }
    }

    expectNoDifference(model.weekBars.isEmpty, true)
  }

  @Test func weekBarsUseZeroHeightWhenAllCountsZero() async {
    let model = await makeBroadcastingModel {
      $0.api.getListenerCounts = { _, _, _, _ in
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
      $0.api.getListenerCounts = { _, _, _, _ in throw TestError.networkError }
    }

    expectNoDifference(model.weekBars.isEmpty, true)
    expectNoDifference(model.presentedAlert == nil, true)
  }

  @Test func weekBarsCapAtMostRecentEightWeeks() async {
    let model = await makeBroadcastingModel {
      $0.api.getListenerCounts = { _, _, _, _ in
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
      $0.api.getListenerCounts = { _, _, _, _ in
        Self.counts([
          Self.bucket("2024-07-21", uniqueUsers: -5),
          Self.bucket("2024-07-28", uniqueUsers: 40),
        ])
      }
    }

    expectNoDifference(model.weekBars.map(\.heightFraction), [0, 1.0])
  }

  @Test func listenerCountsRequestsComputedChicagoDateRange() async {
    let requestedRange = LockIsolated<(String, String)?>(nil)

    _ = await makeBroadcastingModel {
      $0.api.getListenerCounts = { _, _, startDate, endDate in
        requestedRange.setValue((startDate, endDate))
        return Self.emptyCounts
      }
    }

    let expected = ArtistDashboardPageModel.listenerCountsDateRange(now: fixedNow)
    expectNoDifference(requestedRange.value?.0, expected.startDate)
    expectNoDifference(requestedRange.value?.1, expected.endDate)
  }

  // MARK: - Listener Counts Date Range Helper

  @Test func dateRangeHelperMidweekDate() {
    // Wednesday 2026-09-16 12:00 UTC (America/Chicago: still Wed 2026-09-16).
    let now = Date(timeIntervalSince1970: 1_789_567_200)
    let range = ArtistDashboardPageModel.listenerCountsDateRange(now: now)

    expectNoDifference(range.endDate, "2026-09-16")
    // Current week's Monday is 2026-09-14; 7 preceding weeks back is 2026-07-27.
    expectNoDifference(range.startDate, "2026-07-27")
  }

  @Test func dateRangeHelperOnAMonday() {
    // Monday 2026-09-14 12:00 UTC.
    let now = Date(timeIntervalSince1970: 1_789_394_400)
    let range = ArtistDashboardPageModel.listenerCountsDateRange(now: now)

    expectNoDifference(range.endDate, "2026-09-14")
    expectNoDifference(range.startDate, "2026-07-27")
  }

  @Test func dateRangeHelperSundayNightUSEasternDeviceTime() {
    // Sunday 2026-09-13, 23:30 US-Eastern == 2026-09-14 03:30 UTC == Sunday 2026-09-13 22:30
    // America/Chicago (still Sunday there — one hour behind Eastern).
    let now = Date(timeIntervalSince1970: 1_789_357_800)
    let range = ArtistDashboardPageModel.listenerCountsDateRange(now: now)

    expectNoDifference(range.endDate, "2026-09-13")
    // Current week's Monday (containing 2026-09-13, a Sunday) is 2026-09-07.
    expectNoDifference(range.startDate, "2026-07-20")
  }

  @Test func dateRangeHelperSpringForwardDST() {
    // 2026-03-08 is US spring-forward (America/Chicago: 2am -> 3am). Noon UTC lands on the
    // morning of 2026-03-08 in Chicago (just after the transition).
    let now = Date(timeIntervalSince1970: 1_772_971_200)
    let range = ArtistDashboardPageModel.listenerCountsDateRange(now: now)

    expectNoDifference(range.endDate, "2026-03-08")
    // 2026-03-08 is a Sunday; current week's Monday is 2026-03-02, minus 7 weeks = 2026-01-12.
    expectNoDifference(range.startDate, "2026-01-12")
  }

  @Test func dateRangeHelperFallBackDST() {
    // 2026-11-01 is US fall-back (America/Chicago: 2am -> 1am). Noon UTC lands on the
    // morning of 2026-11-01 in Chicago.
    let now = Date(timeIntervalSince1970: 1_793_534_400)
    let range = ArtistDashboardPageModel.listenerCountsDateRange(now: now)

    expectNoDifference(range.endDate, "2026-11-01")
    // 2026-11-01 is a Sunday; current week's Monday is 2026-10-26, minus 7 weeks = 2026-09-07.
    expectNoDifference(range.startDate, "2026-09-07")
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
      $0.api.getListenerCounts = { _, _, _, _ in
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
      $0.api.getProgrammingHealth = { _, _ in
        ProgrammingHealth(stationId: testStationId, status: .unknown, freshPct: nil, checks: [])
      }
      $0.api.getActiveListeningSessions = { _, _, _, _ in Self.emptyActive }
      $0.api.getListenerCounts = { _, _, _, _ in
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
    let health = makeHealth(freshPct: 88, status: .healthy)
    let model = await makeBroadcastingModel {
      $0.api.getProgrammingHealth = { _, _ in
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
      $0.api.getListenerCounts = { _, _, _, _ in
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
    let health = makeHealth(freshPct: 88, status: .healthy)
    let model = await makeBroadcastingModel {
      $0.api.getProgrammingHealth = { _, _ in
        if shouldCancel.value { throw CancellationError() }
        return health
      }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        if shouldCancel.value { throw CancellationError() }
        return Self.active(23)
      }
      $0.api.getListenerCounts = { _, _, _, _ in
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
      $0.api.getProgrammingHealth = { _, _ in
        ProgrammingHealth(stationId: "station-A", status: .unknown, freshPct: nil, checks: [])
      }
      $0.api.getActiveListeningSessions = { _, stationId, _, _ in
        if stationId == "station-B" { throw CancellationError() }
        return Self.active(23)
      }
      $0.api.getListenerCounts = { _, _, _, _ in Self.emptyCounts }
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
      $0.api.getProgrammingHealth = { _, stationId in
        if stationId == "station-A" {
          aStarted.continuation.yield()
          await withCheckedContinuation { releaseA.setValue($0) }
          return ProgrammingHealth(
            stationId: "station-A", status: .unhealthy, freshPct: 11, checks: [])
        }
        return ProgrammingHealth(stationId: "station-B", status: .healthy, freshPct: 99, checks: [])
      }
      $0.api.getActiveListeningSessions = { _, _, _, _ in Self.emptyActive }
      $0.api.getListenerCounts = { _, _, _, _ in Self.emptyCounts }
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
