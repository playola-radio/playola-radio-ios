//
//  StationPlayer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//
import Combine
import FRadioPlayer
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing

@MainActor
class StationPlayer: ObservableObject {
  var disposeBag: Set<AnyCancellable> = Set()

  // MARK: Shared State

  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList>
  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool

  enum PlaybackStatus: Codable, Equatable {
    case startingNewStation(AnyStation)
    case playing(AnyStation)
    case stopped
    case loading(AnyStation)
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
  @Published var isSeeking = false
  let authProvider: PlayolaTokenProvider = .init()

  /// The currently playing radio station, if any
  public var currentStation: AnyStation? {
    switch state.playbackStatus {
    case .startingNewStation(let station):
      return station
    case .playing(let station):
      return station
    case .loading(let station):
      return station
    case .error, .stopped:
      return nil
    }
  }

  static let shared = StationPlayer()

  // MARK: Dependencies

  var urlStreamPlayer: URLStreamPlayer
  var playolaStationPlayer: StreamingStationPlayer

  init(
    urlStreamPlayer: URLStreamPlayer? = nil,
    playolaStationPlayer: StreamingStationPlayer? = nil
  ) {
    self.urlStreamPlayer = urlStreamPlayer ?? .shared
    self.playolaStationPlayer = playolaStationPlayer ?? StreamingStationPlayer()

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
      authProvider: self.authProvider, baseURL: Config.shared.baseUrl)
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

  /// Seeks to the next station in the artist list, wrapping around if at the end
  public func seekNext() {
    let stations = seekableStations()
    guard !stations.isEmpty else { return }

    isSeeking = true
    defer { isSeeking = false }

    guard let current = currentStation,
      let currentIndex = stations.firstIndex(where: { $0.id == current.id })
    else {
      play(station: stations[0])
      return
    }

    let nextIndex = (currentIndex + 1) % stations.count
    play(station: stations[nextIndex])
  }

  /// Seeks to the previous station in the artist list, wrapping around if at the beginning
  public func seekPrevious() {
    let stations = seekableStations()
    guard !stations.isEmpty else { return }

    isSeeking = true
    defer { isSeeking = false }

    guard let current = currentStation,
      let currentIndex = stations.firstIndex(where: { $0.id == current.id })
    else {
      play(station: stations[0])
      return
    }

    let previousIndex = (currentIndex - 1 + stations.count) % stations.count
    play(station: stations[previousIndex])
  }

  func seekableStations() -> [AnyStation] {
    guard let artistList = stationLists.first(where: { $0.slug == StationList.artistListSlug })
    else {
      return []
    }

    let items = artistList.stationItems(
      includeHidden: showSecretStations,
      includeComingSoon: showSecretStations
    )

    return
      items
      .map { $0.anyStation }
      .filter { $0.active }
  }

  func processPlayolaStationPlayerState(
    _ playolaState: StreamingStationPlayer.State?
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
    case .loading:
      guard let currentStation else { return }
      state = .init(
        playbackStatus: .loading(currentStation),
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
