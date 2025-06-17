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
  var stationArtUrl: URL? = nil
  var previouslyPlayingStation: RadioStation? = nil
  var loadingPercentage: Float = 1.0


  // Unused for now
  var albumArtUrl: URL? = nil


  enum PlayerButtonImageName: String {
    case play = "play.fill"
    case stop = "stop.fill"
  }

  var playerButtonImageName = PlayerButtonImageName.stop

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
        nowPlayingText = "\(titlePlaying) - \(artistPlaying)"
      } else {
        nowPlayingText = ""
      }
      albumArtUrl = state.albumArtworkUrl
      stationArtUrl = URL(string: radioStation.imageURL)
      self.playerButtonImageName = .stop
      self.previouslyPlayingStation = radioStation
      self.loadingPercentage = 1.0
    case let .loading(radioStation, progress):
      primaryNavBarTitle = radioStation.name
      secondaryNavBarTitle = radioStation.desc
      nowPlayingText = "Station Loading..."
      if let progress {
        self.loadingPercentage = progress
      }
      albumArtUrl = URL(string: radioStation.imageURL)
      self.playerButtonImageName = .stop
      self.previouslyPlayingStation = radioStation
    case .stopped:
      albumArtUrl = nil
      nowPlayingText = ""
      self.playerButtonImageName = .play
    case .error:
      primaryNavBarTitle = ""
      secondaryNavBarTitle = ""
      nowPlayingText = "Error Playing Station"
      albumArtUrl = nil
      self.playerButtonImageName = .play
    case let .startingNewStation(radioStation):
      primaryNavBarTitle = radioStation.name
      secondaryNavBarTitle = radioStation.desc
      nowPlayingText = ""
      albumArtUrl = URL(string: radioStation.imageURL)
      self.previouslyPlayingStation = radioStation
      self.playerButtonImageName = .stop
    }
  }

  func playPauseButtonTapped() {
    // compared with `!=`.  Use pattern matching instead.
    switch stationPlayer.state.playbackStatus {
    case .stopped:
      // If it’s currently stopped, start playing.
      if let station = self.previouslyPlayingStation {
        stationPlayer.play(station: station)
      }
    default:
      stationPlayer.stop()
    }
  }
}
