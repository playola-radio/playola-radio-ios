//
//  StationPlayer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//
import Foundation
import Combine
import FRadioPlayer

class StationPlayer: ObservableObject {
  var disposeBag: Set<AnyCancellable> = Set()
  enum  PlaybackStatus {
    case playing(RadioStation)
    case stopped
    case loading(RadioStation)
    case error
  }

  struct State {
    var playbackStatus: PlaybackStatus
    var artistPlaying: String?
    var titlePlaying: String?
    var albumArtworkUrl: URL?
  }
  @Published var state = State(playbackStatus: .stopped)

  public var currentStation: RadioStation? {
    switch self.state.playbackStatus {
    case .playing(let radioStation), .loading(let radioStation):
      return radioStation
    case .error, .stopped:
      return nil
    }
  }

  static let shared = StationPlayer()

  // MARK: Dependencies
  var urlStreamPlayer: URLStreamPlayer

  init(urlStreamPlayer: URLStreamPlayer? = nil) {
    self.urlStreamPlayer = urlStreamPlayer ?? .shared

    self.urlStreamPlayer.$state.sink(receiveValue: { state in
      self.processUrlStreamStateChanged(state)
    }).store(in: &disposeBag)

    self.urlStreamPlayer.$albumArtworkURL.sink(receiveValue: { url in
      self.processAlbumArtworkURLChanged(url)
    }).store(in: &disposeBag)
  }

  // MARK: Public Interface
  public func play(station: RadioStation) {
    self.state = State(playbackStatus: .loading(station))
    urlStreamPlayer.set(station: station)
  }

  public func stop() {
    urlStreamPlayer.reset()
    self.state = State(playbackStatus: .stopped)
  }

  private func processUrlStreamStateChanged(_ urlStreamPlayerState: URLStreamPlayer.State) {
    switch urlStreamPlayerState.playerStatus {
    case .loading:
      guard let currentStation else {
        print("Error -- currentStation is nil while URLStreamPlayer.state.playerStatus is .loading")
        return
      }
      self.state = State(playbackStatus: .loading(currentStation))
    case .loadingFinished, .readyToPlay:
      guard let currentStation else {
        print("Error -- currentStation is nil while URLStreamPlayer.state.playerStatus is .loadingFinished")
        return
      }
      self.state = State(playbackStatus: .playing(currentStation),
                         artistPlaying: urlStreamPlayerState.nowPlaying?.artistName,
                         titlePlaying: urlStreamPlayerState.nowPlaying?.trackName,
                         albumArtworkUrl: nil)
    case .error:
      self.state = State(playbackStatus: .error)
    case .urlNotSet, .none:
      self.state = State(playbackStatus: .stopped)
    }
  }

  private func processAlbumArtworkURLChanged(_ albumArtworkURL: URL?) {
    self.state = State(
      playbackStatus: self.state.playbackStatus,
      artistPlaying: self.state.artistPlaying,
      titlePlaying: self.state.titlePlaying,
      albumArtworkUrl: albumArtworkURL)
  }
}
