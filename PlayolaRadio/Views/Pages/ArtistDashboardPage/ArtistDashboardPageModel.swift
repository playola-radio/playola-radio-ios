//
//  ArtistDashboardPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import SwiftUI

// NOTE: All display values are hard-coded placeholders while the 3-tab artist IA
// display is being built out. Real data wiring comes in a follow-up PR.
@MainActor
@Observable
class ArtistDashboardPageModel: ViewModel {

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
  }

  // MARK: - Properties

  var navigationTitle: String { "Dashboard" }

  var weeklyReportLabel: String { "Weekly report" }
  var weeklyReportTrendLabel: String { "↑ 12%" }
  var weeklyReportTrendColor: Color { Color(hex: "#34C759") }

  var healthSectionTitle: String { "STATION HEALTH" }
  var healthScoreLabel: String { "92" }
  var healthRingProgress: Double { 0.92 }
  var healthRingColor: Color { Color(hex: "#34C759") }
  var healthStatusLabel: String { "Your station is in good shape" }

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
  var improveCountLabel: String { "1 OF 5 DONE" }
  var improveCountColor: Color { Color(hex: "#34C759") }

  var improvementItems: [ImprovementItem] {
    [
      ImprovementItem(
        id: "record-intros",
        icon: "mic",
        iconColor: .playolaRed,
        iconBackgroundColor: .black,
        iconBorderColor: Color(hex: "#999999"),
        title: "Record 12 missing intros",
        titleColor: .white,
        titleFontName: FontNames.Inter_600_SemiBold,
        subtitle: "4 of 12 intros recorded",
        subtitleColor: Color(hex: "#999999"),
        progress: 4.0 / 12.0,
        progressColor: .playolaRed
      ),
      ImprovementItem(
        id: "approve-song-request",
        icon: "music.note",
        iconColor: Color(hex: "#C7C7C7"),
        iconBackgroundColor: .black,
        iconBorderColor: Color(hex: "#999999"),
        title: "Approve a song request",
        titleColor: .white,
        titleFontName: FontNames.Inter_600_SemiBold,
        subtitle: "0 of 1 request reviewed",
        subtitleColor: Color(hex: "#999999"),
        progress: 0,
        progressColor: .playolaRed
      ),
      ImprovementItem(
        id: "ama-show",
        icon: "calendar",
        iconColor: Color(hex: "#C7C7C7"),
        iconBackgroundColor: .black,
        iconBorderColor: Color(hex: "#999999"),
        title: "AMA show Saturday",
        titleColor: .white,
        titleFontName: FontNames.Inter_600_SemiBold,
        subtitle: "2 of 3 setup steps ready",
        subtitleColor: Color(hex: "#999999"),
        progress: 2.0 / 3.0,
        progressColor: .playolaRed
      ),
      ImprovementItem(
        id: "add-songs",
        icon: "music.note",
        iconColor: Color(hex: "#C7C7C7"),
        iconBackgroundColor: .black,
        iconBorderColor: Color(hex: "#999999"),
        title: "Add 8 songs to your library",
        titleColor: .white,
        titleFontName: FontNames.Inter_600_SemiBold,
        subtitle: "3 of 8 songs added",
        subtitleColor: Color(hex: "#999999"),
        progress: 3.0 / 8.0,
        progressColor: .playolaRed
      ),
      ImprovementItem(
        id: "answer-question",
        icon: "checkmark",
        iconColor: .black,
        iconBackgroundColor: Color(hex: "#34C759"),
        iconBorderColor: .clear,
        title: "Answer Sarah's question",
        titleColor: Color(hex: "#999999"),
        titleFontName: FontNames.Inter_500_Medium,
        subtitle: "1 of 1 complete · just now",
        subtitleColor: Color(hex: "#34C759"),
        progress: 1.0,
        progressColor: Color(hex: "#34C759")
      ),
    ]
  }

  // MARK: - User Actions

  func weeklyReportTapped() {}

  func statsLinkTapped() {}

  func improvementItemTapped(_ item: ImprovementItem) {}
}
