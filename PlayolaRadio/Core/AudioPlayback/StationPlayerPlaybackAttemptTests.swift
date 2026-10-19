import CustomDump
import Dependencies
import Sharing
import Testing

@testable import PlayolaRadio

private struct PlaybackStartTestError: Error {}

@Suite(.freshSharedState)
@MainActor
struct StationPlayerPlaybackAttemptTests {
  @Test
  func urlStationPlayReturnsFalseWhenStreamFails() async {
    let urlStreamPlayer = URLStreamPlayerMock()
    let stationPlayer = StationPlayer(urlStreamPlayer: urlStreamPlayer)
    let urlStation = UrlStation.mockWith()
    let station = AnyStation.url(urlStation)
    urlStreamPlayer.stateAfterSet = URLStreamPlayer.State(
      playbackState: .stopped,
      playerStatus: .error,
      currentStation: urlStation,
      nowPlaying: nil
    )

    let started = await withDependencies {
      $0.continuousClock = ContinuousClock()
    } operation: {
      await stationPlayer.play(station: station)
    }

    #expect(!started)
    expectNoDifference(stationPlayer.state.playbackStatus, .error)
  }

  @Test
  func urlStationPlayReturnsTrueAfterStreamStarts() async {
    let urlStreamPlayer = URLStreamPlayerMock()
    let stationPlayer = StationPlayer(urlStreamPlayer: urlStreamPlayer)
    let urlStation = UrlStation.mockWith()
    let station = AnyStation.url(urlStation)
    urlStreamPlayer.stateAfterSet = URLStreamPlayer.State(
      playbackState: .playing,
      playerStatus: .readyToPlay,
      currentStation: urlStation,
      nowPlaying: nil
    )

    let started = await withDependencies {
      $0.continuousClock = ContinuousClock()
    } operation: {
      await stationPlayer.play(station: station)
    }

    #expect(started)
    expectNoDifference(stationPlayer.state.playbackStatus, .playing(station))
  }

  @Test
  func urlStationPlayReturnsFalseAfterStartTimeout() async {
    let clock = TestClock()
    let urlStreamPlayer = URLStreamPlayerMock()
    let stationPlayer = StationPlayer(urlStreamPlayer: urlStreamPlayer)
    let urlStation = UrlStation.mockWith()
    let station = AnyStation.url(urlStation)
    urlStreamPlayer.stateAfterSet = URLStreamPlayer.State(
      playbackState: .stopped,
      playerStatus: .loading,
      currentStation: urlStation,
      nowPlaying: nil
    )

    let playTask = withDependencies {
      $0.continuousClock = clock
    } operation: {
      Task { await stationPlayer.play(station: station) }
    }
    await Task.yield()
    await clock.advance(by: .seconds(10))

    let started = await playTask.value
    #expect(!started)
  }

  @Test
  func repeatedUrlStationPlaySharesInFlightFailure() async {
    let urlStreamPlayer = URLStreamPlayerMock()
    urlStreamPlayer.shouldHoldPlayResult = true
    let stationPlayer = StationPlayer(urlStreamPlayer: urlStreamPlayer)
    let station = AnyStation.mockUrl()

    await withMainSerialExecutor {
      let firstPlayTask = Task { await stationPlayer.play(station: station) }
      await Task.yield()

      expectNoDifference(stationPlayer.state.playbackStatus, .loading(station))
      expectNoDifference(urlStreamPlayer.playCallCount, 1)

      let repeatedPlayTask = Task { await stationPlayer.play(station: station) }
      await Task.yield()

      expectNoDifference(urlStreamPlayer.playCallCount, 1)
      urlStreamPlayer.resolveHeldPlay(with: false)

      let firstStarted = await firstPlayTask.value
      let repeatedStarted = await repeatedPlayTask.value
      expectNoDifference([firstStarted, repeatedStarted], [false, false])
    }
  }

  @Test
  func sameStationStartingStateDoesNotReportSuccess() async {
    await withMainSerialExecutor {
      let urlStreamPlayer = URLStreamPlayerMock()
      urlStreamPlayer.shouldHoldPlayResult = true
      let stationPlayer = StationPlayer(urlStreamPlayer: urlStreamPlayer)
      let station = AnyStation.mockUrl()
      stationPlayer.state = StationPlayer.State(playbackStatus: .startingNewStation(station))

      let playTask = Task { await stationPlayer.play(station: station) }
      await Task.yield()

      expectNoDifference(urlStreamPlayer.playCallCount, 1)
      urlStreamPlayer.resolveHeldPlay(with: false)
      let started = await playTask.value
      expectNoDifference(started, false)
    }
  }

  @Test
  func sameStationPlayingReturnsTrueWithoutRestarting() async {
    let urlStreamPlayer = URLStreamPlayerMock()
    urlStreamPlayer.shouldHoldPlayResult = true
    let stationPlayer = StationPlayer(urlStreamPlayer: urlStreamPlayer)
    let station = AnyStation.mockUrl()
    stationPlayer.state = StationPlayer.State(playbackStatus: .playing(station))

    let started = await stationPlayer.play(station: station)

    #expect(started)
    expectNoDifference(urlStreamPlayer.playCallCount, 0)
  }

  @Test
  func handlePlayFailureReportsErrorToSentryWithPlaybackStartSource() async {
    var stationPlayer: StationPlayer!
    let (error, tags) = await withCheckedContinuation { continuation in
      stationPlayer = withDependencies {
        $0.errorReporting.reportError = { error, tags in
          continuation.resume(returning: (error, tags))
        }
      } operation: {
        StationPlayer()
      }
      stationPlayer.handlePlayFailure(PlaybackStartTestError())
    }

    #expect(error is PlaybackStartTestError)
    expectNoDifference(tags, ["source": "playback_start"])
  }

  @Test
  func handlePlayFailureDoesNotReportCancellation() async {
    var stationPlayer: StationPlayer!
    let reportedErrors = await withCheckedContinuation { continuation in
      let reported = LockIsolated<[Error]>([])
      stationPlayer = withDependencies {
        $0.errorReporting.reportError = { error, _ in
          reported.withValue { $0.append(error) }
          continuation.resume(returning: reported.value)
        }
      } operation: {
        StationPlayer()
      }
      stationPlayer.handlePlayFailure(CancellationError())
      stationPlayer.handlePlayFailure(PlaybackStartTestError())
    }

    #expect(reportedErrors.count == 1)
    #expect(reportedErrors.first is PlaybackStartTestError)
  }
}
