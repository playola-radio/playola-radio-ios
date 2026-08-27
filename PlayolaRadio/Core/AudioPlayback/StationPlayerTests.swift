//
//  StationPlayerTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//

import AVFoundation
import Combine
import CustomDump
import Dependencies
import FRadioPlayer
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

private struct PlayFailureTestError: Error {}

/// Session double whose `setActive` blocks until the test releases it, so a test
/// can deterministically interleave a `stop()`/`play()` during the off-main
/// activation window without `Task.sleep`. `@unchecked Sendable`: the coordinator
/// runs `setActive` on its serial actor (off-main); the semaphores are the sync
/// primitives that make the hand-off deterministic.
final class GatedAudioSession: AudioSessionProtocol, @unchecked Sendable {
  let entered = DispatchSemaphore(value: 0)
  let proceed = DispatchSemaphore(value: 0)
  private let throwOnActivate: Bool

  init(throwOnActivate: Bool) { self.throwOnActivate = throwOnActivate }

  func setCategory(
    _ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
    policy: AVAudioSession.RouteSharingPolicy, options: AVAudioSession.CategoryOptions
  ) throws {}
  func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
    entered.signal()
    proceed.wait()
    if throwOnActivate { throw AudioSessionConfigError() }
  }
}

/// One-shot async gate: `wait()` suspends until `open()` is called (or returns
/// immediately if already opened). Lets a test hold an async call suspended
/// without blocking a thread.
actor AsyncGate {
  private var opened = false
  private var continuation: CheckedContinuation<Void, Never>?

  func wait() async {
    if opened { return }
    await withCheckedContinuation { continuation = $0 }
  }

  func open() {
    guard !opened else { return }
    opened = true
    continuation?.resume()
    continuation = nil
  }
}

/// PlayolaTransport double whose `play` suspends on an async gate until the test
/// opens it, so a test can interleave a `stop()`/`play()` while the SDK play call
/// is in flight (the second await inside `StationPlayer.play`).
@MainActor
final class GatedPlayolaStationPlayer: PlayolaTransport {
  private let stateSubject = CurrentValueSubject<PlayolaStationPlayer.State, Never>(.idle)
  var statePublisher: AnyPublisher<PlayolaStationPlayer.State, Never> {
    stateSubject.eraseToAnyPublisher()
  }

  /// Signaled (off-actor safe: a `let` Sendable) when `play` has been entered.
  let entered = DispatchSemaphore(value: 0)
  let gate = AsyncGate()
  private let throwOnPlay: Bool
  var playCount = 0
  var outputLatencyCompensation: TimeInterval = 0

  init(throwOnPlay: Bool) { self.throwOnPlay = throwOnPlay }

  func configure(authProvider: PlayolaAuthenticationProvider, baseURL: URL) {}
  func setRenderBackend(_ backend: PlayolaRenderBackend) {}
  func play(stationId: String) async throws {
    playCount += 1
    entered.signal()
    await gate.wait()
    if throwOnPlay { throw PlayFailureTestError() }
  }
  func stop() {}
  func pauseForInterruption() {}
  func resumeAfterInterruption() async throws {}
}

@Suite(.freshSharedState)
@MainActor
struct StationPlayerTests {

  /// Waits (off the main actor) until the gated session's `setActive` has been
  /// entered, i.e. `play()`/`resume()` is suspended inside activation.
  private func awaitActivationInFlight(_ gate: GatedAudioSession) async {
    await withCheckedContinuation { continuation in
      DispatchQueue.global().async {
        gate.entered.wait()
        continuation.resume()
      }
    }
  }

  /// Waits until the gated Playola double's `play` has been entered, i.e.
  /// `StationPlayer.play` is suspended inside the backend (second) await.
  private func awaitBackendPlayInFlight(_ playola: GatedPlayolaStationPlayer) async {
    await withCheckedContinuation { continuation in
      DispatchQueue.global().async {
        playola.entered.wait()
        continuation.resume()
      }
    }
  }

