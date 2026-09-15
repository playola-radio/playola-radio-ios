//
//  ArtistDashboardPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import Dependencies
import Sharing
import SwiftUI

// NOTE: The Station Health ring / "Improve your station" checklist come from
// `getProgrammingHealth`; the Listeners stat cards come from `getActiveListeningSessions` (one
// call per card); the 8-week chart comes from `getListenerCounts`. The Weekly Report header trend
// is a rolling week-over-week change (trailing 7 days vs. the prior 7 days) computed from two
// more `getActiveListeningSessions` windows.
@MainActor
@Observable
class ArtistDashboardPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.calendar) var calendar

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Types

  struct Stat: Identifiable {
    let id: String
    let value: String
    let label: String
  }

  struct WeekBar: Identifiable {
    let id: String
    let label: String
    let labelColor: Color
    let labelFontName: String
    let labelFontSize: CGFloat
    let barColor: Color
    let heightFraction: Double
  }

  struct ImprovementItem: Identifiable {
    let id: String
    let icon: String
    let iconColor: Color
    let iconBackgroundColor: Color
    let iconBorderColor: Color
    let title: String
    let titleColor: Color
    let titleFontName: String
    let subtitle: String
    let subtitleColor: Color
    let progress: Double
    let progressColor: Color
    let progressTrackColor: Color
    /// Drives the row's tap affordance without any control flow in the view: rows that navigate
    /// somewhere get a visible chevron, rows that don't get a fully transparent one.
    let chevronOpacity: Double
    let isTappable: Bool
  }

  // MARK: - State

  private var programmingHealth: ProgrammingHealth?
  private var nowUniqueUsers: Int?
  private var weekUniqueUsers: Int?
  private var monthUniqueUsers: Int?
  private var trailingWeekUsers: Int?
  private var priorWeekUsers: Int?
  private var listenerBuckets: [ListenerCountsResponse.Bucket] = []
  private var loadedStationId: String?
  /// Bumped once per `viewAppeared`. Each concurrent load captures the value at launch and only
  /// writes back if it still matches — so a slow load from an older station (or an earlier reload)
  /// can't clobber fresher data if it finishes after a newer load has started. Cancellation covers
  /// the common navigation-away case; this closes the narrow window where an in-flight request has
  /// already returned before cancellation propagates.
  private var loadGeneration = 0
  var isLoading = false
  var presentedAlert: PlayolaAlert?

  // MARK: - Properties

  var navigationTitle: String { "Dashboard" }

  var weeklyReportLabel: String { "Weekly report" }

  /// Rolling week-over-week trend for the header. Hidden (empty label, clear color) whenever it
  /// can't be shown honestly — see `weeklyTrendPercent`.
  var weeklyReportTrendLabel: String {
    guard let percent = weeklyTrendPercent else { return "" }
    if percent > 0 { return "↑ \(percent)%" }
    if percent < 0 { return "↓ \(-percent)%" }
    return "0%"
  }

  var weeklyReportTrendColor: Color {
    guard let percent = weeklyTrendPercent else { return .clear }
    if percent > 0 { return Color(hex: "#34C759") }
    if percent < 0 { return .playolaRed }
    return .playolaGray
  }

  var healthSectionTitle: String { "STATION HEALTH" }
  var healthScoreLabel: String { programmingHealth?.freshPct.map(String.init) ?? "—" }
  var healthRingProgress: Double {
    programmingHealth?.freshPct.map { min(1, max(0, Double($0) / 100)) } ?? 0
  }
  var healthRingColor: Color { ringColor(for: programmingHealth?.status) }
  var healthStatusLabel: String { statusLabel(for: programmingHealth?.status) }

  var listenersSectionTitle: String { "LISTENERS" }

  var stats: [Stat] {
    [
      Stat(id: "now", value: Self.statValue(nowUniqueUsers), label: "NOW"),
      Stat(id: "this-week", value: Self.statValue(weekUniqueUsers), label: "THIS WEEK"),
      Stat(id: "this-month", value: Self.statValue(monthUniqueUsers), label: "THIS MONTH"),
    ]
  }

  var chartSectionTitle: String { "LAST \(Self.maxVisibleWeeks) WEEKS" }
  var chartLinkLabel: String { "Stats ›" }

  /// True only on the first load for a station, before any buckets have arrived. A same-station
  /// reload keeps the existing bars visible (no spinner) rather than blanking the chart.
  var isChartLoading: Bool { isLoading && listenerBuckets.isEmpty }
  var chartSpinnerOpacity: Double { isChartLoading ? 1 : 0 }

  /// The chart shows only the most-recent weeks so the fixed-width bars stay within the screen;
  /// older buckets are dropped rather than overflowing the row.
  private static let maxVisibleWeeks = 8

  var weekBars: [WeekBar] {
    let visibleBuckets = listenerBuckets.suffix(Self.maxVisibleWeeks)
    let maxUsers = visibleBuckets.map { max(0, $0.uniqueUsers) }.max() ?? 0
    return visibleBuckets.map { bucket in
      let rawFraction = maxUsers == 0 ? 0 : Double(max(0, bucket.uniqueUsers)) / Double(maxUsers)
      let fraction = min(1, max(0, rawFraction))
      if bucket.isLive {
        return WeekBar(
          id: bucket.bucketStart, label: "SO FAR", labelColor: Color(hex: "#FFC107"),
          labelFontName: FontNames.Inter_700_Bold, labelFontSize: 7,
          barColor: Color(hex: "#FFC107"), heightFraction: fraction)
      }
      return WeekBar(
        id: bucket.bucketStart, label: Self.monthDayLabel(bucket.bucketStart),
        labelColor: .playolaGray, labelFontName: FontNames.Inter_500_Medium, labelFontSize: 8,
        barColor: .playolaRed, heightFraction: fraction)
    }
  }

  var improveSectionTitle: String { "IMPROVE YOUR STATION" }

  /// Kinds the client knows how to render. Unknown kinds are hidden entirely — no meaningful
  /// client-owned copy exists for them yet — and excluded from the N/M count below.
  private static let knownCheckKinds: Set<String> = [
    "appearances", "songCategoryFreshness", "breakerCategoryFreshness",
    "pendingListenerQuestions",
  ]

  /// Kinds whose row navigates to the listener-questions list: answering questions is how
  /// appearances get made, so both the backlog and the completion counter for it land there.
  private static let navigableCheckKinds: Set<String> = [
    "appearances", "pendingListenerQuestions",
  ]

  private var knownChecks: [ProgrammingHealthCheck] {
    (programmingHealth?.checks ?? []).filter { Self.knownCheckKinds.contains($0.kind) }
  }

  var improveCountLabel: String {
    let checks = knownChecks
    let done = checks.filter { $0.status == .healthy }.count
    return "\(done) OF \(checks.count) DONE"
  }

  var improveCountColor: Color { Color(hex: "#34C759") }

  var improvementItems: [ImprovementItem] {
    knownChecks.map(Self.improvementItem(from:))
  }

  // MARK: - User Actions

  func viewAppeared() async {
    guard let token = auth.jwt, let stationId else { return }
    if stationId != loadedStationId {
      loadedStationId = stationId
      clearDisplayState()
    }
    loadGeneration += 1
    let generation = loadGeneration
    isLoading = true
    defer { if generation == loadGeneration { isLoading = false } }
    async let health: Void = loadProgrammingHealth(
      token: token, stationId: stationId, generation: generation)
    async let listeners: Void = loadListenerStats(
      token: token, stationId: stationId, generation: generation)
    async let counts: Void = loadListenerCounts(
      token: token, stationId: stationId, generation: generation)
    async let trend: Void = loadWeeklyTrend(
      token: token, stationId: stationId, generation: generation)
    _ = await (health, listeners, counts, trend)
  }

  func weeklyReportTapped() {}

  func statsLinkTapped() {}

  func improvementItemTapped(_ item: ImprovementItem) {
    guard let stationId, item.isTappable else { return }
    navigationCoordinator.push(
      .broadcastersListenerQuestionPage(BroadcastersListenerQuestionPageModel(stationId: stationId))
    )
  }

  // MARK: - View Helpers

  /// Computes the `[startDate, endDate]` range (`YYYY-MM-DD`, America/Chicago) requested from
  /// `getListenerCounts`: the current Chicago week plus the 7 preceding weeks (8 total, matching
  /// `maxVisibleWeeks`). Pure and independent of the model's injected `\.calendar` — the server
  /// buckets in America/Chicago regardless of device locale, so this helper owns its own
  /// Gregorian, Monday-first, America/Chicago calendar rather than trusting the device's.
  static func listenerCountsDateRange(now: Date) -> (startDate: String, endDate: String) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Chicago")!
    calendar.firstWeekday = 2  // Monday

    let today = calendar.startOfDay(for: now)
    let weekday = calendar.component(.weekday, from: today)
    let daysSinceMonday = (weekday - calendar.firstWeekday + 7) % 7
    let currentWeekMonday =
      calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
    let precedingWeeks = maxVisibleWeeks - 1
    let startDate =
      calendar.date(byAdding: .day, value: -7 * precedingWeeks, to: currentWeekMonday)
      ?? currentWeekMonday

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return (startDate: formatter.string(from: startDate), endDate: formatter.string(from: today))
  }

  // MARK: - Private Helpers

  private var stationId: String? {
    if case .broadcasting(let stationId) = navigationCoordinator.appMode {
      return stationId
    }
    return nil
  }

  private func loadProgrammingHealth(token: String, stationId: String, generation: Int) async {
    do {
      let health = try await api.getProgrammingHealth(token, stationId)
      guard generation == loadGeneration else { return }
      programmingHealth = health
    } catch {
      guard !isCancellation(error) else { return }
      guard generation == loadGeneration else { return }
      programmingHealth = nil
      presentedAlert = .stationHealthError(error.localizedDescription)
      await analytics.track(
        .apiError(endpoint: "getProgrammingHealth", error: error.localizedDescription))
    }
  }

  private func loadListenerStats(token: String, stationId: String, generation: Int) async {
    let referenceNow = now
    let startOfToday = calendar.startOfDay(for: referenceNow)
    let endOfYesterday = startOfToday
    let weekStart = calendar.date(byAdding: .day, value: -7, to: endOfYesterday) ?? endOfYesterday
    let monthStart = calendar.date(byAdding: .day, value: -30, to: endOfYesterday) ?? endOfYesterday

    // NOW means "listening right now": a point-in-time check (no endTime), not "listened at any
    // point today".
    async let nowCount = uniqueUsers(
      token: token, stationId: stationId, airtime: referenceNow, endTime: nil)
    async let weekCount = uniqueUsers(
      token: token, stationId: stationId, airtime: weekStart, endTime: endOfYesterday)
    async let monthCount = uniqueUsers(
      token: token, stationId: stationId, airtime: monthStart, endTime: endOfYesterday)

    do {
      let (now, week, month) = try await (nowCount, weekCount, monthCount)
      guard generation == loadGeneration else { return }
      nowUniqueUsers = now
      weekUniqueUsers = week
      monthUniqueUsers = month
    } catch {
      // The task was cancelled (navigation away / remount): keep the cards' prior values and
      // skip analytics, mirroring `loadProgrammingHealth` / `loadListenerCounts`. Reached only when
      // cancelled — a genuine one-card failure on a live task is swallowed inside `uniqueUsers`
      // (tracked there, returns `nil`) so only that card degrades to "—". (If a real error
      // happens to surface while the task is already cancelled, it is dropped here on purpose:
      // the view is going away.)
    }
  }

  /// Rolling week-over-week change powering the header trend: trailing 7 days vs. the 7 days
  /// before. Both windows are exactly seven days, so it stays low-noise while still moving daily.
  /// Returns `nil` when it can't be computed honestly — either window failed to load, or the prior
  /// window had no listeners to divide by (a "new station" that would otherwise show ∞%).
  private var weeklyTrendPercent: Int? {
    guard let trailing = trailingWeekUsers, let prior = priorWeekUsers, prior > 0 else {
      return nil
    }
    let change = Double(trailing - prior) / Double(prior)
    return Int((change * 100).rounded())
  }

  private func loadWeeklyTrend(token: String, stationId: String, generation: Int) async {
    let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
    let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now

    async let trailing = uniqueUsers(
      token: token, stationId: stationId, airtime: weekAgo, endTime: now)
    async let prior = uniqueUsers(
      token: token, stationId: stationId, airtime: twoWeeksAgo, endTime: weekAgo)

    do {
      let (trailingUsers, priorUsers) = try await (trailing, prior)
      guard generation == loadGeneration else { return }
      trailingWeekUsers = trailingUsers
      priorWeekUsers = priorUsers
    } catch {
      // Cancelled (navigation away / remount): keep the prior trend values, mirroring the other
      // loads. A genuine one-window failure is swallowed inside `uniqueUsers` (returns `nil`),
      // which hides the trend rather than reaching here.
    }
  }

  private func clearDisplayState() {
    programmingHealth = nil
    nowUniqueUsers = nil
    weekUniqueUsers = nil
    monthUniqueUsers = nil
    trailingWeekUsers = nil
    priorWeekUsers = nil
    listenerBuckets = []
  }

  private func uniqueUsers(
    token: String, stationId: String, airtime: Date, endTime: Date?
  ) async throws -> Int? {
    do {
      return try await api.getActiveListeningSessions(token, stationId, airtime, endTime)
        .summary.uniqueUsers
    } catch {
      guard !isCancellation(error) else { throw error }
      await analytics.track(
        .apiError(endpoint: "getActiveListeningSessions", error: error.localizedDescription))
      return nil
    }
  }

  private func loadListenerCounts(token: String, stationId: String, generation: Int) async {
    let range = Self.listenerCountsDateRange(now: now)
    do {
      let buckets = try await api.getListenerCounts(
        token, stationId, range.startDate, range.endDate
      ).buckets
      guard generation == loadGeneration else { return }
      listenerBuckets = buckets
    } catch {
      guard !isCancellation(error) else { return }
      guard generation == loadGeneration else { return }
      listenerBuckets = []
      await analytics.track(
        .apiError(endpoint: "getListenerCounts", error: error.localizedDescription))
    }
  }

  /// A cancelled `.task` auto-cancels the in-flight request (Alamofire surfaces
  /// `AFError.explicitlyCancelled`, so `Task.isCancelled` is already set). Treat that as a
  /// non-event: don't clear loaded state, alert, or record an API error for a navigation away.
  private func isCancellation(_ error: any Error) -> Bool {
    Task.isCancelled || error is CancellationError
  }

  private static func statValue(_ count: Int?) -> String {
    count.map(String.init) ?? "—"
  }

  private static func monthDayLabel(_ bucketStart: String) -> String {
    let parts = bucketStart.split(separator: "-")
    guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else {
      return bucketStart
    }
    return "\(month)/\(day)"
  }

  private func ringColor(for status: ProgrammingHealthStatus?) -> Color {
    switch status {
    case .healthy: return Color(hex: "#34C759")
    case .warning: return Color(hex: "#FFC107")
    case .unhealthy: return .playolaRed
    case .unknown, .none: return Color(hex: "#999999")
    }
  }

  private func statusLabel(for status: ProgrammingHealthStatus?) -> String {
    switch status {
    case .healthy: return "Your station is in good shape"
    case .warning: return "Your station could use a little attention"
    case .unhealthy: return "Your station needs some attention"
    case .unknown, .none: return "Station health isn't available yet"
    }
  }

  /// Client-owned title per known check kind. The server no longer sends display copy, so the
  /// client composes it — this is what keeps unknown kinds hidden rather than shown with an
  /// empty/garbled label.
  private static func title(forKind kind: String) -> String {
    switch kind {
    case "appearances": return "Make DJ appearances"
    case "songCategoryFreshness": return "Keep song categories fresh"
    case "breakerCategoryFreshness": return "Keep breaker categories fresh"
    case "pendingListenerQuestions": return "Answer listener questions"
    default: return kind
    }
  }

  /// Client-owned subtitle per known check kind and its progress, following the per-kind copy
  /// rules: completion counters ("X of Y[...]") read current/required verbatim (capped display of
  /// `current > required` is intentional, not clamped), while the listener-questions backlog reads
  /// off `current` alone since a required count of 0 would otherwise misleadingly read "0 of 0".
  /// Returns `nil` when there's no progress to describe (title-only row).
  private static func subtitle(for check: ProgrammingHealthCheck) -> String? {
    guard let progress = check.progress else { return nil }
    switch check.kind {
    case "pendingListenerQuestions":
      return progress.current > 0 ? "\(progress.current) waiting" : "All caught up"
    case "appearances":
      return "\(progress.current) of \(progress.required)"
    case "songCategoryFreshness", "breakerCategoryFreshness":
      return "\(progress.current) of \(progress.required) categories fresh"
    default:
      return nil
    }
  }

  /// `0...1` fill for the progress bar. A `required` of `0` makes the fraction undefined, so the
  /// bar is hidden entirely (see `hasProgressBar`) rather than rendered at a meaningless value.
  private static func progressFraction(for check: ProgrammingHealthCheck) -> Double {
    guard let progress = check.progress, progress.required > 0 else { return 0 }
    return min(1, max(0, Double(progress.current) / Double(progress.required)))
  }

  private static func hasProgressBar(for check: ProgrammingHealthCheck) -> Bool {
    guard let progress = check.progress else { return false }
    return progress.required > 0
  }

  private static func icon(forKind kind: String) -> String {
    Self.navigableCheckKinds.contains(kind) ? "bubble.left.and.bubble.right.fill" : "checklist"
  }

  private static func improvementItem(from check: ProgrammingHealthCheck) -> ImprovementItem {
    // Completion is server-owned: `status` is the single source of truth and is never
    // re-derived from `progress` client-side.
    let isComplete = check.status == .healthy
    let title = title(forKind: check.kind)
    let subtitle = subtitle(for: check) ?? ""
    let fraction = progressFraction(for: check)
    let trackColor: Color = hasProgressBar(for: check) ? Color(hex: "#5E5F5F") : .clear
    let isTappable = Self.navigableCheckKinds.contains(check.kind)
    let chevronOpacity: Double = isTappable ? 1 : 0

    if isComplete {
      return ImprovementItem(
        id: check.kind,
        icon: "checkmark",
        iconColor: .black,
        iconBackgroundColor: Color(hex: "#34C759"),
        iconBorderColor: .clear,
        title: title,
        titleColor: Color(hex: "#999999"),
        titleFontName: FontNames.Inter_500_Medium,
        subtitle: subtitle,
        subtitleColor: Color(hex: "#34C759"),
        progress: 1,
        progressColor: Color(hex: "#34C759"),
        progressTrackColor: trackColor,
        chevronOpacity: chevronOpacity,
        isTappable: isTappable)
    }

    return ImprovementItem(
      id: check.kind,
      icon: icon(forKind: check.kind),
      iconColor: Color(hex: "#C7C7C7"),
      iconBackgroundColor: .black,
      iconBorderColor: Color(hex: "#999999"),
      title: title,
      titleColor: .white,
      titleFontName: FontNames.Inter_600_SemiBold,
      subtitle: subtitle,
      subtitleColor: Color(hex: "#999999"),
      progress: fraction,
      progressColor: .playolaRed,
      progressTrackColor: trackColor,
      chevronOpacity: chevronOpacity,
      isTappable: isTappable)
  }
}

// MARK: - Alerts

extension PlayolaAlert {
  static func stationHealthError(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }
}
