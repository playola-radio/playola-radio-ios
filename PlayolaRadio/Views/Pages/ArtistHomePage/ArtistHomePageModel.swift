//
//  ArtistHomePageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import SwiftUI

// NOTE: All display values are hard-coded placeholders while the 3-tab artist IA
// display is being built out. Real data wiring comes in a follow-up PR.
@MainActor
@Observable
class ArtistHomePageModel: ViewModel {

  // MARK: - Types

  struct ImprovementItem: Identifiable {
    let id: String
    let icon: String
    let iconTint: Color
    let title: String
    let subtitle: String
  }

  // MARK: - Properties

  var stationName: String { "Reckless Radio" }

  var onAirLabel: String { "ON AIR NOW" }
  var broadcastStatusLabel: String { "Auto DJ" }
  var broadcastStatusColor: Color { Color(hex: "#34C759") }
  var nowPlayingTitle: String { "Cheat On Your Man" }
  var nowPlayingSubtitle: String { "Bri Bagwell · up next: My Boots" }
  var nowPlayingProgress: Double { 0.52 }
  var lastWentLiveLabel: String { "Last went live 4 days ago" }
  var manageBroadcastLabel: String { "Manage broadcast" }

  var improveSectionTitle: String { "IMPROVE YOUR STATION" }
  var improvementCountLabel: String { "5" }

  var improvementItems: [ImprovementItem] {
    [
      ImprovementItem(
        id: "answer-question",
        icon: "bubble.left",
        iconTint: .playolaRed,
        title: "Answer Sarah's question",
        subtitle: "0:24 · 2 minutes ago"
      ),
      ImprovementItem(
        id: "approve-song-request",
        icon: "music.note",
        iconTint: Color(hex: "#C7C7C7"),
        title: "Approve a song request",
        subtitle: "“Neon Moon” · from Tyler"
      ),
      ImprovementItem(
        id: "ama-show",
        icon: "calendar",
        iconTint: Color(hex: "#C7C7C7"),
        title: "AMA show Saturday",
        subtitle: "7:00 PM · reminder set"
      ),
      ImprovementItem(
        id: "record-intros",
        icon: "mic",
        iconTint: Color(hex: "#C7C7C7"),
        title: "Record 12 missing intros",
        subtitle: "Songs without your voice up front"
      ),
      ImprovementItem(
        id: "add-songs",
        icon: "music.note",
        iconTint: Color(hex: "#C7C7C7"),
        title: "Add 8 songs to your library",
        subtitle: "More variety keeps listeners longer"
      ),
    ]
  }

  var showsLinkTitle: String { "Shows" }
  var musicLibraryLinkTitle: String { "Music Library" }

  // MARK: - User Actions

  func manageBroadcastTapped() {}

  func improvementItemTapped(_ item: ImprovementItem) {}

  func showsRowTapped() {}

  func musicLibraryRowTapped() {}
}
