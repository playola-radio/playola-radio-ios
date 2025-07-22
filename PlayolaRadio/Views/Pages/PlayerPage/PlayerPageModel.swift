//
//  PlayerPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/16/25.
//

import Combine
import PlayolaPlayer
import SwiftUI

@MainActor
@Observable
class PlayerPageModel: ViewModel {
  var cancellables: Set<AnyCancellable> = []

  // MARK: State
  private var _stationPlayerState: StationPlayer.State = StationPlayer.State(
    playbackStatus: .stopped)

  // MARK: Computed Properties
  var nowPlayingText: String {
    switch _stationPlayerState.playbackStatus {
    case .playing:
      if let titlePlaying = _stationPlayerState.titlePlaying,
        let artistPlaying = _stationPlayerState.artistPlaying
      {
        return "\(titlePlaying) - \(artistPlaying)"
      } else {
        return ""
      }
    case .loading:
      return "Station Loading..."
    case .stopped:
      return ""
    case .error:
      return "Error Playing Station"
    case .startingNewStation:
      return ""
    }
  }

  var primaryNavBarTitle: String {
    switch _stationPlayerState.playbackStatus {
    case let .loading(radioStation, _),
      let .startingNewStation(radioStation):
      return radioStation.name
    case .error:
      return ""
    default:
      return previouslyPlayingStation?.name ?? ""
    }
  }

  var secondaryNavBarTitle: String {
    switch _stationPlayerState.playbackStatus {
    case let .loading(radioStation, _),
      let .startingNewStation(radioStation):
      return radioStation.desc
    case .error:
      return ""
    default:
      return previouslyPlayingStation?.desc ?? ""
    }
  }

  var stationArtUrl: URL? {
    switch _stationPlayerState.playbackStatus {
    case let .playing(radioStation):
      return URL(string: radioStation.imageURL)
    default:
      return nil
    }
  }

  var albumArtUrl: URL? {
    switch _stationPlayerState.playbackStatus {
    case .playing:
      return _stationPlayerState.albumArtworkUrl
    case let .loading(radioStation, _),
      let .startingNewStation(radioStation):
      return URL(string: radioStation.imageURL)
    case .stopped, .error:
      return nil
    }
  }

  var loadingPercentage: Float {
    switch _stationPlayerState.playbackStatus {
    case let .loading(_, progress):
      return progress ?? 0.0
    default:
      return 1.0
    }
  }

  var playolaSpinPlaying: Spin? {
    _stationPlayerState.playolaSpinPlaying
  }

  var playolaAudioBlockPlaying: AudioBlock? {
    playolaSpinPlaying?.audioBlock
  }

  var playerButtonImageName: PlayerButtonImageName {
    switch _stationPlayerState.playbackStatus {
    case .stopped, .error:
      return .play
    default:
      return .stop
    }
  }

  // MARK: Mutable State
  var previouslyPlayingStation: RadioStation?
  var relatedText: RelatedText?

  // MARK: Callbacks
  var onDismiss: (() -> Void)?

  enum PlayerButtonImageName: String {
    case play = "play.fill"
    case stop = "stop.fill"
  }

  @ObservationIgnored var stationPlayer: StationPlayer

  init(stationPlayer: StationPlayer? = nil, onDismiss: (() -> Void)? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
    self.onDismiss = onDismiss
  }

  func viewAppeared() {
    _stationPlayerState = stationPlayer.state
    updatePreviouslyPlayingStation()
    setRelatedText(playolaSpinPlaying)

    stationPlayer.$state.sink { [weak self] state in
      self?._stationPlayerState = state
      self?.updatePreviouslyPlayingStation()
      self?.setRelatedText(self?.playolaSpinPlaying)
    }.store(in: &cancellables)
  }

  private func updatePreviouslyPlayingStation() {
    switch _stationPlayerState.playbackStatus {
    case let .playing(radioStation),
      let .loading(radioStation, _),
      let .startingNewStation(radioStation):
      self.previouslyPlayingStation = radioStation
    default:
      break
    }
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

  func playPauseButtonTapped() {
    switch _stationPlayerState.playbackStatus {
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
