//
//  YourLibraryPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Observation
import PlayolaPlayer
import SwiftUI

@MainActor
@Observable
class YourLibraryPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.stationPlayer) var stationPlayer
  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.likesManager) var likesManager: LikesManager

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
    let position = presetsModel.displayPresets.firstIndex(where: { $0.id == display.id }) ?? 0
    await analytics.track(
      .presetTileTapped(
        station: StationInfo(from: display.stationItem.anyStation),
        position: position
      ))
    await stationPlayer.play(station: display.stationItem.anyStation)
  }

  func songMenuTapped(for audioBlock: AudioBlock, likedDate: Date) {
    presentedSongActionSheet = SongActionSheet(audioBlock: audioBlock, likedDate: likedDate)
  }

  func removeSong(_ audioBlock: AudioBlock) {
    likesManager.unlike(audioBlock)
  }
}
