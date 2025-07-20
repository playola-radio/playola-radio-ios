//
//  StationPlayer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//

import Combine
import Dependencies
import DependenciesMacros
import FRadioPlayer
import Foundation
import PlayolaPlayer
import Sharing

// MARK: - StationPlayer Types

enum StationPlayerPlaybackStatus {
  case startingNewStation(RadioStation)
  case playing(RadioStation)
  case stopped
  case loading(RadioStation, Float? = nil)
  case error
}

struct StationPlayerState {
  var playbackStatus: StationPlayerPlaybackStatus
  var artistPlaying: String?
  var titlePlaying: String?
  var albumArtworkUrl: URL?
  var playolaSpinPlaying: Spin?

  /// The currently playing radio station, if any
  var currentStation: RadioStation? {
    switch playbackStatus {
    case let .startingNewStation(radioStation):
      return radioStation
    case let .playing(radioStation):
      return radioStation
    case let .loading(radioStation, _):
      return radioStation
    case .error, .stopped:
      return nil
    }
  }
}

// MARK: - StationPlayer Dependency

@DependencyClient
struct StationPlayerClient {
  var statePublisher: AnyPublisher<StationPlayerState, Never> = Empty().eraseToAnyPublisher()
  var play: (RadioStation) async -> Void = { _ in }
  var stop: () async -> Void = {}
  var currentState: () -> StationPlayerState = { StationPlayerState(playbackStatus: .stopped) }
}

extension StationPlayerClient: DependencyKey {
  static let liveValue: Self = {
    let coordinator = StationPlayerCoordinator.shared
    return Self(
      statePublisher: coordinator.$state.eraseToAnyPublisher(),
      play: { station in await coordinator.play(station: station) },
      stop: { await coordinator.stop() },
      currentState: { coordinator.state }
    )
  }()

  static let testValue = Self()
}

extension DependencyValues {
  var stationPlayer: StationPlayerClient {
    get { self[StationPlayerClient.self] }
    set { self[StationPlayerClient.self] = newValue }
  }
}

// MARK: - StationPlayer Coordinator (Internal Implementation)

@MainActor
private class StationPlayerCoordinator: ObservableObject {
  static let shared = StationPlayerCoordinator()

  @Published var state = StationPlayerState(playbackStatus: .stopped)

  private var disposeBag: Set<AnyCancellable> = Set()
  private let authProvider: PlayolaTokenProvider = .init()
  private let urlStreamPlayer: URLStreamPlayer
  private let playolaStationPlayer: PlayolaStationPlayer

  init(
    urlStreamPlayer: URLStreamPlayer? = nil,
    playolaStationPlayer: PlayolaStationPlayer? = nil
  ) {
    self.urlStreamPlayer = urlStreamPlayer ?? .shared
    self.playolaStationPlayer = playolaStationPlayer ?? .shared

    setupObservers()
    configurePlayolaPlayer()
  }

  private func setupObservers() {
    urlStreamPlayer.$state.sink { [weak self] state in
      self?.processUrlStreamStateChanged(state)
    }.store(in: &disposeBag)

    urlStreamPlayer.$albumArtworkURL.sink { [weak self] url in
      self?.processAlbumArtworkURLChanged(url)
    }.store(in: &disposeBag)

    playolaStationPlayer.$state.sink { [weak self] state in
      self?.processPlayolaStationPlayerState(state)
    }.store(in: &disposeBag)
  }

  private func configurePlayolaPlayer() {
    playolaStationPlayer.configure(
      authProvider: authProvider,
      baseURL: Config.shared.baseUrl
    )
  }

  // MARK: - Public Interface

  func play(station: RadioStation) async {
    guard state.currentStation != station else { return }
    await stop()

    state = StationPlayerState(playbackStatus: .startingNewStation(station))
    state = StationPlayerState(playbackStatus: .loading(station))

    if station.streamURL != nil {
      urlStreamPlayer.set(station: station)
    } else if let playolaID = station.playolaID {
      urlStreamPlayer.reset()
      try? await playolaStationPlayer.play(stationId: playolaID)
    }
  }

