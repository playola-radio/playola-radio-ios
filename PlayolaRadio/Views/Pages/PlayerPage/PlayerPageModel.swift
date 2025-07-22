//
//  PlayerPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/16/25.
//

import Combine
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class PlayerPageModel: ViewModel {
  var cancellables: Set<AnyCancellable> = []

  // MARK: State
  @ObservationIgnored @Shared(.nowPlaying) var nowPlaying: NowPlaying?
  var nowPlayingText: String {
    switch nowPlaying?.playbackStatus {
    case .playing:
      if let titlePlaying = nowPlaying?.titlePlaying, let artistPlaying = nowPlaying?.artistPlaying
      {
        return "\(titlePlaying) - \(artistPlaying)"
      } else {
        return ""
      }
    case .loading, .startingNewStation:
      return "Station Loading..."
    case .stopped:
      return ""
    case .error:
      return "Error Playing Station"
    case .none:
      return ""
    }
  }
  var primaryNavBarTitle: String {
    guard let currentStation = nowPlaying?.currentStation else { return "" }
    switch nowPlaying?.playbackStatus {
    case .loading, .startingNewStation:
      return currentStation.name
    default:
      return ""
    }
  }

  var secondaryNavBarTitle: String {
    guard let currentStation = nowPlaying?.currentStation else { return "" }
    switch nowPlaying?.playbackStatus {
    case .loading, .startingNewStation:
      return currentStation.desc
    default:
      return ""
    }
  }

  var stationArtUrl: URL? {
    guard let currentStation = nowPlaying?.currentStation else { return nil }
    switch nowPlaying?.playbackStatus {
    case .playing, .loading, .startingNewStation:
      return URL(string: currentStation.imageURL)
    default:
      return nil
    }
  }

  var previouslyPlayingStation: RadioStation? {
    nowPlaying?.currentStation
  }

  var loadingPercentage: Float {
    switch nowPlaying?.playbackStatus {
    case let .loading(_, progress):
      return progress ?? 0.0
    case .startingNewStation:
      return 0.0
    default:
      return 1.0
    }
  }

  var playolaSpinPlaying: Spin? {
    nowPlaying?.playolaSpinPlaying
  }

  var playolaAudioBlockPlaying: AudioBlock? {
    playolaSpinPlaying?.audioBlock
  }

  var relatedText: RelatedText? {
    guard let currentSpin = playolaSpinPlaying else { return nil }
    guard _chosenRelatedText.1 != currentSpin.id else {
      return _chosenRelatedText.0
    }
    if let transcription = currentSpin.audioBlock.transcription {
      return RelatedText(title: "Why I chose this song", body: transcription)
    } else if let relatedText = currentSpin.relatedTexts?.randomElement() {
      _chosenRelatedText = (relatedText, currentSpin.id)
      return relatedText
    } else {
      return nil
    }
  }

  var _chosenRelatedText: (RelatedText?, String) = (nil, "")

  // MARK: Callbacks
  var onDismiss: (() -> Void)?

  var albumArtUrl: URL? {
    nowPlaying?.albumArtworkUrl
  }

  enum PlayerButtonImageName: String {
    case play = "play.fill"
    case stop = "stop.fill"
  }

  var playerButtonImageName: PlayerButtonImageName {
    switch nowPlaying?.playbackStatus {
    case .stopped, .error:
      return .play
    default:
      return .stop
    }
  }

  @ObservationIgnored var stationPlayer: StationPlayer

  init(stationPlayer: StationPlayer? = nil, onDismiss: (() -> Void)? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
    self.onDismiss = onDismiss
  }

  func viewAppeared() {
    // No longer needed - all properties are computed from nowPlaying
  }

  func playPauseButtonTapped() {
    stationPlayer.stop()
    onDismiss?()
  }
}