  @Test
  func stopDuringActivationDropsStalePlayBeforeBackendStart() async {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let gate = GatedAudioSession(throwOnActivate: false)
    let coordinator = AudioSessionCoordinator(session: gate)
    let playola = SpyPlayolaStationPlayer()
    let player = StationPlayer(
      playolaStationPlayer: playola, audioSessionCoordinator: coordinator)

    let playTask = Task { await player.play(station: .mockPlayola()) }
    await awaitActivationInFlight(gate)

    // User stops while activation is still in flight.
    player.stop()
    gate.proceed.signal()
    _ = await playTask.value

    // The superseded attempt must not start the backend, and stop wins.
    #expect(playola.playCount == 0)
    guard case .stopped = player.state.playbackStatus else {
      Issue.record("stale play started a backend: \(player.state.playbackStatus)")
      return
    }
  }

  @Test
  func staleActivationFailureDoesNotClobberNewerState() async {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let gate = GatedAudioSession(throwOnActivate: true)
    let coordinator = AudioSessionCoordinator(session: gate)
    let playola = SpyPlayolaStationPlayer()
    let player = StationPlayer(
      playolaStationPlayer: playola, audioSessionCoordinator: coordinator)

    let playTask = Task { await player.play(station: .mockPlayola()) }
    await awaitActivationInFlight(gate)

    // User stops before activation fails; the stale failure must not surface as
    // .error over the deliberate stop.
    player.stop()
    gate.proceed.signal()
    _ = await playTask.value

    guard case .stopped = player.state.playbackStatus else {
      Issue.record("stale activation failure clobbered state: \(player.state.playbackStatus)")
      return
    }
  }

  @Test
  func sameStationReplayDuringActivationDoesNotReviveStaleAttempt() async {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let gate = GatedAudioSession(throwOnActivate: false)
    let coordinator = AudioSessionCoordinator(session: gate)
    let playola = SpyPlayolaStationPlayer()
    let player = StationPlayer(
      playolaStationPlayer: playola, audioSessionCoordinator: coordinator)
    let station = AnyStation.mockPlayola()

    // First attempt suspends inside activation.
    let firstPlay = Task { await player.play(station: station) }
    await awaitActivationInFlight(gate)

    // User stops, then replays the SAME station while the first is still parked.
    player.stop()
    gate.proceed.signal()
    _ = await firstPlay.value

    // Station equality would let the stale first attempt revive; the token must
    // drop it, so only the second (real) attempt reaches the backend.
    let secondPlay = Task { await player.play(station: station) }
    await awaitActivationInFlight(gate)
    gate.proceed.signal()
    _ = await secondPlay.value

    #expect(playola.playCount == 1)
  }

  @Test
  func stalePlayolaPlayFailureDoesNotClobberNewerState() async {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let coordinator = AudioSessionCoordinator(session: SpyAudioSession())
    let playola = GatedPlayolaStationPlayer(throwOnPlay: true)
    let player = StationPlayer(
      playolaStationPlayer: playola, audioSessionCoordinator: coordinator)

    let playTask = Task { await player.play(station: .mockPlayola()) }
    await awaitBackendPlayInFlight(playola)

    // User stops while the SDK play() is suspended; the later throw must not
    // surface .error over the deliberate stop.
    player.stop()
    await playola.gate.open()
    _ = await playTask.value

    guard case .stopped = player.state.playbackStatus else {
      Issue.record("stale SDK-play failure clobbered state: \(player.state.playbackStatus)")
      return
    }
  }

  // MARK: - Session Ownership Tests

  @Test
  func playConfiguresSessionBeforeBackendAndSurfacesFailure() async {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let coordinator = AudioSessionCoordinator(session: FailingAudioSession())
    let playola = SpyPlayolaStationPlayer()
    let player = StationPlayer(
      playolaStationPlayer: playola, audioSessionCoordinator: coordinator)

    await player.play(station: .mockPlayola())

    // The app owns the session now: if activating it fails, play() must surface
    // .error instead of proceeding into a backend that would throw deep inside
    // engine.start().
    guard case .error = player.state.playbackStatus else {
      Issue.record(
        "session-config failure must surface as .error, got \(player.state.playbackStatus)")
      return
    }
    // ...and the backend must never be reached when activation failed.
    #expect(playola.playCount == 0)
  }

