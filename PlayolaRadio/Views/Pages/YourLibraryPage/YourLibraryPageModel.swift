//
//  YourLibraryPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Observation
import PlayolaPlayer
import SwiftUI

@MainActor
@Observable
class YourLibraryPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.stationPlayer) var stationPlayer
  @ObservationIgnored @Dependency(\.analytics) var analytics

  // MARK: - Sub-Models

  let presetsModel: PresetsModel

  // MARK: - Initialization

  init(presetsModel: PresetsModel = PresetsModel()) {
    self.presetsModel = presetsModel
    super.init()
  }

  // MARK: - View Helpers

  var navigationTitle: String { "Your Library" }

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
}
