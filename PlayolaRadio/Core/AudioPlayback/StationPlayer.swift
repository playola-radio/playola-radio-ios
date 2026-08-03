//
//  StationPlayer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//
import Combine
import Dependencies
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
  @ObservationIgnored @Shared(.nowPlaying) var nowPlaying

  enum PlaybackStatus: Codable, Equatable {
    case startingNewStation(AnyStation)
    case playing(AnyStation)
    case paused(AnyStation)
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
  @Published var isSeeking = false
  let authProvider: PlayolaTokenProvider = .init()

  /// True only while playback is paused because the coordinator told us to
  /// (interruption / route loss). Gates auto-resume so we never resume after the
  /// user explicitly stopped, and never double-resume on repeated events.
  private var pausedBySystem = false

  /// Monotonic supersession token. `play()`/`resume()` claim a fresh token via
  /// `beginPlaybackAttempt()`; `stop()` bumps it to invalidate anything in
  /// flight. Because session activation now suspends off the main actor, an
  /// attempt can be superseded mid-flight (a stop, or a *same-station* replay);
  /// each attempt re-checks its token after every suspension so a stale one can't
  /// start a backend or clobber newer state. Station equality alone can't tell
  /// two attempts for the same station apart.
  private var playToken = 0

  /// Claims and returns a fresh token for a new playback attempt.
  private func beginPlaybackAttempt() -> Int {
    playToken += 1
    return playToken
  }

  /// The currently playing radio station, if any
  public var currentStation: AnyStation? {
    switch state.playbackStatus {
    case .startingNewStation(let station):
      return station
    case .playing(let station):
      return station
    case .paused(let station):
      return station
    case .loading(let station, _):
      return station
    case .error, .stopped:
      return nil
    }
  }

  // MARK: Dependencies

  var urlStreamPlayer: URLStreamPlayer
  var playolaStationPlayer: any PlayolaTransport
  let audioSessionCoordinator: AudioSessionCoordinator
  private var activePlaybackAttempt: StationPlaybackAttempt?

  // The Combine subscriptions below capture `self` weakly so the cancellable
  // owned by this StationPlayer is the only thing keeping each subscription
  // alive. Without `[weak self]` the disposeBag/closure/self cycle would keep
  // replaced players alive past instance lifetime — which matters once
  // StationPlayer is a dependency-injected service.
  init(
    urlStreamPlayer: URLStreamPlayer? = nil,
    playolaStationPlayer: (any PlayolaTransport)? = nil,
    audioSessionCoordinator: AudioSessionCoordinator? = nil
  ) {
    @Dependency(\.urlStreamPlayer) var injectedUrlStreamPlayer
    @Dependency(\.audioSessionCoordinator) var injectedCoordinator
    self.urlStreamPlayer = urlStreamPlayer ?? injectedUrlStreamPlayer
    self.playolaStationPlayer = playolaStationPlayer ?? PlayolaStationPlayer.shared
    self.audioSessionCoordinator = audioSessionCoordinator ?? injectedCoordinator

    self.urlStreamPlayer.$state
      .sink { [weak self] state in
        self?.processUrlStreamStateChanged(state)
      }
      .store(in: &disposeBag)

    self.urlStreamPlayer.$albumArtworkURL
      .sink { [weak self] url in
        self?.processAlbumArtworkURLChanged(url)
      }
      .store(in: &disposeBag)

    self.playolaStationPlayer.statePublisher
      .sink { [weak self] state in
        self?.processPlayolaStationPlayerState(state)
      }
      .store(in: &disposeBag)

    self.playolaStationPlayer.configure(
      authProvider: self.authProvider, baseURL: Config.shared.baseUrl)

    // Become the interruption/route delegate LAST — after the subscriptions and
    // SDK configure are in place — so an interruption arriving mid-init can't
    // drive pause/resume before global state is coherent.
    self.audioSessionCoordinator.delegate = self
  }

  // MARK: Public Interface

  /// Starts playing the specified station
  /// - Parameter station: The station to play
  /// - Returns: Whether playback started successfully
  @discardableResult
  public func play(station: AnyStation) async -> Bool {
    if case .playing(let currentStation) = state.playbackStatus,
      currentStation == station
    {
      return true
    }

    if let activePlaybackAttempt,
      activePlaybackAttempt.station == station
    {
      return await activePlaybackAttempt.waitForResult()
    }

    stop()
    let token = beginPlaybackAttempt()
    state = State(playbackStatus: .startingNewStation(station))
    state = State(playbackStatus: .loading(station))

    let playbackAttempt = StationPlaybackAttempt(station: station)
    activePlaybackAttempt = playbackAttempt

    // The app now owns the AVAudioSession: activate it BEFORE either backend.
    // The SDK no longer activates the session, so without this the SDK's
    // engine.start() would throw deep in playback. A config failure must surface
    // as .error, not be swallowed.
    do {
      try await audioSessionCoordinator.configureForPlayback()
    } catch {
      // Activation hops off the main actor (see AudioSessionCoordinator), so this
      // method suspended above and a stop()/play() may have superseded it. Only
      // surface the failure if this attempt still owns the token — a stale
      // failure must not clobber the newer station or a deliberate stop.
      if token == playToken { handlePlayFailure(error) }
      return finishPlaybackAttempt(playbackAttempt, started: false)
    }

    // Bail if superseded during the activation suspension, before starting a
    // backend the user no longer wants.
    guard token == playToken else {
      return finishPlaybackAttempt(playbackAttempt, started: false)
    }

    let started: Bool
    switch station {
    case .url(let urlStation):
      started = await urlStreamPlayer.play(station: urlStation)
    case .playola(let playolaStation):
      urlStreamPlayer.reset()
      do {
        try await playolaStationPlayer.play(stationId: playolaStation.id)
        started = true
      } catch {
        // The SDK play() also suspends; guard the failure the same way so a
        // stale throw can't clobber newer state. A stale *success* is left
        // alone: the superseding stop()/play() has already re-driven the SDK
        // (single-station), so tearing down here could kill the newer attempt.
        if token == playToken { handlePlayFailure(error) }
        started = false
      }
    }

    return finishPlaybackAttempt(playbackAttempt, started: started)
  }

  private func finishPlaybackAttempt(
    _ playbackAttempt: StationPlaybackAttempt,
    started: Bool
  ) -> Bool {
    if activePlaybackAttempt === playbackAttempt {
      activePlaybackAttempt = nil
    }
    playbackAttempt.resolve(with: started)
    return started
  }

  // internal for testability
  /// Surfaces a failed station start as a recoverable error state. Without this,
  /// a swallowed failure (e.g. the schedule endpoint returning 500 during an
  /// outage) leaves the player stuck on `.loading` forever, with no error shown
  /// and no recovery — which pushes users into a manual retry storm.
  ///
  /// Both representations of playback state are updated: `state` (which drives
  /// the lock screen via `NowPlayingUpdater`) and `@Shared(.nowPlaying)` (the
  /// app-wide source of truth the in-app UI reads). The shared state would
  /// otherwise stay `.loading`, because it is only driven by
  /// `playolaStationPlayer.$state`, which does not emit when `play()` throws.
  ///
  /// `CancellationError` is ignored: it means a newer `play()`/`stop()` already
  /// superseded this attempt and owns the current state.
  func handlePlayFailure(_ error: Error) {
    if error is CancellationError { return }
    state = State(playbackStatus: .error)
    $nowPlaying.withLock { $0 = NowPlaying(playbackStatus: .error) }
  }

  /// Stops the currently playing station
  public func stop() {
    // Invalidate any in-flight play()/resume() so a superseded attempt resuming
    // from its activation await can't restart a backend or clobber .stopped.
    playToken += 1
    pausedBySystem = false
    urlStreamPlayer.reset()
    playolaStationPlayer.stop()
    state = State(playbackStatus: .stopped)
  }

  /// Pauses whichever backend is active (driven by interruptions / route loss).
  /// Routes Playola through the SDK's pauseForInterruption(); URL stations
  /// through the vendored player. No-op when nothing is playing.
  func pause() {
    switch currentStation {
    case .some(.playola): playolaStationPlayer.pauseForInterruption()
    case .some(.url): urlStreamPlayer.pause()
    case .none: break
    }
  }

  /// Resumes the active backend after an interruption. We own the session now,
  /// so reactivate it first; a failure surfaces as .error via handlePlayFailure.
  func resume() async {
    // Clearing here also covers the manual lock-screen resume path, so a stale
    // interruption-ended event can't trigger a second resume.
    pausedBySystem = false
    // Snapshot the station and claim a token: activation hops off the main actor
    // (see AudioSessionCoordinator), so this method suspends below. If a stop()
    // or another play()/resume() lands in that window, this resume is stale and
    // must not reactivate/resume against state the user has moved on from.
    guard let station = currentStation else { return }
    let token = beginPlaybackAttempt()
    do {
      try await audioSessionCoordinator.configureForPlayback()
      guard token == playToken else { return }
      switch station {
      case .playola: try await playolaStationPlayer.resumeAfterInterruption()
      case .url: urlStreamPlayer.resume()
      }
    } catch {
      if token == playToken { handlePlayFailure(error) }
    }
  }

  /// Seeks to the next station in the artist list, wrapping around if at the end
  public func seekNext() async {
    let stations = seekableStations()
    guard !stations.isEmpty else { return }

    isSeeking = true
    defer { isSeeking = false }

    guard let current = currentStation,
      let currentIndex = stations.firstIndex(where: { $0.id == current.id })
    else {
      await play(station: stations[0])
      return
    }

    let nextIndex = (currentIndex + 1) % stations.count
    await play(station: stations[nextIndex])
  }

  /// Seeks to the previous station in the artist list, wrapping around if at the beginning
  public func seekPrevious() async {
    let stations = seekableStations()
    guard !stations.isEmpty else { return }

    isSeeking = true
    defer { isSeeking = false }

    guard let current = currentStation,
      let currentIndex = stations.firstIndex(where: { $0.id == current.id })
    else {
      await play(station: stations[0])
      return
    }

    let previousIndex = (currentIndex - 1 + stations.count) % stations.count
    await play(station: stations[previousIndex])
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
    _ playolaState: PlayolaStationPlayer.State?
  ) {
    // Backend ownership: the Playola backend only owns global playback state
    // while a Playola station is active (or nothing is). While a URL station is
    // active, ignore all Playola events — a late/stale `.idle` (emitted by
    // `stop()` while switching), `.error`, `.loading`, or `.playing` would
    // otherwise clobber the active URL station. Real stops are driven by
    // `stop()`, which sets `.stopped` explicitly.
    if case .url = currentStation { return }
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

    // `.paused` is published by the SDK when the host pauses playback for an
    // interruption (phone call, Siri, route loss). Keep the interrupted spin's
    // metadata so the lock screen keeps showing what was playing and offers a
    // play button to resume.
    case .paused(let spin):
      if let currentStation {
        state = .init(
          playbackStatus: .paused(currentStation),
          artistPlaying: spin.audioBlock.artist,
          titlePlaying: spin.audioBlock.title,
          albumArtworkUrl: spin.audioBlock.imageUrl,
          playolaSpinPlaying: spin
        )
      }

    // `.error` is PlayolaPlayer 0.19.0's terminal failure (e.g. the schedule
    // fetch exhausted its retries); `.none` is an unexpected empty state. Both
    // surface the recoverable `.error` state so the user sees the error and can
    // tap play again to retry.
    case .error, .none:
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
    // Backend ownership: the URL backend only owns global playback state while a
    // URL station is active (or nothing is). While a Playola station is active,
    // ignore all URL events — a late `.urlNotSet` (FRadioPlayer's response to the
    // `urlStreamPlayer.reset()` that every Playola play performs), or a stale
    // `.readyToPlay`/`.error`, would otherwise clobber the active Playola station
    // (e.g. dismissing CarPlay's Now Playing, or mislabeling it with URL
    // metadata). Real stops are driven by `stop()`, which sets `.stopped`.
    if case .playola = currentStation { return }
    // A URL stream paused for an interruption: FRadioPlayer reports
    // playbackState == .paused while playerStatus stays .loadingFinished, so map
    // it to .paused here instead of letting the playerStatus switch below report
    // .playing with a rate of 1.0.
    if urlStreamPlayerState.playbackState == .paused, let currentStation {
      state = State(
        playbackStatus: .paused(currentStation),
        artistPlaying: urlStreamPlayerState.nowPlaying?.artistName,
        titlePlaying: urlStreamPlayerState.nowPlaying?.trackName,
        albumArtworkUrl: state.albumArtworkUrl  // keep artwork across the pause
      )
      return
    }
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

// MARK: - AudioInterruptionDelegate

extension StationPlayer: AudioInterruptionDelegate {
  /// The coordinator detected an interruption begin or a personal-listening
  /// route loss. Arm auto-resume only for interruptions (`shouldAutoResume`);
  /// a route loss requires manual resume (lock-screen play), so we do not arm
  /// the flag and a later unrelated `.shouldResume` cannot restart it.
  func audioSessionShouldPause(shouldAutoResume: Bool) {
    // Only arm auto-resume when we were actively playing. If we are already
    // paused (e.g. a prior route loss that requires manual resume), a later
    // interruption must not flip the flag back on — otherwise its `.shouldResume`
    // would restart audio that route-loss recovery deliberately left paused.
    let wasActivelyPlaying: Bool
    switch state.playbackStatus {
    case .playing, .loading, .startingNewStation:
      wasActivelyPlaying = true
    case .paused, .stopped, .error:
      wasActivelyPlaying = false
    }
    pausedBySystem = shouldAutoResume && wasActivelyPlaying
    pause()
  }

  /// The coordinator says the interruption ended with `.shouldResume`. Only
  /// resume if the system paused us (not if the user stopped meanwhile) — which
  /// also guards against double-resume on repeated events.
  func audioSessionShouldResume() {
    guard pausedBySystem else { return }
    pausedBySystem = false
    Task { @MainActor in
      // Re-check on the next turn: if the user switched stations or stopped
      // between the interruption ending and this Task running, we are no longer
      // paused and must not resume a superseded station/backend. Also bail if a
      // second interruption re-armed pausedBySystem before this Task ran —
      // resuming during an active interruption would silence the wrong session.
      guard case .paused = self.state.playbackStatus, !self.pausedBySystem else { return }
      await self.resume()
    }
  }
}

// MARK: - PlayolaTransport

/// Minimal transport seam over the PlayolaPlayer SDK so `StationPlayer` can be
/// driven by a spy in tests (the SDK type is a concrete `@MainActor` class that
/// is awkward to fake directly). Conformed by `PlayolaStationPlayer` below.
@MainActor
protocol PlayolaTransport: AnyObject {
  var statePublisher: AnyPublisher<PlayolaStationPlayer.State, Never> { get }
  func configure(authProvider: PlayolaAuthenticationProvider, baseURL: URL)
  func play(stationId: String) async throws
  func stop()
  func pauseForInterruption()
  func resumeAfterInterruption() async throws
}

extension PlayolaStationPlayer: PlayolaTransport {
  var statePublisher: AnyPublisher<PlayolaStationPlayer.State, Never> {
    $state.eraseToAnyPublisher()
  }
  func play(stationId: String) async throws {
    try await play(stationId: stationId, atDate: nil)
  }
}

@MainActor
private final class StationPlaybackAttempt {
  let station: AnyStation
  private var continuations: [CheckedContinuation<Bool, Never>] = []

  init(station: AnyStation) {
    self.station = station
  }

  func waitForResult() async -> Bool {
    await withCheckedContinuation { continuation in
      continuations.append(continuation)
    }
  }

  func resolve(with result: Bool) {
    let continuations = continuations
    self.continuations = []
    for continuation in continuations {
      continuation.resume(returning: result)
    }
  }
}

// MARK: - AudioBlockProvider Protocol
protocol AudioBlockProvider {
  var audioBlock: AudioBlock? { get }
}

// MARK: - Dependency

extension StationPlayer: @preconcurrency DependencyKey {
  static let liveValue = StationPlayer()
  static var testValue: StationPlayer { StationPlayer() }
}

extension DependencyValues {
  var stationPlayer: StationPlayer {
    get { self[StationPlayer.self] }
    set { self[StationPlayer.self] = newValue }
  }
}
