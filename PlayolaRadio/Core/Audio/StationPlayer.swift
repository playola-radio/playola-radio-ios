//
//  StationPlayer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//
import Combine
import FRadioPlayer
import Foundation
import PlayolaPlayer
import Sharing

@MainActor
class StationPlayer: ObservableObject {
  var disposeBag: Set<AnyCancellable> = Set()

  enum PlaybackStatus: Codable, Equatable {
    case startingNewStation(AnyStation)
    case playing(AnyStation)
    case stopped
    case loading(AnyStation, Float? = nil)
    case error
  }

  struct State {
    var playbackStatus: PlaybackStatus
    var artistPlaying: String?
    var titlePlaying: String?
    var albumArtworkUrl: URL?
    var playolaSpinPlaying: Spin?
  }

  @Published var state = State(playbackStatus: .stopped)
  let authProvider: PlayolaTokenProvider = .init()

  /// The currently playing radio station, if any
  public var currentStation: AnyStation? {
    switch state.playbackStatus {
    case .startingNewStation(let station):
      return station
    case .playing(let station):
      return station
    case .loading(let station, _):
      return station
    case .error, .stopped:
      return nil
    }
  }

  static let shared = StationPlayer()

  // MARK: Dependencies

  var urlStreamPlayer: URLStreamPlayer
  var playolaStationPlayer: PlayolaStationPlayer

  init(
    urlStreamPlayer: URLStreamPlayer? = nil,
    playolaStationPlayer: PlayolaStationPlayer? = nil
  ) {
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

    self.playolaStationPlayer.configure(
      authProvider: authProvider, baseURL: Config.shared.baseUrl
    )
  }

  // MARK: Public Interface

  /// Starts playing the specified station
  /// - Parameter station: The station to play
  public func play(station: AnyStation) {
    guard currentStation != station else { return }
    stop()
    state = State(playbackStatus: .startingNewStation(station))
    state = State(playbackStatus: .loading(station))

    switch station {
    case .url(let urlStation):
      urlStreamPlayer.set(station: urlStation)
    case .playola(let playolaStation):
      urlStreamPlayer.reset()
      Task { try? await playolaStationPlayer.play(stationId: playolaStation.id) }
    }
  }

  /// Stops the currently playing station
  public func stop() {
    urlStreamPlayer.reset()
    playolaStationPlayer.stop()
    state = State(playbackStatus: .stopped)
  }

  func processPlayolaStationPlayerState(
    _ playolaState: PlayolaStationPlayer.State?
  ) {
    switch playolaState {
    case .idle:
      state = .init(
        playbackStatus: .stopped,
        artistPlaying: nil,
        titlePlaying: nil,
        albumArtworkUrl: nil,
        playolaSpinPlaying: nil
      )
    case .loading(let progress):
      guard let currentStation else { return }
      state = .init(
        playbackStatus: .loading(currentStation, progress),
        artistPlaying: nil,
        titlePlaying: nil,
        albumArtworkUrl: nil,
        playolaSpinPlaying: nil
      )
    case .playing(let nowPlaying):
      if let currentStation {
        state = .init(
          playbackStatus: .playing(currentStation),
          artistPlaying: nowPlaying.audioBlock.artist,
          titlePlaying: nowPlaying.audioBlock.title,
          albumArtworkUrl: nowPlaying.audioBlock.imageUrl,
          playolaSpinPlaying: nowPlaying
        )
      }
    case .none:
      state = .init(
        playbackStatus: .error,
        artistPlaying: nil,
        titlePlaying: nil,
        albumArtworkUrl: nil,
        playolaSpinPlaying: nil
      )
    }
  }

  private func processUrlStreamStateChanged(
    _ urlStreamPlayerState: URLStreamPlayer.State
  ) {
    switch urlStreamPlayerState.playerStatus {
    case .loading:
      guard let currentStation else {
        // Log error: currentStation is nil while URLStreamPlayer.state.playerStatus is .loading
        return
      }
      state = State(playbackStatus: .loading(currentStation))
    case .loadingFinished, .readyToPlay:
      guard let currentStation else {
        // Log error: currentStation is nil while URLStreamPlayer.state.playerStatus is .loadingFinished
        return
      }
      state = State(
        playbackStatus: .playing(currentStation),
        artistPlaying: urlStreamPlayerState.nowPlaying?.artistName,
        titlePlaying: urlStreamPlayerState.nowPlaying?.trackName,
        albumArtworkUrl: nil
      )
    case .error:
      state = State(playbackStatus: .error)
    case .urlNotSet, .none:
      state = State(playbackStatus: .stopped)
    }
  }

  private func processAlbumArtworkURLChanged(_ albumArtworkURL: URL?) {
    state = State(
      playbackStatus: state.playbackStatus,
      artistPlaying: state.artistPlaying,
      titlePlaying: state.titlePlaying,
      albumArtworkUrl: albumArtworkURL,
      playolaSpinPlaying: state.playolaSpinPlaying
    )
  }
}

// MARK: - AudioBlockProvider Protocol

protocol AudioBlockProvider {
  var audioBlock: AudioBlock? { get }
}
