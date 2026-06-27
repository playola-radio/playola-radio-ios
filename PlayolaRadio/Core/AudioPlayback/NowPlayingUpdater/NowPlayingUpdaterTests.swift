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

  @Test
  func testProcessPlayolaErrorStatePublishesRecoverableErrorStatus() {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .loading(.mock))
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater()
    }

    // PlayolaPlayer 0.19.0's terminal `.error` must publish the recoverable
    // `.error` status into shared state, not leave the UI stuck on .loading.
    updater.processPlayolaStationPlayerState(.error(.networkError("boom")))

    #expect(nowPlaying?.playbackStatus == .error)
  }

  // MARK: - Backend Ownership Regression Tests

  // Same CarPlay/lock-screen "instantly dismissed" regression as in
  // StationPlayer, but for the shared `nowPlaying` state NowPlayingUpdater
  // publishes. NowPlayingUpdater independently observes both audio backends, so
  // the spurious cross-backend `.stopped` must be guarded here too.

  @Test
  func testUrlStreamUrlNotSetDoesNotClobberActivePlayolaNowPlaying() {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let playolaStation = AnyStation.mockPlayola()
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer()
      stationPlayer.state = StationPlayer.State(playbackStatus: .loading(playolaStation))
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }

    // Establish a real Playola baseline (last writer wins over init echoes).
    updater.processPlayolaStationPlayerState(.loading(0.5))
    // A late URL-backend `.urlNotSet` (FRadioPlayer's response to reset() during
    // the Playola play) must not clobber shared state back to .stopped.
    updater.processUrlStreamStateChanged(
      URLStreamPlayer.State(
        playbackState: .stopped,
        playerStatus: .urlNotSet,
        currentStation: nil,
        nowPlaying: nil
      )
    )

    expectNoDifference(nowPlaying?.playbackStatus, .loading(playolaStation, 0.5))
  }

  @Test
  func testPlayolaIdleDoesNotClobberActiveUrlNowPlaying() {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let urlStation = AnyStation.mockUrl()
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer()
      stationPlayer.state = StationPlayer.State(playbackStatus: .playing(urlStation))
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }

    // Establish a real URL baseline.
    updater.processUrlStreamStateChanged(
      URLStreamPlayer.State(
        playbackState: .playing,
        playerStatus: .readyToPlay,
        currentStation: nil,
        nowPlaying: nil
      )
    )
    // A stray Playola `.idle` (emitted by stop() while switching) must not
    // clobber the active URL station back to .stopped.
    updater.processPlayolaStationPlayerState(.idle)

    expectNoDifference(nowPlaying?.playbackStatus, .playing(urlStation))
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

  // MARK: - Analytics Tests

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
    if case .listeningSessionStarted(let stationInfo) = events.first {
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
    if case .listeningSessionStarted(let stationInfo) = events.first {
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
    guard case .listeningSessionStarted(let stationInfo) = event else {
      Issue.record("Expected listeningSessionStarted event at index \(eventIndex), got: \(event)")
      return
    }
    #expect(stationInfo.id == expectedStationId)
  }
}
