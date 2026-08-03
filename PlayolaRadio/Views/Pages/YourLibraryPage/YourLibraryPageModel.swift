//
//  YourLibraryPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Observation
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class YourLibraryPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.stationPlayer) var stationPlayer
  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.likesManager) var likesManager: LikesManager

  // MARK: - Shared State

  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool

  // MARK: - Sub-Models

  let presetsModel: PresetsModel

  // MARK: - Properties

  var presentedSongActionSheet: SongActionSheet?

  // MARK: - Initialization

  init(presetsModel: PresetsModel = PresetsModel()) {
    self.presetsModel = presetsModel
    super.init()
  }

  // MARK: - View Helpers

  var navigationTitle: String { "Your Library" }
  var likedSongsSectionTitle: String { "Liked Songs" }

  /// All liked songs, newest first (flat — no date grouping).
  var likedSongs: [(AudioBlock, Date)] {
    likesManager.allLikedAudioBlocksWithTimestamps.sorted { $0.1 > $1.1 }
  }

  func formatTimestamp(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
    return formatter.string(from: date)
  }

  // MARK: - User Actions

  func viewAppeared() async {
    await presetsModel.loadPresetsIfNeeded()
  }

  func presetTileTapped(_ display: PresetDisplayItem) async {
    guard !presetsModel.isEditingPresets else { return }

    let item = display.stationItem
    let station = item.anyStation

    // A preset shown as unavailable ("Coming Soon" / inactive) must not attempt
    // playback — mirror the availability guards in StationListModel.stationSelected.
    if item.visibility == .comingSoon && showSecretStations == false { return }
    guard station.active else { return }

    let position = presetsModel.displayPresets.firstIndex(where: { $0.id == display.id }) ?? 0
    await analytics.track(
      .presetTileTapped(
        station: StationInfo(from: station),
        position: position
      ))
    await stationPlayer.play(station: station)
  }

  func songMenuTapped(for audioBlock: AudioBlock, likedDate: Date) {
    presentedSongActionSheet = SongActionSheet(audioBlock: audioBlock, likedDate: likedDate)
  }

  func removeSong(_ audioBlock: AudioBlock) {
    likesManager.unlike(audioBlock)
  }
}
