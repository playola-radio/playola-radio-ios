//
//  StationPlayer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//
import Foundation
import Combine
import FRadioPlayer
import PlayolaPlayer

@MainActor
class StationPlayer: ObservableObject {
  var disposeBag: Set<AnyCancellable> = Set()
  enum  PlaybackStatus {
    case playing(RadioStation)
    case stopped
    case loading(RadioStation, Float? = nil)
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
    case .playing(let radioStation):
      return radioStation
    case .loading(let radioStation, let _):
      return radioStation
    case .error, .stopped:
      return nil
    }
  }

  static let shared = StationPlayer()

  // MARK: Dependencies
  var urlStreamPlayer: URLStreamPlayer
  var playolaStationPlayer: PlayolaStationPlayer
  
  init(urlStreamPlayer: URLStreamPlayer? = nil,
       playolaStationPlayer: PlayolaStationPlayer? = nil) {
    self.urlStreamPlayer = urlStreamPlayer ?? .shared
    self.playolaStationPlayer = playolaStationPlayer ?? .shared

    self.urlStreamPlayer.$state.sink(receiveValue: { state in
      self.processUrlStreamStateChanged(state)
    }).store(in: &disposeBag)

    self.urlStreamPlayer.$albumArtworkURL.sink(receiveValue: { url in
      self.processAlbumArtworkURLChanged(url)
    }).store(in: &disposeBag)

    self.playolaStationPlayer.$state.sink(receiveValue: { state in
      self.processPlayolaStationPlayerState(state)
    }).store(in: &disposeBag)


  }

  // MARK: Public Interface
  public func play(station: RadioStation) {
    guard currentStation != station else { return }
    stop()
    self.state = State(playbackStatus: .loading(station))
    if let _ = station.streamURL {
      urlStreamPlayer.set(station: station)
    } else if let playolaID = station.playolaID {
      urlStreamPlayer.reset()
      Task { try? await playolaStationPlayer.play(stationId: playolaID) }
    }
  }

  public func stop() {
    urlStreamPlayer.reset()
    playolaStationPlayer.stop()
    self.state = State(playbackStatus: .stopped)
  }

  func processPlayolaStationPlayerState(_ playolaState: PlayolaStationPlayer.State?) {
    switch playolaState {
    case .idle:
      self.state = .init(playbackStatus: .stopped, artistPlaying: nil, titlePlaying: nil, albumArtworkUrl: nil)
    case .loading(let progress):
      self.state = .init(playbackStatus: .loading(self.currentStation!, progress), titlePlaying: nil, albumArtworkUrl: nil)
    case .playing(let nowPlaying):
      self.state = .init(playbackStatus: .playing(self.currentStation!),
                         artistPlaying: nowPlaying.artist,
                         titlePlaying: nowPlaying.title,
                         albumArtworkUrl: nowPlaying.imageUrl != nil ? URL(string: nowPlaying.imageUrl!) : nil)
    case .none:
      self.state = .init(playbackStatus: .error)
    }
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
