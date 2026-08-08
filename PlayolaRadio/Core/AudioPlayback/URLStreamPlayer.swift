//
//  URLStreamPlayer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Combine
import Dependencies
import FRadioPlayer
import Foundation

@MainActor
public class URLStreamPlayer: ObservableObject {
  var urlStreamReporter: UrlStreamListeningSessionReporter?
  struct State: Sendable, Equatable {
    static func == (lhs: URLStreamPlayer.State, rhs: URLStreamPlayer.State)
      -> Bool
    {
      lhs.playerStatus == rhs.playerStatus
        && lhs.playbackState == rhs.playbackState
        && lhs.currentStation == rhs.currentStation
        && lhs.nowPlaying == rhs.nowPlaying
    }

    var playbackState: FRadioPlayer.PlaybackState
    var playerStatus: FRadioPlayer.State?
    public var currentStation: UrlStation?
    var nowPlaying: FRadioPlayer.Metadata?
  }

  @Published var state: URLStreamPlayer.State = State(
    playbackState: .stopped,
    playerStatus: nil,
    currentStation: nil,
    nowPlaying: nil)

  @Published var albumArtworkURL: URL?

  @Published private(set) var currentStation: UrlStation?

  var searchedStations: [UrlStation] = []

  private let player = FRadioPlayer.shared

  init() {
    addObserverToPlayer()
    self.urlStreamReporter = UrlStreamListeningSessionReporter(urlStreamPlayer: self)
  }

  func addObserverToPlayer() {
    player.addObserver(self)
  }

  func fetch(completion: (([StationList]) -> Void)? = nil) {
    completion?([])
  }

  func set(station: UrlStation?) {
    guard let station else {
      reset()
      return
    }

    currentStation = station
    player.radioURL = URL(string: station.streamUrl)
  }

  /// Starts a URL stream and waits until the player reports either audible playback or failure.
  /// Returning before one of those outcomes would let callers treat an unreachable stream as
  /// successfully handled.
  func play(station: UrlStation) async -> Bool {
    @Dependency(\.continuousClock) var clock

    return await withCheckedContinuation { continuation in
      let attempt = URLPlaybackAttempt(continuation: continuation)
      attempt.cancellable = $state.sink { state in
        guard state.currentStation?.id == station.id else { return }

        if state.playbackState == .playing {
          attempt.resolve(true)
        } else if state.playerStatus == .error {
          attempt.resolve(false)
        }
      }

      attempt.timeoutTask = Task {
        do {
          try await clock.sleep(for: .seconds(10))
        } catch {
          return
        }
        attempt.resolve(false)
      }

      set(station: station)
    }
  }

  public func reset() {
    currentStation = nil
    player.radioURL = nil
  }

  /// Pauses the URL stream for an interruption/route loss. The app's
  /// AudioSessionCoordinator owns the session and decides when this happens;
  /// the vendored FRadioPlayer no longer self-handles interruptions.
  func pause() {
    player.pause()
  }

  /// Resumes the URL stream after an interruption. The caller reactivates the
  /// session first.
  func resume() {
    player.play()
  }
}

@MainActor
private final class URLPlaybackAttempt {
  var cancellable: AnyCancellable?
  var timeoutTask: Task<Void, Never>?
  private var continuation: CheckedContinuation<Bool, Never>?

  init(continuation: CheckedContinuation<Bool, Never>) {
    self.continuation = continuation
  }

  func resolve(_ started: Bool) {
    guard let continuation else { return }
    self.continuation = nil
    cancellable = nil
    timeoutTask?.cancel()
    timeoutTask = nil
    continuation.resume(returning: started)
  }
}

// MARK: - FRadioPlayerObserver

extension URLStreamPlayer: @preconcurrency FRadioPlayerObserver {
  public func radioPlayer(
    _: FRadioPlayer, metadataDidChange _: FRadioPlayer.Metadata?
  ) {
    state = State(
      playbackState: FRadioPlayer.shared.playbackState,
      playerStatus: FRadioPlayer.shared.state,
      currentStation: currentStation,
      nowPlaying: player.currentMetadata)
  }

  // URLStreamPlayer only publishes metadata; NowPlayingUpdater is the single
  // writer of the system Now Playing info center. `$albumArtworkURL` feeds the
  // in-app now-playing UI (via StationPlayer); the lock screen uses station
  // artwork by design. See SingleNowPlayingWriterTests.
  public func radioPlayer(_: FRadioPlayer, artworkDidChange artworkURL: URL?) {
    albumArtworkURL = artworkURL
  }

  public func radioPlayer(
    _: FRadioPlayer, playerStateDidChange _: FRadioPlayer.State
  ) {
    state = State(
      playbackState: FRadioPlayer.shared.playbackState,
      playerStatus: FRadioPlayer.shared.state,
      currentStation: currentStation,
      nowPlaying: player.currentMetadata)
  }

  public func radioPlayer(
    _: FRadioPlayer, playbackStateDidChange _: FRadioPlayer.PlaybackState
  ) {
    state = State(
      playbackState: FRadioPlayer.shared.playbackState,
      playerStatus: FRadioPlayer.shared.state,
      currentStation: currentStation,
      nowPlaying: player.currentMetadata)
  }
}

extension URLStreamPlayer {
  static var mock: URLStreamPlayer {
    let stationPlayer = URLStreamPlayer()
    stationPlayer.state = State(
      playbackState: .playing,
      playerStatus: .readyToPlay,
      nowPlaying: FRadioPlayer.Metadata(
        artistName: "Rachel Loy",
        trackName: "Selfie",
        rawValue: nil,
        groups: []
      ))
    return stationPlayer
  }
}

// MARK: - Dependency

extension URLStreamPlayer: @preconcurrency DependencyKey {
  public static let liveValue = URLStreamPlayer()
  public static var testValue: URLStreamPlayer { URLStreamPlayer() }
}

extension DependencyValues {
  var urlStreamPlayer: URLStreamPlayer {
    get { self[URLStreamPlayer.self] }
    set { self[URLStreamPlayer.self] = newValue }
  }
}