  @Test
  func pauseRoutesToActiveBackendAndResumeReactivatesSession() async throws {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let spySession = SpyAudioSession()
    let coordinator = AudioSessionCoordinator(session: spySession)
    let playola = SpyPlayolaStationPlayer()
    let player = StationPlayer(
      playolaStationPlayer: playola, audioSessionCoordinator: coordinator)

    await player.play(station: .mockPlayola())

    player.pause()
    #expect(playola.pauseForInterruptionCount == 1)

    spySession.activations = []
    await player.resume()
    #expect(spySession.activations.contains(true))  // session reactivated first
    #expect(playola.resumeAfterInterruptionCount == 1)
  }

  @Test
  func systemPauseRoutesToActiveBackend() async {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let coordinator = AudioSessionCoordinator(session: SpyAudioSession())
    let playola = SpyPlayolaStationPlayer()
    let player = StationPlayer(
      playolaStationPlayer: playola, audioSessionCoordinator: coordinator)
    await player.play(station: .mockPlayola())

    // The coordinator delegate path pauses the active backend.
    player.audioSessionShouldPause(shouldAutoResume: true)
    #expect(playola.pauseForInterruptionCount == 1)
  }

  @Test
  func systemResumeWithoutSystemPauseIsIgnored() async {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let coordinator = AudioSessionCoordinator(session: SpyAudioSession())
    let playola = SpyPlayolaStationPlayer()
    let player = StationPlayer(
      playolaStationPlayer: playola, audioSessionCoordinator: coordinator)

    // A stray interruption-ended (no prior system pause) must not resume.
    player.audioSessionShouldResume()

    #expect(playola.resumeAfterInterruptionCount == 0)
  }

  @Test
  func interruptionWhileRoutePausedDoesNotArmAutoResume() async {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let coordinator = AudioSessionCoordinator(session: SpyAudioSession())
    let playola = SpyPlayolaStationPlayer()
    let player = StationPlayer(
      playolaStationPlayer: playola, audioSessionCoordinator: coordinator)
    await player.play(station: .mockPlayola())

    // Route loss (headphones unplugged): pause WITHOUT arming auto-resume.
    player.audioSessionShouldPause(shouldAutoResume: false)
    // The backend reports the resulting paused state (as the real SDK would).
    player.processPlayolaStationPlayerState(.paused(.mock))
    guard case .paused = player.state.playbackStatus else {
      Issue.record("expected .paused after route loss, got \(player.state.playbackStatus)")
      return
    }

    // A phone-call interruption then begins while already route-paused. Even
    // though interruptions normally auto-resume, we must NOT re-arm here — route
    // recovery stays manual — so the interruption's .shouldResume is a no-op.
    player.audioSessionShouldPause(shouldAutoResume: true)
    player.audioSessionShouldResume()

    #expect(playola.resumeAfterInterruptionCount == 0)
  }

  // MARK: - Play Failure Tests

  @Test
  func testHandlePlayFailureSetsErrorState() {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .loading(.mock))
    let stationPlayer = StationPlayer()

    stationPlayer.handlePlayFailure(PlayFailureTestError())

