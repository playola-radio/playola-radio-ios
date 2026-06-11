//
//  WelcomeMessagePageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct WelcomeMessagePageModelTests {

  @Test
  func testTaskPlaysRecordingAndMarksSeen() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let player = StationPlayerMock()
    let capturedURL = LockIsolated<URL?>(nil)
    let stateSink = LockIsolated<(@MainActor @Sendable (PlaybackState) -> Void)?>(nil)
    let seenCalls = LockIsolated<[String]>([])

    await withMainSerialExecutor {
      let model = makeRecordingModel(
        player: player, capturedURL: capturedURL, stateSink: stateSink, seenCalls: seenCalls)
      await model.task()

      #expect(capturedURL.value == URL(string: "https://example.com/welcome.m4a"))
      #expect(player.callsToPlay.isEmpty)
      // The "seen" write runs in a detached task; the main serial executor lets it complete
      // deterministically after a single yield rather than polling.
      await Task.yield()
      #expect(seenCalls.value == ["station-123"])
    }
  }

  @Test
  func testChipRevealsAndCompletionFollowRealDuration() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let player = StationPlayerMock()
    let capturedURL = LockIsolated<URL?>(nil)
    let stateSink = LockIsolated<(@MainActor @Sendable (PlaybackState) -> Void)?>(nil)
    let seenCalls = LockIsolated<[String]>([])

    let model = makeRecordingModel(
      player: player, capturedURL: capturedURL, stateSink: stateSink, seenCalls: seenCalls)
    await model.task()
    let send = try #require(stateSink.value)

    send(PlaybackState(currentTime: 1, duration: 8, isPlaying: true))
    #expect(model.chips.allSatisfy { model.isChipRevealed($0) == false })
    #expect(model.isPrimaryButtonEnabled == false)
    #expect(model.skipButtonOpacity == 1)

    send(PlaybackState(currentTime: 2, duration: 8, isPlaying: true))
    #expect(model.chips.filter { model.isChipRevealed($0) }.map(\.id) == ["songs"])

    send(PlaybackState(currentTime: 4, duration: 8, isPlaying: true))
    #expect(model.chips.filter { model.isChipRevealed($0) }.map(\.id) == ["songs", "stories"])

    // A buffering stall (not playing, mid-recording) must NOT count as completion.
    send(PlaybackState(currentTime: 4, duration: 8, isPlaying: false))
    #expect(model.isComplete == false)

    send(PlaybackState(currentTime: 6, duration: 8, isPlaying: true))
    #expect(model.chips.allSatisfy { model.isChipRevealed($0) })
    #expect(model.isComplete == false)

    send(PlaybackState(currentTime: 8, duration: 8, isPlaying: false))
    #expect(model.isComplete == true)
    #expect(model.progress == 1)
    #expect(model.primaryButtonTitle == "Start Listening")
    #expect(model.isPrimaryButtonEnabled == true)
    #expect(model.nowPlayingCardOpacity == 1)
    #expect(model.skipButtonOpacity == 0)
  }

  private func makeRecordingModel(
    player: StationPlayerMock,
    capturedURL: LockIsolated<URL?>,
    stateSink: LockIsolated<(@MainActor @Sendable (PlaybackState) -> Void)?>,
    seenCalls: LockIsolated<[String]>
  ) -> WelcomeMessagePageModel {
    withDependencies {
      $0.analytics.track = { _ in }
      $0.stationPlayer = player
      $0.api.fetchSchedule = { _, _ in [] }
      $0.api.getStationWelcomeMessage = { _, _ in
        AudioBlock.mockWith(
          durationMS: 8_000,
          downloadUrl: URL(string: "https://example.com/welcome.m4a")
        )
      }
      $0.api.markWelcomeMessageSeen = { _, stationId in
        seenCalls.withValue { $0.append(stationId) }
      }
      $0.audioPlayer.startPlayback = { url, onStateChange in
        capturedURL.setValue(url)
        stateSink.setValue(onStateChange)
        return PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    } operation: {
      WelcomeMessagePageModel(station: .mockPlayola(id: "station-123"))
    }
  }

  // Tapping Skip while the recording is still being fetched must not start welcome audio
  // over the already-starting station.
  @Test
  func testSkipDuringFetchDoesNotStartWelcomeAudio() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let player = StationPlayerMock()
    let startPlaybackCalled = LockIsolated(false)
    let (gateStream, gateContinuation) = AsyncStream<Void>.makeStream()

    let model = withDependencies {
      $0.analytics.track = { _ in }
      $0.stationPlayer = player
      $0.api.fetchSchedule = { _, _ in [] }
      $0.api.getStationWelcomeMessage = { _, _ in
        var iterator = gateStream.makeAsyncIterator()
        _ = await iterator.next()
        return AudioBlock.mockWith(downloadUrl: URL(string: "https://example.com/welcome.m4a"))
      }
      $0.audioPlayer.startPlayback = { _, _ in
        startPlaybackCalled.setValue(true)
        return PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    } operation: {
      WelcomeMessagePageModel(station: .mockPlayola(id: "station-123"))
    }

    let taskHandle = Task { await model.task() }
    await Task.yield()
    await model.skipButtonTapped()
    gateContinuation.yield()
    gateContinuation.finish()
    await taskHandle.value

    #expect(startPlaybackCalled.value == false)
    #expect(player.callsToPlay.map(\.id) == ["station-123"])
  }

  @Test
  func testTaskStartsStationDirectlyWhenRecordingMissing() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let player = StationPlayerMock()
    let events = LockIsolated<[AnalyticsEvent]>([])

    let model = withDependencies {
      $0.analytics.track = { event in events.withValue { $0.append(event) } }
      $0.stationPlayer = player
      $0.api.fetchSchedule = { _, _ in [] }
      $0.api.getStationWelcomeMessage = { _, _ in nil }
    } operation: {
      WelcomeMessagePageModel(station: .mockPlayola(id: "station-123"))
    }

    await model.task()

    #expect(player.callsToPlay.map(\.id) == ["station-123"])
    #expect(events.value.count == 1)
  }

  // A failed fetch must not burn the user's one welcome — no server "seen" stamp.
  @Test
  func testTaskStartsStationDirectlyWhenFetchFailsWithoutMarkingSeen() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let player = StationPlayerMock()
    let seenCalls = LockIsolated(0)

    let model = withDependencies {
      $0.analytics.track = { _ in }
      $0.stationPlayer = player
      $0.api.fetchSchedule = { _, _ in [] }
      $0.api.getStationWelcomeMessage = { _, _ in throw APIError.dataNotValid }
      $0.api.markWelcomeMessageSeen = { _, _ in seenCalls.withValue { $0 += 1 } }
    } operation: {
      WelcomeMessagePageModel(station: .mockPlayola(id: "station-123"))
    }

    await model.task()

    #expect(player.callsToPlay.map(\.id) == ["station-123"])
    #expect(seenCalls.value == 0)
  }

  // Skip and Start Listening both route to the same start-once path — mashing
  // either (or both) must only start the station a single time.
  @Test
  func testSkipAndPrimaryButtonsStartStationOnlyOnce() async {
    let player = StationPlayerMock()
    let events = LockIsolated<[AnalyticsEvent]>([])

    let model = withDependencies {
      $0.analytics.track = { event in events.withValue { $0.append(event) } }
      $0.stationPlayer = player
    } operation: {
      WelcomeMessagePageModel(station: .mockPlayola(id: "station-xyz"))
    }

    await model.skipButtonTapped()
    await model.skipButtonTapped()
    await model.primaryButtonTapped()

    #expect(player.callsToPlay.map(\.id) == ["station-xyz"])
    #expect(events.value.count == 1)
  }

  // MARK: - Now Playing card (live schedule preview)

  // The card shows the song airing on the station right now, derived from the fetched
  // schedule and the current clock (the station itself isn't playing yet).
  @Test
  func testNowPlayingCardShowsCurrentlyAiringSong() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date(timeIntervalSince1970: 1_000_000)
    let spins = [
      Spin.mockWith(
        id: "spin-1",
        airtime: now.addingTimeInterval(-30),
        stationId: "station-123",
        audioBlock: AudioBlock.mockWith(
          title: "Sea of Heartbreak", artist: "Radney Foster", endOfMessageMS: 180_000, type: "song"
        )
      )
    ]

    await withDependencies {
      $0.date.now = now
      $0.analytics.track = { _ in }
      $0.stationPlayer = StationPlayerMock()
      $0.api.fetchSchedule = { _, _ in spins }
      $0.api.getStationWelcomeMessage = { _, _ in
        AudioBlock.mockWith(downloadUrl: URL(string: "https://example.com/welcome.m4a"))
      }
      $0.audioPlayer.startPlayback = { _, _ in
        PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    } operation: {
      let model = WelcomeMessagePageModel(
        station: .mockPlayola(
          id: "station-123", name: "Bordertown Radio", curatorName: "Radney Foster"))
      await model.task()

      #expect(model.nowPlayingSpin?.id == "spin-1")
      #expect(model.nowPlayingCardTitle == "Sea of Heartbreak")
      #expect(model.nowPlayingCardSubtitle == "Radney Foster")
    }
  }

  // When nothing is airing (between spins / after the schedule ends / fetch failed),
  // the card falls back to the curator rather than showing a stale spin.
  @Test
  func testNowPlayingCardFallsBackToCuratorWhenNothingAiring() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date(timeIntervalSince1970: 1_000_000)
    let endedSpin = [
      Spin.mockWith(
        id: "spin-old",
        airtime: now.addingTimeInterval(-600),
        stationId: "station-123",
        audioBlock: AudioBlock.mockWith(endOfMessageMS: 60_000, type: "song")
      )
    ]

    await withDependencies {
      $0.date.now = now
      $0.analytics.track = { _ in }
      $0.stationPlayer = StationPlayerMock()
      $0.api.fetchSchedule = { _, _ in endedSpin }
      $0.api.getStationWelcomeMessage = { _, _ in
        AudioBlock.mockWith(downloadUrl: URL(string: "https://example.com/welcome.m4a"))
      }
      $0.audioPlayer.startPlayback = { _, _ in
        PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    } operation: {
      let model = WelcomeMessagePageModel(
        station: .mockPlayola(
          id: "station-123", name: "Bordertown Radio", curatorName: "Radney Foster"))
      await model.task()

      #expect(model.nowPlayingSpin == nil)
      #expect(model.nowPlayingCardTitle == "Bordertown Radio")
      #expect(model.nowPlayingCardSubtitle == "with Radney Foster")
    }
  }

  // The card is live: the same fetched schedule yields a different airing track as the
  // clock advances past a spin boundary (no refetch, no player).
  @Test
  func testNowPlayingCardUpdatesAsScheduleAdvances() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let start = Date(timeIntervalSince1970: 1_000_000)
    let spins = [
      Spin.mockWith(
        id: "spin-1",
        airtime: start,
        stationId: "station-123",
        audioBlock: AudioBlock.mockWith(
          title: "First Song", artist: "A", endOfMessageMS: 60_000, type: "song")
      ),
      Spin.mockWith(
        id: "spin-2",
        airtime: start.addingTimeInterval(60),
        stationId: "station-123",
        audioBlock: AudioBlock.mockWith(
          title: "Second Song", artist: "B", endOfMessageMS: 60_000, type: "song")
      ),
    ]

    let model = await withDependencies {
      $0.date.now = start.addingTimeInterval(10)
      $0.analytics.track = { _ in }
      $0.stationPlayer = StationPlayerMock()
      $0.api.fetchSchedule = { _, _ in spins }
      $0.api.getStationWelcomeMessage = { _, _ in
        AudioBlock.mockWith(downloadUrl: URL(string: "https://example.com/welcome.m4a"))
      }
      $0.audioPlayer.startPlayback = { _, _ in
        PlaybackSession(play: {}, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    } operation: {
      let model = WelcomeMessagePageModel(station: .mockPlayola(id: "station-123"))
      await model.task()
      #expect(model.nowPlayingCardTitle == "First Song")
      return model
    }

    withDependencies {
      $0.date.now = start.addingTimeInterval(75)
    } operation: {
      #expect(model.nowPlayingSpin?.id == "spin-2")
      #expect(model.nowPlayingCardTitle == "Second Song")
    }
  }
}
