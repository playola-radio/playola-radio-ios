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

extension AMAPlaybackLifecycleTests {
  @Test(arguments: [0, 1, 2])
  func disappearanceDuringTeardownPreventsPlayback(kind: Int) async {
    let entered = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let starts = LockIsolated(0)
    let stops = LockIsolated(0)
    let model = withDependencies {
      $0.audioPlayer.startPlayback = { _, _ in
        starts.withValue { $0 += 1 }
        return PlaybackSession(
          play: {}, pause: {},
          stop: {
            let call = stops.withValue {
              $0 += 1
              return $0
            }
            if call == 1 {
              entered.continuation.yield()
              var iterator = release.stream.makeAsyncIterator()
              await iterator.next()
            }
          }, seek: { _ in }, cancel: {})
      }
    } operation: {
      reviewModel()
    }
    if kind == 1 {
      await model.playQuestionButtonTapped()
    } else {
      await model.answerPlayPauseButtonTapped()
      if kind == 2 {
        model.answerPlaybackState = PlaybackState(
          currentTime: 10, duration: 10, isPlaying: false, didFinish: true)
      }
    }
    let playback = Task {
      if kind == 0 {
        await model.playQuestionButtonTapped()
      } else {
        await model.answerPlayPauseButtonTapped()
      }
    }
    var iterator = entered.stream.makeAsyncIterator()
    await iterator.next()
    await model.viewDisappeared()
    release.continuation.yield()
    await playback.value
    expectNoDifference(starts.value, 1)
    expectNoDifference(model.questionPlaybackState, .idle)
    expectNoDifference(model.answerPlaybackState, .idle)
  }

  @Test(arguments: [false, true])
  func reversedStopsCannotClearNewPlayback(answer: Bool) async {
    let entered = AsyncStream<Void>.makeStream()
    let releases = [AsyncStream<Void>.makeStream(), AsyncStream<Void>.makeStream()]
    let starts = LockIsolated(0)
    let stops = LockIsolated(0)
    let model = withDependencies {
      $0.audioPlayer.startPlayback = { _, update in
        starts.withValue { $0 += 1 }
        await update(PlaybackState(currentTime: 1, duration: 10, isPlaying: true))
        return PlaybackSession(
          play: {}, pause: {},
          stop: {
            let index = stops.withValue {
              let index = $0
              $0 += 1
              return index
            }
            if index < 2 {
              entered.continuation.yield()
              var iterator = releases[index].stream.makeAsyncIterator()
              await iterator.next()
            }
          }, seek: { _ in }, cancel: {})
      }
    } operation: {
      reviewModel()
    }
    await play(model, answer: answer)
    let first = Task { await model.viewDisappeared() }
    var iterator = entered.stream.makeAsyncIterator()
    await iterator.next()
    let detached =
      answer ? model.answerPlaybackState == .idle : model.questionPlaybackState == .idle
    expectNoDifference(detached, true)
    guard detached else {
      releases[0].continuation.yield()
      await first.value
      return
    }
    await play(model, answer: answer)
    let second = Task { await model.viewDisappeared() }
    await iterator.next()
    await play(model, answer: answer)
    releases[1].continuation.yield()
    await second.value
    releases[0].continuation.yield()
    await first.value
    expectNoDifference(starts.value, 3)
    expectNoDifference(
      answer ? model.answerPlaybackState.isPlaying : model.questionPlaybackState.isPlaying, true)
  }
}

extension AMAPlaybackLifecycleTests {
  private func reviewModel() -> AMAAnswerQuestionPageModel {
    AMAAnswerQuestionPageModel(
      answeredQuestion: .mockWith(
        audioBlock: .mockWith(downloadUrl: audioURL),
        answerAudioBlock: .mockWith(downloadUrl: audioURL)), addToShow: noopAdd)
  }

  private func play(_ model: AMAAnswerQuestionPageModel, answer: Bool) async {
    if answer {
      await model.answerPlayPauseButtonTapped()
    } else {
      await model.playQuestionButtonTapped()
    }
  }
}
