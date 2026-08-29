//
//  ArtistDashboardPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import Dependencies
import Sharing
import SwiftUI

// NOTE: The Station Health ring and the "Improve your station" checklist are driven by the live
// `getStationHealthScore` endpoint. The Weekly Report header, Listeners stats, and 6-week chart
// are not part of that endpoint yet and remain hard-coded placeholders.
@MainActor
@Observable
class ArtistDashboardPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics

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
      Stat(id: "now", value: "23", label: "NOW"),
      Stat(id: "this-week", value: "184", label: "THIS WEEK"),
      Stat(id: "this-month", value: "721", label: "THIS MONTH"),
    ]
  }

  var chartSectionTitle: String { "LAST 6 WEEKS" }
  var chartLinkLabel: String { "Stats ›" }

  var weekBars: [WeekBar] {
    [
      WeekBar(
        id: "7/20", label: "7/20", labelColor: .playolaGray,
        labelFontName: FontNames.Inter_500_Medium, labelFontSize: 8,
        barColor: .playolaRed, heightFraction: 22.0 / 39.0),
      WeekBar(
        id: "7/27", label: "7/27", labelColor: .playolaGray,
        labelFontName: FontNames.Inter_500_Medium, labelFontSize: 8,
        barColor: .playolaRed, heightFraction: 30.0 / 39.0),
      WeekBar(
        id: "8/3", label: "8/3", labelColor: .playolaGray,
        labelFontName: FontNames.Inter_500_Medium, labelFontSize: 8,
        barColor: .playolaRed, heightFraction: 26.0 / 39.0),
      WeekBar(
        id: "8/10", label: "8/10", labelColor: .playolaGray,
        labelFontName: FontNames.Inter_500_Medium, labelFontSize: 8,
        barColor: .playolaRed, heightFraction: 1.0),
      WeekBar(
        id: "8/17", label: "8/17", labelColor: .playolaGray,
        labelFontName: FontNames.Inter_500_Medium, labelFontSize: 8,
        barColor: .playolaRed, heightFraction: 34.0 / 39.0),
      WeekBar(
        id: "so-far", label: "SO FAR", labelColor: Color(hex: "#FFC107"),
        labelFontName: FontNames.Inter_700_Bold, labelFontSize: 7,
        barColor: Color(hex: "#FFC107"), heightFraction: 25.0 / 39.0),
    ]
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
    await loadHealthScore()
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

  private func loadHealthScore() async {
    guard let token = auth.jwt, let stationId else { return }
    do {
      stationHealth = try await api.getStationHealthScore(token, stationId)
    } catch {
      await analytics.track(
        .apiError(endpoint: "getStationHealthScore", error: error.localizedDescription))
    }
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
