//
//  ArtistStationPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import SwiftUI

// NOTE: All display values are hard-coded placeholders while the 3-tab artist IA
// display is being built out. Real data wiring comes in a follow-up PR.
@MainActor
@Observable
class ArtistStationPageModel: ViewModel {

  // MARK: - Properties

  var navigationTitle: String { "Station" }
  var stationName: String { "Reckless Radio" }

  var onAirLabel: String { "ON AIR NOW" }
  var broadcastStatusLabel: String { "Auto DJ" }
  var broadcastStatusColor: Color { Color(hex: "#34C759") }
  var nowPlayingTitle: String { "Cheat On Your Man" }
  var nowPlayingSubtitle: String { "Bri Bagwell · up next: My Boots" }
  var nowPlayingProgress: Double { 0.52 }
  var lastWentLiveLabel: String { "Last went live 4 days ago" }
  var broadcastSettingsLabel: String { "Broadcast settings" }

  var showsLinkTitle: String { "Shows" }
  var musicLibraryLinkTitle: String { "Music Library" }
  var scheduleLinkTitle: String { "Schedule" }

  // MARK: - User Actions

  func broadcastSettingsTapped() {}

  func showsRowTapped() {}

  func musicLibraryRowTapped() {}

  func scheduleRowTapped() {}
}
