import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AMAPlaybackLifecycleTests {
  private let audioURL = URL(fileURLWithPath: "/tmp/answer.wav")

  private func noopAdd(_ qa: AMAQuestionAnswer) async throws {}

  @Test func disappearingWhileQuestionPlaybackStartsStopsTheLateSession() async {
    let stopped = LockIsolated(0)
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let question = ListenerQuestion.mockWith(audioBlock: .mockWith(downloadUrl: audioURL))
    let model = withDependencies {
      $0.audioPlayer.startPlayback = { _, _ in
        started.continuation.yield()
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        return PlaybackSession(
          play: {}, pause: {}, stop: { stopped.withValue { $0 += 1 } }, seek: { _ in },
          cancel: {})
      }
    } operation: {
      AMAAnswerQuestionPageModel(question: question, addToShow: noopAdd)
    }

    let playback = Task { await model.playQuestionButtonTapped() }
    var iterator = started.stream.makeAsyncIterator()
    await iterator.next()
    await model.viewDisappeared()
    release.continuation.yield()
    await playback.value

    expectNoDifference(stopped.value, 1)
  }

  @Test func disappearingWhileAnswerPlaybackStartsStopsTheLateSession() async {
    let stopped = LockIsolated(0)
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let model = withDependencies {
      $0.audioPlayer.startPlayback = { _, _ in
        started.continuation.yield()
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        return PlaybackSession(
          play: {}, pause: {}, stop: { stopped.withValue { $0 += 1 } }, seek: { _ in },
          cancel: {})
      }
    } operation: {
      AMAAnswerQuestionPageModel(
        answeredQuestion: .mockWith(answerAudioBlock: .mockWith(downloadUrl: audioURL)),
        addToShow: noopAdd)
    }

    let playback = Task { await model.answerPlayPauseButtonTapped() }
    var iterator = started.stream.makeAsyncIterator()
    await iterator.next()
    await model.viewDisappeared()
    release.continuation.yield()
    await playback.value

    expectNoDifference(stopped.value, 1)
  }

  @Test func completedAnswerStartsAFreshPlaybackSession() async {
    let starts = LockIsolated(0)
    let plays = LockIsolated(0)
    let states = LockIsolated<[@MainActor @Sendable (PlaybackState) -> Void]>([])
    let model = withDependencies {
      $0.audioPlayer.startPlayback = { _, update in
        starts.withValue { $0 += 1 }
        states.withValue { $0.append(update) }
        return PlaybackSession(
          play: { plays.withValue { $0 += 1 } }, pause: {}, stop: {}, seek: { _ in }, cancel: {})
      }
    } operation: {
      AMAAnswerQuestionPageModel(
        answeredQuestion: .mockWith(answerAudioBlock: .mockWith(downloadUrl: audioURL)),
        addToShow: noopAdd)
    }

    await model.answerPlayPauseButtonTapped()
    states.value[0](
      PlaybackState(currentTime: 10, duration: 10, isPlaying: false, didFinish: true))
    await model.answerPlayPauseButtonTapped()

    expectNoDifference(starts.value, 2)
    expectNoDifference(plays.value, 0)
  }
}
