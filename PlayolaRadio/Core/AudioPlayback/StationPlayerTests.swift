//
//  StationPlayerTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//

import Combine
import CustomDump
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

private struct PlayFailureTestError: Error {}

/// Records transport calls so StationPlayer's backend routing can be asserted
/// without constructing a real (CoreAudio-backed) PlayolaStationPlayer.
@MainActor
final class SpyPlayolaStationPlayer: PlayolaTransport {
  private let stateSubject = CurrentValueSubject<PlayolaStationPlayer.State, Never>(.idle)
  var statePublisher: AnyPublisher<PlayolaStationPlayer.State, Never> {
    stateSubject.eraseToAnyPublisher()
  }

  var configureCount = 0
  var playCount = 0
  var stopCount = 0
  var pauseForInterruptionCount = 0
  var resumeAfterInterruptionCount = 0

  func configure(authProvider: PlayolaAuthenticationProvider, baseURL: URL) { configureCount += 1 }
  func play(stationId: String) async throws { playCount += 1 }
  func stop() { stopCount += 1 }
  func pauseForInterruption() { pauseForInterruptionCount += 1 }
  func resumeAfterInterruption() async throws { resumeAfterInterruptionCount += 1 }
}

@MainActor
struct StationPlayerTests {

  // MARK: - Session Ownership Tests

  @Test
  func playConfiguresSessionBeforeBackendAndSurfacesFailure() async {
    @Shared(.nowPlaying) var nowPlaying = NowPlaying(playbackStatus: .stopped)
    let coordinator = AudioSessionCoordinator(session: FailingAudioSession())
    let player = StationPlayer(audioSessionCoordinator: coordinator)

    await player.play(station: .mockPlayola())

    // The app owns the session now: if activating it fails, play() must surface
    // .error instead of proceeding into a backend that would throw deep inside
    // engine.start().
    guard case .error = player.state.playbackStatus else {
      Issue.record(
        "session-config failure must surface as .error, got \(player.state.playbackStatus)")
      return
    }
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
    // StationPlayer.processPlayolaStationPlayerState drives only `state`; the
    // shared `nowPlaying` is NowPlayingUpdater's responsibility and must be
    // left untouched here.
    expectNoDifference(nowPlaying?.playbackStatus, .loading(.mock))
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
    let urlStreamPlayer = URLStreamPlayerMock()
    let stationPlayer = StationPlayer(urlStreamPlayer: urlStreamPlayer)
    let playolaStation = AnyStation.mockPlayola()
    stationPlayer.state = StationPlayer.State(playbackStatus: .playing(playolaStation))

    urlStreamPlayer.state = URLStreamPlayer.State(
      playbackState: .stopped,
      playerStatus: .urlNotSet,
      currentStation: nil,
      nowPlaying: nil
    )

    expectNoDifference(stationPlayer.state.playbackStatus, .playing(playolaStation))
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
    let stationPlayer = StationPlayer()
    let urlStation = AnyStation.mockUrl()
    stationPlayer.state = StationPlayer.State(playbackStatus: .playing(urlStation))

    stationPlayer.processPlayolaStationPlayerState(.idle)

    expectNoDifference(stationPlayer.state.playbackStatus, .playing(urlStation))
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
    await stationPlayer.play(station: stations[0])

    await stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == stations[1].id)
  }

  @Test
  func testSeekNextWrapsAroundFromLastToFirst() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    await stationPlayer.play(station: stations[2])

    await stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == stations[0].id)
  }

  @Test
  func testSeekNextWithNoCurrentStationPlaysFirst() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations

    await stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == stations[0].id)
  }

  @Test
  func testSeekNextWithEmptyStationListDoesNothing() async {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()

    await stationPlayer.seekNext()

    #expect(stationPlayer.currentStation == nil)
  }

  // MARK: - seekPrevious Tests

  @Test
  func testSeekPreviousPlaysPreviousStation() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    await stationPlayer.play(station: stations[1])

    await stationPlayer.seekPrevious()

    #expect(stationPlayer.currentStation?.id == stations[0].id)
  }

  @Test
  func testSeekPreviousWrapsAroundFromFirstToLast() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    await stationPlayer.play(station: stations[0])

    await stationPlayer.seekPrevious()

    #expect(stationPlayer.currentStation?.id == stations[2].id)
  }

  @Test
  func testSeekPreviousWithNoCurrentStationPlaysFirst() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations

    await stationPlayer.seekPrevious()

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

    await stationPlayer.play(station: artistStations[0])
    await stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == artistStations[1].id)
  }

  @Test
  func testSeekSkipsInactiveStations() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithInactiveStation()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let allStations = stationLists.first!.stations

    await stationPlayer.play(station: allStations[0])
    await stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == allStations[2].id)
  }

  @Test
  func testSeekSkipsComingSoonStationsWhenSecretsDisabled() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithComingSoonStation()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let allStations = stationLists.first!.stations

    await stationPlayer.play(station: allStations[0])
    await stationPlayer.seekNext()

    #expect(stationPlayer.currentStation?.id == allStations[2].id)
  }

  @Test
  func testSeekIncludesComingSoonStationsWhenSecretsEnabled() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithComingSoonStation()
    @Shared(.showSecretStations) var showSecretStations = true

    let stationPlayer = StationPlayer()
    let allStations = stationLists.first!.stations

    await stationPlayer.play(station: allStations[0])
    await stationPlayer.seekNext()

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
    await stationPlayer.play(station: stations[0])

    await stationPlayer.seekNext()

    #expect(!stationPlayer.isSeeking, "isSeeking should be false after seek completes")
  }

  @Test
  func testIsSeekingIsFalseAfterSeekPreviousCompletes() async {
    @Shared(.stationLists) var stationLists = makeArtistListWithThreeStations()
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()
    let stations = stationLists.first!.stations
    await stationPlayer.play(station: stations[1])

    await stationPlayer.seekPrevious()

    #expect(!stationPlayer.isSeeking, "isSeeking should be false after seek completes")
  }

  @Test
  func testIsSeekingIsFalseWhenSeekHasNoStations() async {
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayer = StationPlayer()

    await stationPlayer.seekNext()

    #expect(!stationPlayer.isSeeking, "isSeeking should remain false when no stations")
  }

  // MARK: - Helper Methods

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