  func stop() async {
    urlStreamPlayer.reset()
    playolaStationPlayer.stop()
    state = StationPlayerState(playbackStatus: .stopped)
  }

  // MARK: - State Processing

  private func processPlayolaStationPlayerState(_ playolaState: PlayolaStationPlayer.State?) {
    switch playolaState {
    case .idle:
      state = StationPlayerState(
        playbackStatus: .stopped,
        artistPlaying: nil,
        titlePlaying: nil,
        albumArtworkUrl: nil,
        playolaSpinPlaying: nil
      )
    case let .loading(progress):
      guard let currentStation = state.currentStation else { return }
      state = StationPlayerState(
        playbackStatus: .loading(currentStation, progress),
        artistPlaying: nil,
        titlePlaying: nil,
        albumArtworkUrl: nil,
        playolaSpinPlaying: nil
      )
    case let .playing(nowPlaying):
      if let currentStation = state.currentStation {
        state = StationPlayerState(
          playbackStatus: .playing(currentStation),
          artistPlaying: nowPlaying.audioBlock.artist,
          titlePlaying: nowPlaying.audioBlock.title,
          albumArtworkUrl: nowPlaying.audioBlock.imageUrl,
          playolaSpinPlaying: nowPlaying
        )
      }
    case .none:
      state = StationPlayerState(
        playbackStatus: .error,
        artistPlaying: nil,
        titlePlaying: nil,
        albumArtworkUrl: nil,
        playolaSpinPlaying: nil
      )
    }
  }

  private func processUrlStreamStateChanged(_ urlStreamPlayerState: URLStreamPlayer.State) {
    switch urlStreamPlayerState.playerStatus {
    case .loading:
      guard let currentStation = state.currentStation else {
        // Log error: currentStation is nil while URLStreamPlayer.state.playerStatus is .loading
        return
      }
      state = StationPlayerState(playbackStatus: .loading(currentStation))
    case .loadingFinished, .readyToPlay:
      guard let currentStation = state.currentStation else {
        // Log error: currentStation is nil while URLStreamPlayer.state.playerStatus is .loadingFinished
        return
      }
      state = StationPlayerState(
        playbackStatus: .playing(currentStation),
        artistPlaying: urlStreamPlayerState.nowPlaying?.artistName,
        titlePlaying: urlStreamPlayerState.nowPlaying?.trackName,
        albumArtworkUrl: nil
      )
    case .error:
      state = StationPlayerState(playbackStatus: .error)
    case .urlNotSet, .none:
      state = StationPlayerState(playbackStatus: .stopped)
    }
  }

  private func processAlbumArtworkURLChanged(_ albumArtworkURL: URL?) {
    state = StationPlayerState(
      playbackStatus: state.playbackStatus,
      artistPlaying: state.artistPlaying,
      titlePlaying: state.titlePlaying,
      albumArtworkUrl: albumArtworkURL,
      playolaSpinPlaying: state.playolaSpinPlaying
    )
  }
}

// MARK: - Legacy Support (Deprecated)

@MainActor
@available(*, deprecated, message: "Use StationPlayerClient dependency instead")
class StationPlayer: ObservableObject {
  var state: StationPlayerState {
    get { StationPlayerCoordinator.shared.state }
    set { StationPlayerCoordinator.shared.state = newValue }
  }

  var currentStation: RadioStation? {
    StationPlayerCoordinator.shared.state.currentStation
  }

  static let shared = StationPlayer()

  private init() {}

  func play(station: RadioStation) {
    Task { await StationPlayerCoordinator.shared.play(station: station) }
  }

  func stop() {
    Task { await StationPlayerCoordinator.shared.stop() }
  }
}

// MARK: - Backward Compatibility Type Aliases

@available(*, deprecated, renamed: "StationPlayerPlaybackStatus")
typealias PlaybackStatus = StationPlayerPlaybackStatus

@available(*, deprecated, renamed: "StationPlayerState")
typealias State = StationPlayerState

// MARK: - AudioBlockProvider Protocol

protocol AudioBlockProvider {
  var audioBlock: AudioBlock? { get }
}
