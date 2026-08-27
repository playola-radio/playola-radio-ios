//
//  StationPlayerLastPlayedTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//

import CustomDump
import Dependencies
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct StationPlayerLastPlayedTests {

  @Test
  func playolaPlayPersistsLastPlayedStation() async {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    @Shared(.lastPlayedStation) var lastPlayedStation: LastPlayedStation?
    let coordinator = AudioSessionCoordinator(session: SpyAudioSession())
    let player = StationPlayer(
      playolaStationPlayer: SpyPlayolaStationPlayer(), audioSessionCoordinator: coordinator)
    let station = AnyStation.mockPlayola()

    await player.play(station: station)

    // Persisted on accepted user intent so the lock-screen / car play command can
    // resume it after Stop and across a cold-but-alive relaunch.
    expectNoDifference(lastPlayedStation, LastPlayedStation(station: station))
  }

  @Test
  func urlPlayDoesNotOverwriteLastPlayedPlayolaStation() async {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let playolaStation = AnyStation.mockPlayola()
    @Shared(.lastPlayedStation) var lastPlayedStation: LastPlayedStation? =
      LastPlayedStation(station: playolaStation)
    let coordinator = AudioSessionCoordinator(session: SpyAudioSession())
    let player = StationPlayer(
      playolaStationPlayer: SpyPlayolaStationPlayer(), audioSessionCoordinator: coordinator)

    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      await player.play(station: .mockUrl())
    }

    // Only `.playola` stations are persisted; the legacy URL backend never
    // overwrites the durable snapshot.
    expectNoDifference(lastPlayedStation, LastPlayedStation(station: playolaStation))
  }

  @Test
  func stopDoesNotClearPersistedLastPlayedStation() async {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    @Shared(.lastPlayedStation) var lastPlayedStation: LastPlayedStation?
    let coordinator = AudioSessionCoordinator(session: SpyAudioSession())
    let player = StationPlayer(
      playolaStationPlayer: SpyPlayolaStationPlayer(), audioSessionCoordinator: coordinator)
    let station = AnyStation.mockPlayola()
    await player.play(station: station)

    player.stop()

    // Stop must not erase the snapshot — it is precisely what a later play command
    // resumes.
    expectNoDifference(lastPlayedStation, LastPlayedStation(station: station))
  }

  @Test
  func signOutClearsPersistedLastPlayedStation() async {
    @Shared(.auth) var auth = Auth()
    @Shared(.lastPlayedStation) var lastPlayedStation: LastPlayedStation? =
      LastPlayedStation(station: .mockPlayola())
    let player = StationPlayer(
      playolaStationPlayer: SpyPlayolaStationPlayer(),
      audioSessionCoordinator: AudioSessionCoordinator(session: SpyAudioSession()))

    await withDependencies {
      $0.analytics.reset = {}
      $0.analytics.track = { _ in }
      $0.stationPlayer = player
      $0.nowPlayingUpdater = NowPlayingUpdater(stationPlayer: player)
    } operation: {
      await AuthService.shared.signOut()
    }

    // Station content is account-scoped: one account must never resume into
    // another's last station.
    #expect(lastPlayedStation == nil)
  }

  @Test
  func signOutStopsActivePlayback() async {
    @Shared(.auth) var auth = Auth()
    @Shared(.lastPlayedStation) var lastPlayedStation: LastPlayedStation?
    let player = StationPlayer(
      playolaStationPlayer: SpyPlayolaStationPlayer(),
      audioSessionCoordinator: AudioSessionCoordinator(session: SpyAudioSession()))

    await withDependencies {
      $0.continuousClock = ImmediateClock()
      $0.analytics.reset = {}
      $0.analytics.track = { _ in }
      $0.stationPlayer = player
      $0.nowPlayingUpdater = NowPlayingUpdater(stationPlayer: player)
    } operation: {
      await player.play(station: .mockPlayola())
      await AuthService.shared.signOut()
    }

    // Playback must not survive sign-out; otherwise a later state emission could
    // resurrect the Now Playing entry from the still-current station.
    #expect(player.currentStation == nil)
  }
}
