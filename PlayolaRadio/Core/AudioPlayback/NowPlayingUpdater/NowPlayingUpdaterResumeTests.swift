//
//  NowPlayingUpdaterResumeTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/14/25.
//

import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import MediaPlayer
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct NowPlayingUpdaterResumeTests {

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

  private func makeStoppedUpdater() -> NowPlayingUpdater {
    withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer(
        playolaStationPlayer: SpyPlayolaStationPlayer(),
        audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }
  }

  private func makeLists(
    containing station: Station, visibility: StationListItemVisibility
  ) -> IdentifiedArrayOf<StationList> {
    IdentifiedArrayOf(uniqueElements: [
      StationList.mockArtistList(items: [
        APIStationItem(sortOrder: 0, visibility: visibility, station: station, urlStation: nil)
      ])
    ])
  }

  // Intentional behavior change (spec "iOS runtime behavior"): resume is no longer a
  // zero-network cold-launch path. A station absent from every fetched list (including
  // lists not loaded yet) is not playable, so there is nothing to resume.
  @Test
  func testResumeRefusesWhenStationListsEmpty() {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.lastPlayedStation) var persisted: LastPlayedStation? =
      LastPlayedStation(station: .mockPlayola())
    let updater = makeStoppedUpdater()

    expectNoDifference(updater.handlePlayCommand(), .commandFailed)
  }

  @Test
  func testResumeRefusesStationThatBecameSecretWhenLocked() {
    let station = Station.mockWith(id: "became-secret-id")
    @Shared(.stationLists) var stationLists = makeLists(containing: station, visibility: .hidden)
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.lastPlayedStation) var persisted: LastPlayedStation? =
      LastPlayedStation(station: .playola(station))
    let updater = makeStoppedUpdater()

    expectNoDifference(updater.handlePlayCommand(), .commandFailed)
  }

  @Test
  func testResumeResolvesPlayableStationFromLists() {
    let station = Station.mockWith(id: "playable-id")
    @Shared(.stationLists) var stationLists = makeLists(containing: station, visibility: .visible)
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.lastPlayedStation) var persisted: LastPlayedStation? =
      LastPlayedStation(station: .playola(station))
    let updater = makeStoppedUpdater()

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

    #expect(updater.handlePlayCommand() == .commandFailed)
  }

  @Test
  func handlePlayCommandRefusesNonPlayolaSnapshot() {
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
    let station = Station.mockWith(id: "paused-visible-id")
    @Shared(.stationLists) var stationLists = makeLists(containing: station, visibility: .visible)
    @Shared(.showSecretStations) var showSecretStations = false
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer(
        playolaStationPlayer: SpyPlayolaStationPlayer(),
        audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
      stationPlayer.state = StationPlayer.State(playbackStatus: .paused(.playola(station)))
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }

    // Interruption pause: the play command resumes the live backend directly.
    #expect(updater.handlePlayCommand() == .success)
  }

  @Test
  func handlePlayCommandRefusesPausedStationThatBecameSecretWhenLocked() {
    let station = Station.mockWith(id: "paused-secret-id")
    @Shared(.stationLists) var stationLists = makeLists(containing: station, visibility: .hidden)
    @Shared(.showSecretStations) var showSecretStations = false
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      let stationPlayer = StationPlayer(
        playolaStationPlayer: SpyPlayolaStationPlayer(),
        audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
      stationPlayer.state = StationPlayer.State(playbackStatus: .paused(.playola(station)))
      return NowPlayingUpdater(stationPlayer: stationPlayer)
    }

    expectNoDifference(updater.handlePlayCommand(), .commandFailed)
  }

  @Test
  func pauseSupersedesQueuedPlayCommand() async {
    let listed = Station.mockWith(id: "queued-play-id")
    @Shared(.stationLists) var stationLists = makeLists(containing: listed, visibility: .visible)
    let playola = SpyPlayolaStationPlayer()
    let station = AnyStation.playola(listed)
    let stationPlayer = StationPlayer(
      playolaStationPlayer: playola,
      audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
    stationPlayer.state = StationPlayer.State(playbackStatus: .paused(station))
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater(stationPlayer: stationPlayer)
    }
    await withMainSerialExecutor {
      expectNoDifference(updater.handlePlayCommand(), .success)
      stationPlayer.pauseWithoutAutoResume()
      await Task.yield()
      expectNoDifference(playola.resumeAfterInterruptionCount, 0)

      stationPlayer.state = StationPlayer.State(playbackStatus: .paused(station))
      expectNoDifference(updater.handlePlayCommand(), .success)
      await Task.yield()
      expectNoDifference(playola.resumeAfterInterruptionCount, 1)
    }
  }

  // MARK: - Remote Play Command Analytics Tests

  private func makeUpdaterTrackingRemotePlay(
    status: StationPlayer.PlaybackStatus?,
    launchedAt: Date = Date(),
    commandAt: Date = Date(),
    onEvent: @escaping @Sendable (AnalyticsEvent) -> Void
  ) -> NowPlayingUpdater {
    withDependencies {
      $0.analytics.track = { event in
        if case .remotePlayCommandReceived = event { onEvent(event) }
      }
      $0.date = .constant(commandAt)
    } operation: {
      let stationPlayer = StationPlayer(
        playolaStationPlayer: SpyPlayolaStationPlayer(),
        audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
      if let status {
        stationPlayer.state = StationPlayer.State(playbackStatus: status)
      }
      return NowPlayingUpdater(stationPlayer: stationPlayer, launchedAt: launchedAt)
    }
  }

  @Test
  func handlePlayCommandTracksResumeWhenPaused() async {
    let station = Station.mockWith(id: "tracked-paused-id")
    @Shared(.stationLists) var stationLists = makeLists(containing: station, visibility: .visible)
    let launch = Date(timeIntervalSince1970: 1_000)
    let event = await withCheckedContinuation { continuation in
      let updater = makeUpdaterTrackingRemotePlay(
        status: .paused(.playola(station)),
        launchedAt: launch,
        commandAt: launch.addingTimeInterval(42)
      ) { continuation.resume(returning: $0) }
      _ = updater.handlePlayCommand()
    }

    guard case .remotePlayCommandReceived(let action, _, let secondsSinceLaunch) = event else {
      Issue.record("Expected remotePlayCommandReceived, got: \(event)")
      return
    }
    #expect(action == "resume")
    #expect(secondsSinceLaunch == 42)
  }

  @Test
  func handlePlayCommandTracksRestartWhenStoppedWithLastStation() async {
    let station = Station.mockWith(id: "tracked-last-id")
    @Shared(.stationLists) var stationLists = makeLists(containing: station, visibility: .visible)
    @Shared(.lastPlayedStation) var persisted: LastPlayedStation? =
      LastPlayedStation(station: .playola(station))
    let event = await withCheckedContinuation { continuation in
      let updater = makeUpdaterTrackingRemotePlay(status: nil) {
        continuation.resume(returning: $0)
      }
      _ = updater.handlePlayCommand()
    }

    guard case .remotePlayCommandReceived(let action, _, _) = event else {
      Issue.record("Expected remotePlayCommandReceived, got: \(event)")
      return
    }
    #expect(action == "restart_last_station")
  }

  @Test
  func handlePlayCommandTracksNoneWhenNothingToResume() async {
    let event = await withCheckedContinuation { continuation in
      let updater = makeUpdaterTrackingRemotePlay(status: nil) {
        continuation.resume(returning: $0)
      }
      _ = updater.handlePlayCommand()
    }

    guard case .remotePlayCommandReceived(let action, _, _) = event else {
      Issue.record("Expected remotePlayCommandReceived, got: \(event)")
      return
    }
    #expect(action == "none")
  }

  @Test
  func remotePlayCommandReceivedEventNameAndProperties() {
    let event = AnalyticsEvent.remotePlayCommandReceived(
      action: "resume", appState: "background", secondsSinceLaunch: 7)

    #expect(event.name == "Remote Play Command Received")
    #expect(event.properties["action"] as? String == "resume")
    #expect(event.properties["app_state"] as? String == "background")
    #expect(event.properties["seconds_since_launch"] as? Int == 7)
  }

  // MARK: - Remote Command Tests

  @Test
  func setupRemoteControlCenterEnablesPauseCommand() {
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.pauseCommand.isEnabled = false
    let updater = withDependencies {
      $0.analytics.track = { _ in }
      $0.date = .constant(Date())
    } operation: {
      NowPlayingUpdater()
    }

    updater.setupRemoteControlCenter()

    #expect(commandCenter.pauseCommand.isEnabled)
  }
}
