//
//  NowPlayingUpdaterTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/14/25.
//

import CustomDump
import Dependencies
import Foundation
import MediaPlayer
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct NowPlayingUpdaterTests {

  // MARK: - Now Playing Info Cache Tests

  // Regression: the now-playing artwork merge must read from our local copy,
  // never MPNowPlayingInfoCenter.default().nowPlayingInfo (Sentry APPLE-IOS-1C).

  @Test
  func testSetNowPlayingInfoUpdatesLocalCache() {
    let updater = NowPlayingUpdater()

    updater.setNowPlayingInfo([MPMediaItemPropertyTitle: "cached title"])

    #expect(updater.currentNowPlayingInfo[MPMediaItemPropertyTitle] as? String == "cached title")
  }

  @Test
  func testPreservingExistingArtworkCarriesArtworkFromLocalCache() {
    let updater = NowPlayingUpdater()
    let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 10, height: 10)) { _ in UIImage() }
    updater.setNowPlayingInfo([
      MPMediaItemPropertyArtwork: artwork,
      MPMediaItemPropertyTitle: "old title",
    ])

    let merged = updater.preservingExistingArtwork(in: [MPMediaItemPropertyTitle: "new title"])

    #expect(merged[MPMediaItemPropertyTitle] as? String == "new title")
    #expect(merged[MPMediaItemPropertyArtwork] != nil)
  }

  @Test
  func testPreservingExistingArtworkNoOpWhenNoArtworkCached() {
    let updater = NowPlayingUpdater()
    updater.setNowPlayingInfo([MPMediaItemPropertyTitle: "title"])

    let merged = updater.preservingExistingArtwork(in: [MPMediaItemPropertyTitle: "new title"])

    #expect(merged[MPMediaItemPropertyArtwork] == nil)
  }

  // MARK: - Playola State Processing Tests

  // Phase 3: shared `nowPlaying` writing (Playola `.error` recovery, and the
  // cross-backend ownership guards for shared state) moved to `StationPlayer`,
  // the single writer of `@Shared(.nowPlaying)`. Those assertions now live in
  // StationPlayerTests. NowPlayingUpdater is a pure renderer of
  // `stationPlayer.$state` and no longer observes the backends directly.

  @Test
  func testUrlStationWithoutTrackMetadataFallsBackToStationNameAndDescription() {
    let urlStation = AnyStation.mockUrl()  // name "Mock FM", description "Mock FM Station"
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer()
      // Playing URL station whose stream reported no ICY track metadata.
      stationPlayer.state = StationPlayer.State(playbackStatus: .playing(urlStation))
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }

    // Regression (Phase 2): after URLStreamPlayer stopped writing the lock screen
    // directly, NowPlayingUpdater must still fall back to the station's own
    // name/description instead of leaving the lock-screen title/artist blank.
    #expect(updater.currentNowPlayingInfo[MPMediaItemPropertyTitle] as? String == "Mock FM")
    #expect(
      updater.currentNowPlayingInfo[MPMediaItemPropertyArtist] as? String == "Mock FM Station")
  }

  @Test
  func testIsStillCurrentTrueForPlayingStationFalseAfterSwitch() {
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer()
      stationPlayer.state = StationPlayer.State(playbackStatus: .playing(.mock))
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }

    // Artwork that resolves for the current station applies; artwork for a
    // station we've since switched away from is dropped (stale-artwork guard).
    #expect(updater.isStillCurrent(.mock))
    #expect(!updater.isStillCurrent(makeTestStation2()))
  }

  // MARK: - Resume Last Station Tests

  @Test
  func stoppedWithPersistedStationRendersNowPlayingEntry() {
    let station = AnyStation.mockPlayola(name: "Bri's Show", curatorName: "Bri")
    @Shared(.lastPlayedStation) var persisted: LastPlayedStation? =
      LastPlayedStation(station: station)
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer(
        playolaStationPlayer: SpyPlayolaStationPlayer(),
        audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
      // Default state is `.stopped` (currentStation nil): the init `$state` sink
      // fires synchronously and must render the persisted snapshot, not clear.
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }

    // A Stop with a persisted snapshot keeps the Now Playing entry populated (so
    // the lock-screen button stays live) instead of clearing it, and reports rate
    // 0.0 so iOS shows a functional Play button rather than a Pause.
    #expect(!updater.currentNowPlayingInfo.isEmpty)
    #expect(updater.currentNowPlayingInfo[MPMediaItemPropertyTitle] as? String == "Bri's Show")
    #expect(updater.currentNowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 0.0)
  }

  @Test
  func stoppedWithNonPlayolaSnapshotClearsNowPlayingEntry() {
    // Mirror of the resume-boundary guard on the display side: only `.playola`
    // snapshots drive a stopped Now Playing entry, so a stale/corrupt `.url`
    // snapshot must not surface a live lock-screen button for the retiring URL
    // backend. (`.url` is never persisted today; this enforces the invariant.)
    @Shared(.lastPlayedStation) var persisted: LastPlayedStation? =
      LastPlayedStation(station: .mockUrl())
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer(
        playolaStationPlayer: SpyPlayolaStationPlayer(),
        audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }

    #expect(updater.currentNowPlayingInfo.isEmpty)
  }

  @Test
  func handlePlayCommandResumesPersistedStationWhenStopped() {
    @Shared(.lastPlayedStation) var persisted: LastPlayedStation? =
      LastPlayedStation(station: .mockPlayola())
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer(
        playolaStationPlayer: SpyPlayolaStationPlayer(),
        audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }

    // Stopped with a durable snapshot: the play command accepts and restarts it.
    #expect(updater.handlePlayCommand() == .success)
  }

  @Test
  func handlePlayCommandReturnsCommandFailedWhenNoPersistedStation() {
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer(
        playolaStationPlayer: SpyPlayolaStationPlayer(),
        audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }

    // Nothing was ever played: there is genuinely nothing to resume.
    #expect(updater.handlePlayCommand() == .commandFailed)
  }

  @Test
  func handlePlayCommandRefusesNonPlayolaSnapshot() {
    // Only `.playola` is ever persisted, but enforce the invariant at the resume
    // boundary: a stale/corrupt `.url` snapshot must never reach the retiring URL
    // backend via the play command.
    @Shared(.lastPlayedStation) var persisted: LastPlayedStation? =
      LastPlayedStation(station: .mockUrl())
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer(
        playolaStationPlayer: SpyPlayolaStationPlayer(),
        audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }

    #expect(updater.handlePlayCommand() == .commandFailed)
  }

  @Test
  func handlePlayCommandResumesPausedStation() {
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer(
        playolaStationPlayer: SpyPlayolaStationPlayer(),
        audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
      stationPlayer.state = StationPlayer.State(playbackStatus: .paused(.mockPlayola()))
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }

    // Interruption pause: the play command resumes the live backend directly.
    #expect(updater.handlePlayCommand() == .success)
  }

  // MARK: - Analytics Tests

  // MARK: - render_backend plumbing

  /// A StationPlayer whose render backend is locked the way the app locks it:
  /// by actually playing a Playola station through the selection seam.
  private func makePlayerWithLockedBackend() async -> StationPlayer {
    let player = StationPlayer(
      playolaStationPlayer: RenderBackendSpyTransport(),
      audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
    await player.play(station: AnyStation.mockPlayola())
    return player
  }

  @Test
  func testListeningSessionStartedCarriesLockedRenderBackendForPlayolaStation() async {
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = true
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = AnyStation.mockPlayola()
    let player = await makePlayerWithLockedBackend()

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater(stationPlayer: player)
    }

    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .stopped
    )

    guard case .listeningSessionStarted(_, let renderBackend)? = capturedEvents.value.first else {
      Issue.record("Expected listeningSessionStarted, got: \(capturedEvents.value)")
      return
    }
    #expect(renderBackend == "sampleBuffer")
  }

  @Test
  func testListeningSessionStartedOmitsRenderBackendForUrlStation() async {
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = true
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    // Even with a locked backend from an earlier Playola play, a URL-stream
    // session never touches the SDK, so it must not carry the renderer.
    let player = await makePlayerWithLockedBackend()

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater(stationPlayer: player)
    }

    await updater.trackListeningSession(
      currentStatus: .playing(AnyStation.mockUrl()),
      previousStatus: .stopped
    )

    guard case .listeningSessionStarted(_, let renderBackend)? = capturedEvents.value.first else {
      Issue.record("Expected listeningSessionStarted, got: \(capturedEvents.value)")
      return
    }
    #expect(renderBackend == nil)
  }

  @Test
  func testPlaybackErrorCarriesLockedRenderBackendForPlayolaStation() async {
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = true
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = AnyStation.mockPlayola()
    let player = await makePlayerWithLockedBackend()

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater(stationPlayer: player)
    }
    updater.lastPlayedStation = station

    await updater.trackListeningSession(
      currentStatus: .error,
      previousStatus: .loading(station)
    )

    guard case .playbackError(_, _, let renderBackend)? = capturedEvents.value.first else {
      Issue.record("Expected playbackError, got: \(capturedEvents.value)")
      return
    }
    #expect(renderBackend == "sampleBuffer")
  }

  @Test
  func testTrackListeningSessionStartsSessionWhenTransitioningToPlaying() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = AnyStation.mock

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater()
    }

    // Transition from stopped to playing
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .stopped
    )

    // Verify session started event was tracked
    let events = capturedEvents.value
    #expect(events.count == 1)
    if case .listeningSessionStarted(let stationInfo, _) = events.first {
      #expect(stationInfo.id == station.id)
      #expect(stationInfo.name == station.name)
    } else {
      Issue.record(
        "Expected listeningSessionStarted event, got: \(String(describing: events.first))")
    }
  }

  @Test
  func testTrackListeningSessionEndsSessionWhenStoppingFromPlaying() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = AnyStation.mock

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater()
    }

    // First start a session
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .stopped
    )

    // Clear events
    capturedEvents.withValue { $0.removeAll() }

    // Now stop the session
    await updater.trackListeningSession(
      currentStatus: .stopped,
      previousStatus: .playing(station)
    )

    // Verify session ended event was tracked
    let events = capturedEvents.value
    #expect(events.count == 1)
    if case .listeningSessionEnded(let stationInfo, let sessionLengthSec) = events.first {
      #expect(stationInfo.id == station.id)
      #expect(stationInfo.name == station.name)
      #expect(sessionLengthSec >= 0)
    } else {
      Issue.record("Expected listeningSessionEnded event, got: \(String(describing: events.first))")
    }
  }

  @Test
  func testStartingNewStationWhilePausedEndsPriorSessionAndStartsNext() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let stationA = AnyStation.mock
    let stationB = makeTestStation2()

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater()
    }

    // A is playing, then gets interruption-paused (session stays open).
    await updater.trackListeningSession(currentStatus: .playing(stationA), previousStatus: .stopped)
    await updater.trackListeningSession(
      currentStatus: .paused(stationA), previousStatus: .playing(stationA))
    capturedEvents.withValue { $0.removeAll() }

    // User picks station B from CarPlay while paused: .paused(A) -> .startingNewStation(B)
    // with no intervening .stopped. A's session must end here.
    await updater.trackListeningSession(
      currentStatus: .startingNewStation(stationB), previousStatus: .paused(stationA))
    guard case .listeningSessionEnded(let endedInfo, _)? = capturedEvents.value.first else {
      Issue.record(
        "Expected A's session to end, got \(String(describing: capturedEvents.value.first))")
      return
    }
    #expect(endedInfo.id == stationA.id)

    // sessionStartTime was cleared, so B's session can now start (no leak).
    capturedEvents.withValue { $0.removeAll() }
    await updater.trackListeningSession(
      currentStatus: .playing(stationB), previousStatus: .startingNewStation(stationB))
    guard case .listeningSessionStarted(let startedInfo, _)? = capturedEvents.value.first else {
      Issue.record(
        "Expected B's session to start, got \(String(describing: capturedEvents.value.first))")
      return
    }
    #expect(startedInfo.id == stationB.id)
  }

  @Test
  func testTrackListeningSessionInitiatesSessionBeforeSwitch() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station1 = AnyStation.mock
    let station2 = AnyStation.url(
      UrlStation(
        id: "station2",
        name: "Station 2",
        streamUrl: "https://stream2.example.com",
        imageUrl: "https://example.com/station2.jpg",
        description: "Description 2",
        website: nil,
        location: nil,
        active: true,
        createdAt: Date(),
        updatedAt: Date()
      ))

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater()
    }

    // Start playing station 1
    await updater.trackListeningSession(
      currentStatus: .playing(station1),
      previousStatus: .stopped
    )

    // Verify session was started
    let initialEvents = capturedEvents.value
    #expect(initialEvents.count == 1, "Expected 1 event after starting session")
    guard case .listeningSessionStarted = initialEvents.first else {
      Issue.record("Expected listeningSessionStarted event after starting session")
      return
    }

    // Clear events and switch to station 2
    capturedEvents.withValue { $0.removeAll() }
    await updater.trackListeningSession(
      currentStatus: .playing(station2),
      previousStatus: .playing(station1)
    )

    // Verify switch generated events
    let events = capturedEvents.value
    #expect(events.count == 3, "Station switch must generate exactly 3 events")
  }

  @Test
  func testTrackListeningSessionTracksStationSwitchEvents() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station1 = AnyStation.mock
    let station2 = makeTestStation2()

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater()
    }

    // Setup: Start playing station 1 first
    await updater.trackListeningSession(
      currentStatus: .playing(station1),
      previousStatus: .stopped
    )
    capturedEvents.withValue { $0.removeAll() }

    // Switch to station 2
    await updater.trackListeningSession(
      currentStatus: .playing(station2),
      previousStatus: .playing(station1)
    )

    // Verify the three expected events
    let events = capturedEvents.value
    #expect(events.count == 3, "Expected exactly 3 events when switching stations")
    guard events.count == 3 else { return }

    verifySessionEndedEvent(events[0], expectedStationId: station1.id, eventIndex: 0)
    verifySwitchedStationEvent(
      events[1], fromStationId: station1.id, toStationId: station2.id, eventIndex: 1)
    verifySessionStartedEvent(events[2], expectedStationId: station2.id, eventIndex: 2)
  }

  @Test
  func testTrackListeningSessionTracksPlaybackError() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater()
    }

    // First start a session to set up the session state
    await updater.trackListeningSession(
      currentStatus: .playing(AnyStation.mock),
      previousStatus: .stopped
    )

    // Clear events from setup
    capturedEvents.withValue { $0.removeAll() }

    // Set last played station for error tracking
    updater.lastPlayedStation = AnyStation.mock

    // Transition to error state
    await updater.trackListeningSession(
      currentStatus: .error,
      previousStatus: .playing(AnyStation.mock)
    )

    // Verify events were tracked
    let events = capturedEvents.value
    guard events.count > 0 else {
      Issue.record("Expected at least 1 event, got 0")
      return
    }

    // When transitioning from playing to error, only session ended is tracked
    // The error case in the switch statement is only for non-playing to error transitions
    #expect(events.count == 1)

    // Should be session ended
    if case .listeningSessionEnded = events[0] {
      // Expected
    } else {
      Issue.record("Expected listeningSessionEnded event, got: \(events[0])")
    }
  }

  @Test
  func testTrackListeningSessionDoesNotStartMultipleSessions() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = AnyStation.mock

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater()
    }

    // Start playing
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .stopped
    )

    // Clear events
    capturedEvents.withValue { $0.removeAll() }

    // Transition from loading to playing (should not start another session)
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .loading(station)
    )

    // Verify no new session was started
    let events = capturedEvents.value
    #expect(events.count == 0)
  }

  @Test
  func testTrackListeningSessionHandlesLoadingToPlayingTransition() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = AnyStation.mock

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater()
    }

    // Transition from loading to playing (common flow)
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .loading(station)
    )

    // Verify session started
    let events = capturedEvents.value
    #expect(events.count == 1)
    if case .listeningSessionStarted(let stationInfo, _) = events.first {
      #expect(stationInfo.id == station.id)
    } else {
      Issue.record(
        "Expected listeningSessionStarted event, got: \(String(describing: events.first))")
    }
  }

  @Test
  func testTrackListeningSessionDoesNotTrackSameStationSwitch() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let station = AnyStation.mock

    let updater = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater()
    }

    // Start playing
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .stopped
    )

    // Clear events
    capturedEvents.withValue { $0.removeAll() }

    // "Switch" to same station (should not track anything)
    await updater.trackListeningSession(
      currentStatus: .playing(station),
      previousStatus: .playing(station)
    )

    // Verify no events were tracked
    let events = capturedEvents.value
    #expect(events.count == 0)
  }

  // MARK: - Now Playing Title/Artist Tests

  @Test
  func testPopulatePlayingInfoCommercialShowsPlayolaPaysAndStationName() {
    let station = AnyStation.playola(
      Station.mockWith(
        name: "Test Station Name"
      )
    )
    let commercialAudioBlock = AudioBlock.mockWith(
      title: "Some Commercial Title",
      artist: "Some Commercial Artist",
      type: "commercial"
    )
    let spin = Spin.mockWith(audioBlock: commercialAudioBlock, airing: nil)

    let updater = NowPlayingUpdater()

    let (title, artist) = updater.nowPlayingTitleAndArtist(
      spin: spin,
      station: station
    )

    #expect(title == "Playola Pays")
    #expect(artist == "Test Station Name")
  }

  @Test
  func testPopulatePlayingInfoSongShowsTitleAndArtist() {
    let station = AnyStation.playola(
      Station.mockWith(
        name: "Test Station Name"
      )
    )
    let songAudioBlock = AudioBlock.mockWith(
      title: "My Song Title",
      artist: "My Song Artist",
      type: "song"
    )
    let spin = Spin.mockWith(audioBlock: songAudioBlock, airing: nil)

    let updater = NowPlayingUpdater()

    let (title, artist) = updater.nowPlayingTitleAndArtist(
      spin: spin,
      station: station
    )

    #expect(title == "My Song Title")
    #expect(artist == "My Song Artist")
  }

  @Test
  func testPopulatePlayingInfoSongWithAiringShowsTitleAndArtist() {
    let station = AnyStation.playola(
      Station.mockWith(
        name: "Test Station Name"
      )
    )
    let songAudioBlock = AudioBlock.mockWith(
      title: "My Song Title",
      artist: "My Song Artist",
      type: "song"
    )
    let airing = Airing.mockWith(
      episode: Episode.mockWith(title: "Episode Title")
    )
    let spin = Spin.mockWith(audioBlock: songAudioBlock, airing: airing)

    let updater = NowPlayingUpdater()

    let (title, artist) = updater.nowPlayingTitleAndArtist(
      spin: spin,
      station: station
    )

    #expect(title == "My Song Title")
    #expect(artist == "My Song Artist")
  }

  @Test
  func testPopulatePlayingInfoNonSongWithAiringShowsEpisodeTitleAndStationName() {
    let station = AnyStation.playola(
      Station.mockWith(
        name: "Test Station Name"
      )
    )
    let nonSongAudioBlock = AudioBlock.mockWith(
      title: "Voice Track Title",
      artist: "Voice Track Artist",
      type: "voiceTrack"
    )
    let airing = Airing.mockWith(
      episode: Episode.mockWith(title: "Episode Title")
    )
    let spin = Spin.mockWith(audioBlock: nonSongAudioBlock, airing: airing)

    let updater = NowPlayingUpdater()

    let (title, artist) = updater.nowPlayingTitleAndArtist(
      spin: spin,
      station: station
    )

    #expect(title == "Episode Title")
    #expect(artist == "Test Station Name")
  }

  @Test
  func testPopulatePlayingInfoNonSongWithoutAiringShowsStationNameAndEmptyArtist() {
    let station = AnyStation.playola(
      Station.mockWith(
        name: "Test Station Name"
      )
    )
    let nonSongAudioBlock = AudioBlock.mockWith(
      title: "Voice Track Title",
      artist: "Voice Track Artist",
      type: "voiceTrack"
    )
    let spin = Spin.mockWith(audioBlock: nonSongAudioBlock, airing: nil)

    let updater = NowPlayingUpdater()

    let (title, artist) = updater.nowPlayingTitleAndArtist(
      spin: spin,
      station: station
    )

    #expect(title == "Test Station Name")
    #expect(artist == "")
  }

  // MARK: - Helper Methods

  private func makeTestStation2() -> AnyStation {
    return AnyStation.url(
      UrlStation(
        id: "station2",
        name: "Station 2",
        streamUrl: "https://stream2.example.com",
        imageUrl: "https://example.com/station2.jpg",
        description: "Description 2",
        website: nil,
        location: nil,
        active: true,
        createdAt: Date(),
        updatedAt: Date()
      ))
  }

  private func verifySessionEndedEvent(
    _ event: AnalyticsEvent, expectedStationId: String, eventIndex: Int
  ) {
    guard case .listeningSessionEnded(let stationInfo, _) = event else {
      Issue.record("Expected listeningSessionEnded event at index \(eventIndex), got: \(event)")
      return
    }
    #expect(stationInfo.id == expectedStationId)
  }

  private func verifySwitchedStationEvent(
    _ event: AnalyticsEvent,
    fromStationId: String,
    toStationId: String,
    eventIndex: Int
  ) {
    guard case .switchedStation(let from, let to, let timeBeforeSwitchSec, let reason) = event
    else {
      Issue.record("Expected switchedStation event at index \(eventIndex), got: \(event)")
      return
    }
    #expect(from.id == fromStationId)
    #expect(to.id == toStationId)
    #expect(timeBeforeSwitchSec >= 0)
    #expect(reason == .userInitiated)
  }

  private func verifySessionStartedEvent(
    _ event: AnalyticsEvent, expectedStationId: String, eventIndex: Int
  ) {
    guard case .listeningSessionStarted(let stationInfo, _) = event else {
      Issue.record("Expected listeningSessionStarted event at index \(eventIndex), got: \(event)")
      return
    }
    #expect(stationInfo.id == expectedStationId)
  }
}
