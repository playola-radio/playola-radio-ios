//
//  ArtistDashboardPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import Dependencies
import Sharing
import SwiftUI

// NOTE: The Station Health ring / "Improve your station" checklist come from `getStationHealthScore`;
// the Listeners stat cards come from `getActiveListeningSessions` (one call per card); the 6-week
// chart comes from `getListenerCounts`. Only the Weekly Report header trend ("↑ 12%") remains a
// hard-coded placeholder pending the percent-change deltas fast-follow.
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
  }

  // MARK: - State

  private var stationHealth: StationHealth?
  private var nowUniqueUsers: Int?
  private var weekUniqueUsers: Int?
  private var monthUniqueUsers: Int?
  private var listenerBuckets: [ListenerCountsResponse.Bucket] = []
  var isLoading = false
  var presentedAlert: PlayolaAlert?

  // MARK: - Properties

  var navigationTitle: String { "Dashboard" }

  var weeklyReportLabel: String { "Weekly report" }
  var weeklyReportTrendLabel: String { "↑ 12%" }
  var weeklyReportTrendColor: Color { Color(hex: "#34C759") }

  var healthSectionTitle: String { "STATION HEALTH" }
  var healthScoreLabel: String { stationHealth?.score.map(String.init) ?? "—" }
  var healthRingProgress: Double {
    stationHealth?.score.map { min(1, max(0, Double($0) / 100)) } ?? 0
  }
  var healthRingColor: Color { ringColor(for: stationHealth?.band) }
  var healthStatusLabel: String { statusLabel(for: stationHealth?.band) }

  var listenersSectionTitle: String { "LISTENERS" }

  var stats: [Stat] {
    [
      Stat(id: "now", value: Self.statValue(nowUniqueUsers), label: "NOW"),
      Stat(id: "this-week", value: Self.statValue(weekUniqueUsers), label: "THIS WEEK"),
      Stat(id: "this-month", value: Self.statValue(monthUniqueUsers), label: "THIS MONTH"),
    ]
  }

  var chartSectionTitle: String { "LAST 6 WEEKS" }
  var chartLinkLabel: String { "Stats ›" }

  var weekBars: [WeekBar] {
    let maxUsers = listenerBuckets.map { max(0, $0.uniqueUsers) }.max() ?? 0
    return listenerBuckets.map { bucket in
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

  var improveCountLabel: String {
    let done = stationHealth?.completedTaskCount ?? 0
    let total = stationHealth?.tasks.count ?? 0
    return "\(done) OF \(total) DONE"
  }

  var improveCountColor: Color { Color(hex: "#34C759") }

  var improvementItems: [ImprovementItem] {
    (stationHealth?.sortedTasks ?? []).map(Self.improvementItem(from:))
  }

  // MARK: - User Actions

  func viewAppeared() async {
    guard let token = auth.jwt, let stationId else { return }
    isLoading = true
    defer { isLoading = false }
    async let health: Void = loadHealthScore(token: token, stationId: stationId)
    async let listeners: Void = loadListenerStats(token: token, stationId: stationId)
    async let counts: Void = loadListenerCounts(token: token, stationId: stationId)
    _ = await (health, listeners, counts)
  }

  func weeklyReportTapped() {}

  func statsLinkTapped() {}

  func improvementItemTapped(_ item: ImprovementItem) {}

  // MARK: - Private Helpers

  private var stationId: String? {
    if case .broadcasting(let stationId) = navigationCoordinator.appMode {
      return stationId
    }
    return nil
  }

  private func loadHealthScore(token: String, stationId: String) async {
    do {
      stationHealth = try await api.getStationHealthScore(token, stationId)
    } catch {
      guard !isCancellation(error) else { return }
      stationHealth = nil
      presentedAlert = .stationHealthError(error.localizedDescription)
      await analytics.track(
        .apiError(endpoint: "getStationHealthScore", error: error.localizedDescription))
    }
  }

  private func loadListenerStats(token: String, stationId: String) async {
    let referenceNow = now
    let startOfToday = calendar.startOfDay(for: referenceNow)
    let endOfYesterday = startOfToday
    let weekStart = calendar.date(byAdding: .day, value: -7, to: endOfYesterday) ?? endOfYesterday
    let monthStart = calendar.date(byAdding: .day, value: -30, to: endOfYesterday) ?? endOfYesterday

    async let nowCount = uniqueUsers(
      token: token, stationId: stationId, airtime: startOfToday, endTime: referenceNow)
    async let weekCount = uniqueUsers(
      token: token, stationId: stationId, airtime: weekStart, endTime: endOfYesterday)
    async let monthCount = uniqueUsers(
      token: token, stationId: stationId, airtime: monthStart, endTime: endOfYesterday)

    nowUniqueUsers = await nowCount
    weekUniqueUsers = await weekCount
    monthUniqueUsers = await monthCount
  }

  private func uniqueUsers(
    token: String, stationId: String, airtime: Date, endTime: Date?
  ) async -> Int? {
    do {
      return try await api.getActiveListeningSessions(token, stationId, airtime, endTime)
        .summary.uniqueUsers
    } catch {
      guard !isCancellation(error) else { return nil }
      await analytics.track(
        .apiError(endpoint: "getActiveListeningSessions", error: error.localizedDescription))
      return nil
    }
  }

  private func loadListenerCounts(token: String, stationId: String) async {
    do {
      listenerBuckets = try await api.getListenerCounts(token, stationId).buckets
    } catch {
      guard !isCancellation(error) else { return }
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

  private func ringColor(for band: StationHealthBand?) -> Color {
    switch band {
    case .good: return Color(hex: "#34C759")
    case .fair: return Color(hex: "#FFC107")
    case .attention: return .playolaRed
    case .unavailable, .unknown, .none: return Color(hex: "#999999")
    }
  }

  private func statusLabel(for band: StationHealthBand?) -> String {
    switch band {
    case .good: return "Your station is in good shape"
    case .fair: return "Your station could use a little attention"
    case .attention: return "Your station needs some attention"
    case .unavailable, .unknown, .none: return "Station health isn't available yet"
    }
  }

  private static func improvementItem(from task: StationHealthTask) -> ImprovementItem {
    let isComplete = task.progress?.isComplete ?? false
    let subtitle = task.progress?.label ?? ""
    let fraction = task.progress?.fraction ?? 0
    // Contract: a task with no progress shows no subtitle or bar. Since the view has no
    // control flow, an absent progress hides the bar by making its track transparent.
    let trackColor: Color = task.progress == nil ? .clear : Color(hex: "#5E5F5F")

    if isComplete {
      return ImprovementItem(
        id: task.key,
        icon: "checkmark",
        iconColor: .black,
        iconBackgroundColor: Color(hex: "#34C759"),
        iconBorderColor: .clear,
        title: task.label,
        titleColor: Color(hex: "#999999"),
        titleFontName: FontNames.Inter_500_Medium,
        subtitle: subtitle,
        subtitleColor: Color(hex: "#34C759"),
        progress: 1,
        progressColor: Color(hex: "#34C759"),
        progressTrackColor: trackColor)
    }

    return ImprovementItem(
      id: task.key,
      icon: icon(forFactorKey: task.factorKey),
      iconColor: Color(hex: "#C7C7C7"),
      iconBackgroundColor: .black,
      iconBorderColor: Color(hex: "#999999"),
      title: task.label,
      titleColor: .white,
      titleFontName: FontNames.Inter_600_SemiBold,
      subtitle: subtitle,
      subtitleColor: Color(hex: "#999999"),
      progress: fraction,
      progressColor: .playolaRed,
      progressTrackColor: trackColor)
  }

  /// Presentation-only icon per factor. The server never sends an icon; a sensible default keeps
  /// new factors rendering without a contract change.
  private static func icon(forFactorKey key: String) -> String {
    switch key {
    case "appearances": return "bubble.left.and.bubble.right.fill"
    default: return "checklist"
    }
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
