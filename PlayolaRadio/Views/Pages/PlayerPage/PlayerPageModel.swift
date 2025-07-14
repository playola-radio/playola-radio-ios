//
//  PlayerPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/16/25.
//

import SwiftUI
import Combine
import PlayolaPlayer

@MainActor
@Observable
class PlayerPageModel: ViewModel {
  var cancellables: Set<AnyCancellable> = []
  
  // MARK: State
  var nowPlayingText: String = ""
  var primaryNavBarTitle: String = ""
  var secondaryNavBarTitle: String = ""
  var stationArtUrl: URL?
  var previouslyPlayingStation: RadioStation?
  var loadingPercentage: Float = 1.0
  var playolaSpinPlaying: Spin? {
    didSet {
      self.playolaAudioBlockPlaying = playolaSpinPlaying?.audioBlock
      setRelatedText(playolaSpinPlaying)
    }
  }
  
  var playolaAudioBlockPlaying: AudioBlock?
  
  var relatedText: RelatedText?
  
  // MARK: Callbacks
  var onDismiss: (() -> Void)?
  
  // Unused for now
  var albumArtUrl: URL?
  
  enum PlayerButtonImageName: String {
    case play = "play.fill"
    case stop = "stop.fill"
  }
  
  var playerButtonImageName = PlayerButtonImageName.stop
  
  @ObservationIgnored var stationPlayer: StationPlayer
  
  init(stationPlayer: StationPlayer? = nil, onDismiss: (() -> Void)? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
    self.onDismiss = onDismiss
  }
  
  func viewAppeared() {
    processNewStationState(stationPlayer.state)
    stationPlayer.$state.sink { self.processNewStationState($0) }.store(in: &cancellables)
  }
  
  func setRelatedText(_ currentSpin: Spin?) {
    guard let currentSpin else {
      self.relatedText = nil
      return
    }
    if let transcription = currentSpin.audioBlock.transcription {
      self.relatedText = .init(title: "Why I chose this song", body: transcription)
    } else if let relatedTexts = currentSpin.relatedTexts?.randomElement() {
      self.relatedText = relatedTexts
    } else {
      self.relatedText = nil
    }
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
      self.playolaSpinPlaying = state.playolaSpinPlaying
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
      self.playolaSpinPlaying = state.playolaSpinPlaying
    case .stopped:
      albumArtUrl = nil
      nowPlayingText = ""
      self.playerButtonImageName = .play
      self.playolaSpinPlaying = nil
    case .error:
      primaryNavBarTitle = ""
      secondaryNavBarTitle = ""
      nowPlayingText = "Error Playing Station"
      albumArtUrl = nil
      self.playerButtonImageName = .play
      self.playolaSpinPlaying = nil
    case let .startingNewStation(radioStation):
      primaryNavBarTitle = radioStation.name
      secondaryNavBarTitle = radioStation.desc
      nowPlayingText = ""
      albumArtUrl = URL(string: radioStation.imageURL)
      self.previouslyPlayingStation = radioStation
      self.playerButtonImageName = .stop
      self.playolaSpinPlaying = state.playolaSpinPlaying
    }
  }
  
  func playPauseButtonTapped() {
    // compared with `!=`.  Use pattern matching instead.
    switch stationPlayer.state.playbackStatus {
    case .stopped:
      // If it's currently stopped, start playing.
      if let station = self.previouslyPlayingStation {
        stationPlayer.play(station: station)
      }
    default:
      stationPlayer.stop()
      onDismiss?()
    }
  }
}