    // Both the lock-screen-facing state and the app-wide shared state must move
    // to .error, otherwise in-app UI stays stuck on .loading.
    expectNoDifference(stationPlayer.state.playbackStatus, .error)
    expectNoDifference(nowPlaying?.playbackStatus, .error)
  }

  @Test
  func testHandlePlayFailureIgnoresCancellation() {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .loading(.mock))
    let stationPlayer = StationPlayer()
    stationPlayer.state = StationPlayer.State(playbackStatus: .loading(.mock))

    stationPlayer.handlePlayFailure(CancellationError())

    expectNoDifference(stationPlayer.state.playbackStatus, .loading(.mock))
    expectNoDifference(nowPlaying?.playbackStatus, .loading(.mock))
  }

  // MARK: - Shared Now Playing Writer Tests

  // Phase 3: StationPlayer is the sole writer of `@Shared(.nowPlaying)`, writing
  // it as a projection of the authoritative `state` so the two can't drift.

  @Test
  func stationPlayerIsSoleWriterOfSharedNowPlaying() {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let playolaStation = AnyStation.mockPlayola()
    let stationPlayer = StationPlayer()
    stationPlayer.state = StationPlayer.State(playbackStatus: .loading(playolaStation))

    stationPlayer.processPlayolaStationPlayerState(.playing(.mock))

    expectNoDifference(nowPlaying?.playbackStatus, .playing(playolaStation))
    #expect(nowPlaying?.playolaSpinPlaying?.id == Spin.mock.id)
    #expect(nowPlaying?.artistPlaying == Spin.mock.audioBlock.artist)
  }

  @Test
  func processUrlStreamPlayingWritesSharedNowPlaying() {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let urlStreamPlayer = URLStreamPlayerMock()
    let urlStation = AnyStation.mockUrl()
    let stationPlayer = StationPlayer(urlStreamPlayer: urlStreamPlayer)
    stationPlayer.state = StationPlayer.State(playbackStatus: .loading(urlStation))

    urlStreamPlayer.state = URLStreamPlayer.State(
      playbackState: .playing,
      playerStatus: .readyToPlay,
      currentStation: nil,
      nowPlaying: FRadioPlayer.Metadata(
        artistName: "ICY Artist", trackName: "ICY Track", rawValue: nil, groups: [])
    )

    expectNoDifference(nowPlaying?.playbackStatus, .playing(urlStation))
    #expect(nowPlaying?.artistPlaying == "ICY Artist")
    #expect(nowPlaying?.titlePlaying == "ICY Track")

    // ICY artwork (URL backend) publishes to shared state too — no state/nowPlaying drift.
    let artwork = URL(string: "https://example.com/icy.jpg")
    urlStreamPlayer.albumArtworkURL = artwork
    expectNoDifference(nowPlaying?.albumArtworkUrl, artwork)
  }

  // MARK: - Playola State Processing Tests

  @Test
  func testProcessPlayolaErrorStateSetsRecoverableErrorState() {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .loading(.mock))
    let stationPlayer = StationPlayer()
    stationPlayer.state = StationPlayer.State(playbackStatus: .loading(.mock))

    // PlayolaPlayer 0.19.0's terminal `.error` must surface as the app's
    // recoverable `.error` state, not leave the player stuck on .loading.
    stationPlayer.processPlayolaStationPlayerState(.error(.networkError("boom")))

    expectNoDifference(stationPlayer.state.playbackStatus, .error)
    // Phase 3: sole writer of shared `nowPlaying`, so `.error` reaches the UI too.
    expectNoDifference(nowPlaying?.playbackStatus, .error)
  }

  // MARK: - Backend Ownership Regression Tests

  // Regression for the CarPlay "Now Playing is instantly dismissed" bug.
  //
  // Playing a Playola station calls `urlStreamPlayer.reset()`, which makes
  // FRadioPlayer report `.urlNotSet` asynchronously. That URL-backend event used
  // to clobber the active Playola station's state back to `.stopped`, which
  // CarPlay observed and reacted to by popping Now Playing back to the list.
  // The URL backend must not drive global state while a Playola station is active.

  @Test
  func testUrlStreamUrlNotSetDoesNotClobberLoadingPlayolaStation() {
    let urlStreamPlayer = URLStreamPlayerMock()
    let stationPlayer = StationPlayer(urlStreamPlayer: urlStreamPlayer)
    let playolaStation = AnyStation.mockPlayola()
    stationPlayer.state = StationPlayer.State(playbackStatus: .loading(playolaStation))

    urlStreamPlayer.state = URLStreamPlayer.State(
      playbackState: .stopped,
      playerStatus: .urlNotSet,
      currentStation: nil,
      nowPlaying: nil
    )

    expectNoDifference(stationPlayer.state.playbackStatus, .loading(playolaStation))
  }

  @Test
  func testUrlStreamUrlNotSetDoesNotClobberPlayingPlayolaStation() {
    let playolaStation = AnyStation.mockPlayola()
    let playolaArtwork = URL(string: "https://example.com/playola-spin.jpg")
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(
      albumArtworkUrl: playolaArtwork, playbackStatus: .playing(playolaStation))
    let urlStreamPlayer = URLStreamPlayerMock()
    let stationPlayer = StationPlayer(urlStreamPlayer: urlStreamPlayer)
    stationPlayer.state = StationPlayer.State(playbackStatus: .playing(playolaStation))

    urlStreamPlayer.state = URLStreamPlayer.State(
      playbackState: .stopped,
      playerStatus: .urlNotSet,
      currentStation: nil,
      nowPlaying: nil
    )

    expectNoDifference(stationPlayer.state.playbackStatus, .playing(playolaStation))
    expectNoDifference(nowPlaying?.playbackStatus, .playing(playolaStation))

    // The stale `artworkDidChange(nil)` a Playola play triggers via `reset()` must
    // not clear the Playola station's artwork — the URL-backend ownership guard.
    urlStreamPlayer.albumArtworkURL = nil
    expectNoDifference(nowPlaying?.albumArtworkUrl, playolaArtwork)
  }

  // Covers the brief `.startingNewStation` window between `stop()` and
  // `.loading` during a Playola play — the guard must hold here too, so a future
  // refactor of `currentStation` can't silently reintroduce the clobber.
  @Test
  func testUrlStreamUrlNotSetDoesNotClobberStartingNewPlayolaStation() {
    let urlStreamPlayer = URLStreamPlayerMock()
    let stationPlayer = StationPlayer(urlStreamPlayer: urlStreamPlayer)
    let playolaStation = AnyStation.mockPlayola()
    stationPlayer.state = StationPlayer.State(playbackStatus: .startingNewStation(playolaStation))

    urlStreamPlayer.state = URLStreamPlayer.State(
      playbackState: .stopped,
      playerStatus: .urlNotSet,
      currentStation: nil,
      nowPlaying: nil
    )

    expectNoDifference(stationPlayer.state.playbackStatus, .startingNewStation(playolaStation))
  }

  // Mirror of the above: the Playola backend must not clobber an active URL
  // station. `stop()` emits Playola `.idle` while switching stations, so a URL
  // station's playback could be wiped the same way.
  @Test
  func testPlayolaIdleDoesNotClobberActiveUrlStation() {
    // Also asserts the guard protects shared `nowPlaying` (sole-writer migration).
    let urlStation = AnyStation.mockUrl()
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .playing(urlStation))
    let stationPlayer = StationPlayer()
    stationPlayer.state = StationPlayer.State(playbackStatus: .playing(urlStation))

    stationPlayer.processPlayolaStationPlayerState(.idle)

    expectNoDifference(stationPlayer.state.playbackStatus, .playing(urlStation))
    expectNoDifference(nowPlaying?.playbackStatus, .playing(urlStation))
  }

  // Ownership also covers non-`.stopped` terminal events: an inactive backend's
  // late `.error` must not error out the active station.
  @Test
  func testUrlStreamErrorDoesNotClobberActivePlayolaStation() {
    let urlStreamPlayer = URLStreamPlayerMock()
    let stationPlayer = StationPlayer(urlStreamPlayer: urlStreamPlayer)
    let playolaStation = AnyStation.mockPlayola()
    stationPlayer.state = StationPlayer.State(playbackStatus: .playing(playolaStation))

    urlStreamPlayer.state = URLStreamPlayer.State(
      playbackState: .stopped,
      playerStatus: .error,
      currentStation: nil,
      nowPlaying: nil
    )

    expectNoDifference(stationPlayer.state.playbackStatus, .playing(playolaStation))
  }

  @Test
  func testPlayolaErrorDoesNotClobberActiveUrlStation() {
    let stationPlayer = StationPlayer()
    let urlStation = AnyStation.mockUrl()
    stationPlayer.state = StationPlayer.State(playbackStatus: .playing(urlStation))

    stationPlayer.processPlayolaStationPlayerState(.error(.networkError("boom")))

    expectNoDifference(stationPlayer.state.playbackStatus, .playing(urlStation))
  }

  // MARK: - seekNext Tests

  @Test
  func testSeekNextPlaysNextStation() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    await play(stationPlayer, station: stations[0])

    await seekNext(stationPlayer)

    #expect(stationPlayer.currentStation?.id == stations[1].id)
  }

  @Test
  func testSeekNextWrapsAroundFromLastToFirst() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    await play(stationPlayer, station: stations[2])

    await seekNext(stationPlayer)

    #expect(stationPlayer.currentStation?.id == stations[0].id)
  }

  @Test
  func testSeekNextWithNoCurrentStationPlaysFirst() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations

    await seekNext(stationPlayer)

    #expect(stationPlayer.currentStation?.id == stations[0].id)
  }

  @Test
  func testSeekNextWithEmptyStationListDoesNothing() async {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()

    await seekNext(stationPlayer)

    #expect(stationPlayer.currentStation == nil)
  }

  // MARK: - seekPrevious Tests

  @Test
  func testSeekPreviousPlaysPreviousStation() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    await play(stationPlayer, station: stations[1])

    await seekPrevious(stationPlayer)

    #expect(stationPlayer.currentStation?.id == stations[0].id)
  }

  @Test
  func testSeekPreviousWrapsAroundFromFirstToLast() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    await play(stationPlayer, station: stations[0])

    await seekPrevious(stationPlayer)

    #expect(stationPlayer.currentStation?.id == stations[2].id)
  }

  @Test
  func testSeekPreviousWithNoCurrentStationPlaysFirst() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations

    await seekPrevious(stationPlayer)

    #expect(stationPlayer.currentStation?.id == stations[0].id)
  }

  // MARK: - Station Filtering Tests

  @Test
  func testSeekOnlyUsesArtistListStations() async {
    @Shared(.stationLists) var stationLists = makeArtistAndFmLists()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let artistList = stationLists.first { $0.id == StationList.KnownIDs.artistList.rawValue }!
    let artistStations = artistList.stations

    await play(stationPlayer, station: artistStations[0])
    await seekNext(stationPlayer)

    #expect(stationPlayer.currentStation?.id == artistStations[1].id)
  }

  @Test
  func testSeekSkipsInactiveStations() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithInactiveStation()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let allStations = stationLists.first!.stations

    await play(stationPlayer, station: allStations[0])
    await seekNext(stationPlayer)

    #expect(stationPlayer.currentStation?.id == allStations[2].id)
  }

  @Test
  func testSeekSkipsComingSoonStationsWhenSecretsDisabled() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithComingSoonStation()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let allStations = stationLists.first!.stations

    await play(stationPlayer, station: allStations[0])
    await seekNext(stationPlayer)

    #expect(stationPlayer.currentStation?.id == allStations[2].id)
  }

  @Test
  func testSeekIncludesComingSoonStationsWhenSecretsEnabled() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithComingSoonStation()
    @Shared(.showSecretStations) var showSecretStations = true

    let stationPlayer = StationPlayer()
    let allStations = stationLists.first!.stations

    await play(stationPlayer, station: allStations[0])
    await seekNext(stationPlayer)

    #expect(stationPlayer.currentStation?.id == allStations[1].id)
  }

  // MARK: - seekableStations Tests

  @Test
  func testSeekableStationsReturnsStationsFromArtistList() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let seekable = stationPlayer.seekableStations()

    #expect(seekable.count == 3)
    #expect(seekable[0].id == "station1")
    #expect(seekable[1].id == "station2")
    #expect(seekable[2].id == "station3")
  }

  @Test
  func testSeekableStationsReturnsEmptyWhenNoArtistList() {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let seekable = stationPlayer.seekableStations()

    #expect(seekable.isEmpty)
  }

  @Test
  func testSeekableStationsFiltersInactiveStations() {
    @Shared(.stationLists) var stationLists = makeArtistListWithInactiveStation()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let seekable = stationPlayer.seekableStations()

    #expect(seekable.count == 2)
    #expect(seekable[0].id == "station1")
    #expect(seekable[1].id == "station3")
  }

  @Test
  func testSeekableStationsAccessesSharedState() {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()

    // Verify stationPlayer can see the shared state
    #expect(stationPlayer.stationLists.count == 1, "StationPlayer should see 1 station list")
    #expect(
      stationPlayer.stationLists.first?.slug == "artist-list",
      "StationPlayer should see artist-list slug")
  }

  // MARK: - isSeeking Flag Tests

  @Test
  func testIsSeekingIsFalseByDefault() {
    let stationPlayer = StationPlayer()
    #expect(!stationPlayer.isSeeking)
  }

  @Test
  func testIsSeekingIsFalseAfterSeekNextCompletes() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    await play(stationPlayer, station: stations[0])

    await seekNext(stationPlayer)

    #expect(!stationPlayer.isSeeking, "isSeeking should be false after seek completes")
  }

  @Test
  func testIsSeekingIsFalseAfterSeekPreviousCompletes() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    await play(stationPlayer, station: stations[1])

    await seekPrevious(stationPlayer)

    #expect(!stationPlayer.isSeeking, "isSeeking should be false after seek completes")
  }

  @Test
  func testIsSeekingIsFalseWhenSeekHasNoStations() async {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()

    await seekNext(stationPlayer)

    #expect(!stationPlayer.isSeeking, "isSeeking should remain false when no stations")
  }

  // MARK: - Helper Methods

  @discardableResult
  private func play(_ stationPlayer: StationPlayer, station: AnyStation) async -> Bool {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      await stationPlayer.play(station: station)
    }
  }

  private func seekNext(_ stationPlayer: StationPlayer) async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      await stationPlayer.seekNext()
    }
  }

  private func seekPrevious(_ stationPlayer: StationPlayer) async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      await stationPlayer.seekPrevious()
    }
  }

  private func makeArtistListWithThreeStations() -> IdentifiedArrayOf<StationList> {
    let now = Date()
    let artistList = StationList(
      id: StationList.KnownIDs.artistList.rawValue,
      name: "Artists",
      slug: "artist-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station1", name: "Station 1")
        ),
        APIStationItem(
          sortOrder: 1,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station2", name: "Station 2")
        ),
        APIStationItem(
          sortOrder: 2,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station3", name: "Station 3")
        ),
      ]
    )
    return IdentifiedArray(uniqueElements: [artistList])
  }

  private func makeArtistAndFmLists() -> IdentifiedArrayOf<StationList> {
    let now = Date()
    let artistList = StationList(
      id: StationList.KnownIDs.artistList.rawValue,
      name: "Artists",
      slug: "artist-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "artist1", name: "Artist 1")
        ),
        APIStationItem(
          sortOrder: 1,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "artist2", name: "Artist 2")
        ),
      ]
    )
    let fmList = StationList(
      id: StationList.KnownIDs.fmStationsList.rawValue,
      name: "FM Stations",
      slug: "fm-list",
      hidden: false,
      sortOrder: 1,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "fm1", name: "FM Station 1")
        )
      ]
    )
    return IdentifiedArray(uniqueElements: [artistList, fmList])
  }

  private func makeArtistListWithInactiveStation() -> IdentifiedArrayOf<StationList> {
    let now = Date()
    let artistList = StationList(
      id: StationList.KnownIDs.artistList.rawValue,
      name: "Artists",
      slug: "artist-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station1", name: "Station 1", active: true)
        ),
        APIStationItem(
          sortOrder: 1,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station2", name: "Station 2 (Inactive)", active: false)
        ),
        APIStationItem(
          sortOrder: 2,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station3", name: "Station 3", active: true)
        ),
      ]
    )
    return IdentifiedArray(uniqueElements: [artistList])
  }

  private func makeArtistListWithComingSoonStation() -> IdentifiedArrayOf<StationList> {
    let now = Date()
    let artistList = StationList(
      id: StationList.KnownIDs.artistList.rawValue,
      name: "Artists",
      slug: "artist-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station1", name: "Station 1")
        ),
        APIStationItem(
          sortOrder: 1,
          visibility: .comingSoon,
          station: nil,
          urlStation: makeUrlStation(id: "station2", name: "Station 2 (Coming Soon)")
        ),
        APIStationItem(
          sortOrder: 2,
          visibility: .visible,
          station: nil,
          urlStation: makeUrlStation(id: "station3", name: "Station 3")
        ),
      ]
    )
    return IdentifiedArray(uniqueElements: [artistList])
  }

  private func makeUrlStation(id: String, name: String, active: Bool = true) -> UrlStation {
    UrlStation(
      id: id,
      name: name,
      streamUrl: "https://example.com/stream/\(id)",
      imageUrl: "https://example.com/image/\(id).jpg",
      description: "Description for \(name)",
      website: nil,
      location: nil,
      active: active,
      createdAt: Date(),
      updatedAt: Date()
    )
  }
}
