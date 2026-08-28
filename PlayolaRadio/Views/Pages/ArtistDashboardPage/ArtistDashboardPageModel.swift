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

  // MARK: - Properties

  var navigationTitle: String { "Dashboard" }

  var healthScoreLabel: String { "92" }
  var healthRingProgress: Double { 0.92 }
  var healthRingColor: Color { Color(hex: "#34C759") }
  var healthStatusLabel: String { "In good shape" }
  var healthWeakestLabel: String { "Weakest: intro coverage · 12 songs missing intros" }

  var stats: [Stat] {
    [
      Stat(id: "listeners-now", value: "23", label: "LISTENERS NOW"),
      Stat(id: "listener-hours", value: "11h 20m", label: "LISTENER HOURS"),
      Stat(id: "new-this-week", value: "6", label: "NEW THIS WEEK"),
    ]
  }

  var reportRowTitle: String { "This week" }
  var reportTrendLabel: String { "↑ 12%" }
  var reportTrendColor: Color { Color(hex: "#34C759") }

  // MARK: - User Actions

  func thisWeekReportTapped() {}
}
