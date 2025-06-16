//
//  PlayerPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/16/25.
//

import SwiftUI
import Combine

@MainActor
@Observable
class PlayerPageModel: ViewModel {
  var cancellables: Set<AnyCancellable> = []

  // MARK: State
  var nowPlayingText: String = ""
  var primaryNavBarTitle: String = ""
  var secondaryNavBarTitle: String = ""

  // Unused for now
  var albumArtUrl: URL? = nil
  var stationArtUrl: URL? = nil


  @ObservationIgnored var stationPlayer: StationPlayer

  init(stationPlayer: StationPlayer? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
  }

  func viewAppeared() {
    processNewStationState(stationPlayer.state)
    stationPlayer.$state.sink { self.processNewStationState($0) }.store(in: &cancellables)
  }

  func processNewStationState(_ state: StationPlayer.State) {
    switch state.playbackStatus {
    case let .playing(radioStation):
      if let titlePlaying = state.titlePlaying, let artistPlaying = state.artistPlaying {
        nowPlayingText = "\(titlePlaying) / \(artistPlaying)"
      } else {
        nowPlayingText = ""
      }
      albumArtUrl = state.albumArtworkUrl
      stationArtUrl = URL(string: radioStation.imageURL)
    case let .loading(radioStation, progress):
      primaryNavBarTitle = radioStation.name
      secondaryNavBarTitle = radioStation.desc
      if let progress {
        nowPlayingText = "Station Loading... \(Int(round(progress * 100)))%"
      } else {
        nowPlayingText = "Station Loading..."
      }
      albumArtUrl = URL(string: radioStation.imageURL)
    case .stopped:
      albumArtUrl = nil
      nowPlayingText = ""
    case .error:
      primaryNavBarTitle = ""
      secondaryNavBarTitle = ""
      nowPlayingText = "Error Playing Station"
      albumArtUrl = nil
    case let .startingNewStation(radioStation):
      primaryNavBarTitle = radioStation.name
      secondaryNavBarTitle = radioStation.desc
      nowPlayingText = ""
      albumArtUrl = URL(string: radioStation.imageURL)
    }
  }
}
