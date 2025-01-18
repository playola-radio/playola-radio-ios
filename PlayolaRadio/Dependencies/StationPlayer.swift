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
    case playing
    case stopped
    case loading
  }
  struct State {
    var playbackStatus: PlaybackStatus
    var artistPlaying: String?
    var titlePlaying: String?
    var stationPlaying: RadioStation?
    var albumArtworkUrl: URL?
  }
  var state = State(playbackStatus: .stopped)

  static let shared = StationPlayer()

  // MARK: Dependencies
  var urlStreamPlayer: URLStreamPlayer

  init(urlStreamPlayer: URLStreamPlayer? = nil) {
    self.urlStreamPlayer = urlStreamPlayer ?? .shared

    urlStreamPlayer?.$state.sink(receiveValue: { state in
      self.processUrlStreamStateChanged(state)
    }).store(in: &disposeBag)

    urlStreamPlayer?.$albumArtworkURL.sink(receiveValue: { url in
      self.processAlbumArtworkURLChanged(url)
    }).store(in: &disposeBag)
  }

  // MARK: Public Interface
  public func play(station: RadioStation) {
    self.state = State(playbackStatus: .loading, stationPlaying: station)
    urlStreamPlayer.set(station: station)
  }

  public func stop() {
    urlStreamPlayer.reset()
    self.state = State(playbackStatus: .stopped)
  }

  private func processUrlStreamStateChanged(_ urlStreamPlayerState: URLStreamPlayer.State) {
    self.state = State(
      playbackStatus: self.state.playbackStatus,
      artistPlaying: urlStreamPlayerState.nowPlaying?.artistName,
      titlePlaying: urlStreamPlayerState.nowPlaying?.trackName,
      stationPlaying: urlStreamPlayerState.currentStation,
      albumArtworkUrl: self.state.albumArtworkUrl)
  }

  private func processAlbumArtworkURLChanged(_ albumArtworkURL: URL?) {
    self.state = State(
      playbackStatus: self.state.playbackStatus,
      artistPlaying: self.state.artistPlaying,
      titlePlaying: self.state.titlePlaying,
      stationPlaying: self.state.stationPlaying,
      albumArtworkUrl: albumArtworkURL)
  }
}
