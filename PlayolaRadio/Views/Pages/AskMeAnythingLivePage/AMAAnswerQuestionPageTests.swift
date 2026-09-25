//
//  AMAAnswerQuestionPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import SwiftUI
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AMAAnswerQuestionPageTests {

  private let recordingURL = URL(fileURLWithPath: "/tmp/answer.wav")

  private func noopAdd(_ qa: AMAQuestionAnswer) async throws {}

  // MARK: - Trailing Song Display

  @Test func displayedTrailingSongReflectsDraft() {
    let existing = AudioBlock.mockWith(id: "existing")
    let question = ListenerQuestion.mockWith(trailingAudioBlock: existing)
    let model = makeModel(question: question, addToShow: noopAdd)

    #expect(model.displayedTrailingSong?.id == "existing")
    #expect(!model.showAddSongButton)

    model.trailingDraft = .cleared
    #expect(model.displayedTrailingSong == nil)
    #expect(model.showAddSongButton)

    let picked = AudioBlock.mockWith(id: "picked")
    model.trailingDraft = .selected(picked)
    #expect(model.displayedTrailingSong?.id == "picked")
    #expect(!model.showAddSongButton)
  }

  // MARK: - Submit: Trailing PUT Semantics

  @Test func unchangedDraftSkipsTheTrailingPut() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let trailingCalls = LockIsolated(0)
    let model = makeSubmitModel(
      trailingDraft: .unchanged,
      onTrailing: { _ in trailingCalls.withValue { $0 += 1 } })

    await model.addToShowButtonTapped()

    #expect(trailingCalls.value == 0)
    #expect(model.submissionPhase == .completed)
  }

  @Test func clearedDraftSendsNullTrailingPut() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let capturedTrailing = LockIsolated<String??>(nil)
    let model = makeSubmitModel(
      trailingDraft: .cleared,
      existingTrailing: .mockWith(id: "old"),
      onTrailing: { id in capturedTrailing.setValue(id) })

    await model.addToShowButtonTapped()

    #expect(capturedTrailing.value == .some(.none))
    #expect(model.submissionPhase == .completed)
  }

  @Test func selectedDraftSendsBlockIdTrailingPut() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let capturedTrailing = LockIsolated<String??>(nil)
    let model = makeSubmitModel(
      trailingDraft: .selected(.mockWith(id: "new-song")),
      onTrailing: { id in capturedTrailing.setValue(id) })

    await model.addToShowButtonTapped()

    #expect(capturedTrailing.value == .some(.some("new-song")))
    #expect(model.submissionPhase == .completed)
  }

  // MARK: - Submit: Ordering

  @Test func submitRunsUploadThenAnswerThenTrailingThenAir() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let log = LockIsolated<[String]>([])
    let model = makeSubmitModel(
      trailingDraft: .selected(.mockWith(id: "song")),
      onUpload: { log.withValue { $0.append("upload") } },
      onRegister: { log.withValue { $0.append("register") } },
      onTrailing: { _ in log.withValue { $0.append("trailing") } },
      onAir: { log.withValue { $0.append("air") } })

    await model.addToShowButtonTapped()

    expectNoDifference(log.value, ["upload", "register", "trailing", "air"])
  }

  // MARK: - Submit: Success Navigation

  @Test func successfulSubmitMarksAiredAndPopsToLive() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let model = makeSubmitModel(
      trailingDraft: .unchanged,
      configureCoordinator: {
        nav.push(.askMeAnythingLivePage(AskMeAnythingLivePageModel(stationId: "s1")))
        nav.push(
          .amaQuestionPickerPage(
            AMAQuestionPickerPageModel(stationId: "s1", showStartedAt: nil, addToShow: { _ in })))
      })

    await model.addToShowButtonTapped()

    #expect(model.submissionPhase == .completed)
    #expect(!model.controlsInteractive)
    guard case .askMeAnythingLivePage = nav.path.last else {
      Issue.record("Expected to pop back to the live page")
      return
    }
  }

  // MARK: - Submit: Partial-Failure Resume

  @Test func retryAfterAirFailureDoesNotReUploadOrReRegister() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let uploadCalls = LockIsolated(0)
    let registerCalls = LockIsolated(0)
    let airAttempts = LockIsolated(0)
    let model = makeSubmitModel(
      trailingDraft: .unchanged,
      onUpload: { uploadCalls.withValue { $0 += 1 } },
      onRegister: { registerCalls.withValue { $0 += 1 } },
      onAir: {
        airAttempts.withValue { $0 += 1 }
        if airAttempts.value == 1 { throw NSError(domain: "offline", code: 1) }
      })

    await model.addToShowButtonTapped()
    #expect(
      model.submissionPhase
        == .failed(error: NSError(domain: "offline", code: 1).localizedDescription))
    #expect(!model.showReRecord)

    await model.recordButtonTapped()
    expectNoDifference(model.recordingPhase, .review)

    await model.addToShowButtonTapped()

    #expect(uploadCalls.value == 1)
    #expect(registerCalls.value == 1)
    #expect(airAttempts.value == 2)
    #expect(model.submissionPhase == .completed)
  }

  @Test func changingTrailingDraftAfterFailureReAppliesTheTrailing() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let trailingCalls = LockIsolated(0)
    let airAttempts = LockIsolated(0)
    let model = makeSubmitModel(
      trailingDraft: .selected(.mockWith(id: "first")),
      onTrailing: { _ in trailingCalls.withValue { $0 += 1 } },
      onAir: {
        airAttempts.withValue { $0 += 1 }
        if airAttempts.value == 1 { throw NSError(domain: "offline", code: 1) }
      })

    await model.addToShowButtonTapped()
    #expect(trailingCalls.value == 1)

    model.trailingDraft = .selected(.mockWith(id: "second"))
    await model.addToShowButtonTapped()

    #expect(trailingCalls.value == 2)
    #expect(model.submissionPhase == .completed)
  }

  // MARK: - Submit: Guards

  @Test func submitRequiresSignInWhenNoJwt() async {
    let uploadCalls = LockIsolated(0)
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: nil)
    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
      $0.voicetrackUploadService = VoicetrackUploadService(
        processVoicetrack: { _, _, _, _ in
          uploadCalls.withValue { $0 += 1 }
          return .mockWith(id: "a")
        })
    } operation: {
      AMAAnswerQuestionPageModel(question: .mock, addToShow: { _ in })
    }
    model.recordingPhase = .review
    model.recordingURL = recordingURL

    await model.addToShowButtonTapped()

    #expect(uploadCalls.value == 0)
    #expect(model.presentedAlert != nil)
  }

  @Test func submitIgnoredUnlessInReviewPhase() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let uploadCalls = LockIsolated(0)
    let model = makeSubmitModel(
      trailingDraft: .unchanged,
      onUpload: { uploadCalls.withValue { $0 += 1 } })
    model.recordingPhase = .idle

    await model.addToShowButtonTapped()

    #expect(uploadCalls.value == 0)
    #expect(model.submissionPhase == .notStarted)
  }

  @Test func backButtonIsIgnoredWhileSubmitting() {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let model = makeSubmitModel(trailingDraft: .unchanged)
    model.submissionPhase = .scheduling

    model.backButtonTapped()

    #expect(model.presentedAlert == nil)
  }

  @Test func disappearingWhileRecordingCancelsAndResetsRecordingState() async {
    let cancelled = LockIsolated(0)
    let model = withDependencies {
      $0.audioRecorder = AudioRecorderClient(
        requestPermission: { true }, prepareForRecording: {}, startRecording: {},
        stopRecording: { self.recordingURL }, currentTime: { 0 }, deleteRecording: { _ in },
        getAudioLevel: { 0 },
        startRecordingWithUpdates: { _ in
          RecordingSession(
            stop: { self.recordingURL },
            cancel: { cancelled.withValue { $0 += 1 } }, delete: { _ in })
        })
    } operation: {
      AMAAnswerQuestionPageModel(question: .mock, addToShow: noopAdd)
    }

    await model.recordButtonTapped()
    await model.viewDisappeared()

    expectNoDifference(cancelled.value, 1)
    expectNoDifference(model.recordingPhase, .idle)
    expectNoDifference(model.recordingState, .idle)
    expectNoDifference(model.recordingURL, nil)
  }

  @Test func disappearingWhileRecordingStartsCancelsTheLateSession() async {
    let cancelled = LockIsolated(0)
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let model = withDependencies {
      $0.audioRecorder.startRecordingWithUpdates = { _ in
        started.continuation.yield()
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        return RecordingSession(
          stop: { self.recordingURL },
          cancel: { cancelled.withValue { $0 += 1 } },
          delete: { _ in })
      }
    } operation: {
      AMAAnswerQuestionPageModel(question: .mock, addToShow: noopAdd)
    }

    let recording = Task { await model.recordButtonTapped() }
    var startedIterator = started.stream.makeAsyncIterator()
    await startedIterator.next()
    await model.viewDisappeared()
    release.continuation.yield()
    await recording.value

    expectNoDifference(cancelled.value, 1)
    expectNoDifference(model.recordingPhase, .idle)
  }

  @Test func stopTappedDuringRecordingStartupCancelsTheArrivingSession() async {
    let cancelled = LockIsolated(0)
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let model = withDependencies {
      $0.audioRecorder.startRecordingWithUpdates = { _ in
        started.continuation.yield()
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        return RecordingSession(
          stop: { self.recordingURL },
          cancel: { cancelled.withValue { $0 += 1 } },
          delete: { _ in })
      }
    } operation: {
      AMAAnswerQuestionPageModel(question: .mock, addToShow: noopAdd)
    }

    let starting = Task { await model.recordButtonTapped() }
    var startedIterator = started.stream.makeAsyncIterator()
    await startedIterator.next()
    await model.recordButtonTapped()

    expectNoDifference(model.recordingPhase, .idle)
    expectNoDifference(model.recordingURL, nil)

    release.continuation.yield()
    await starting.value

    expectNoDifference(cancelled.value, 1)
    expectNoDifference(model.recordingPhase, .idle)
    expectNoDifference(model.recordingURL, nil)
  }

  @Test func failedStartupFromACancelledTakeDoesNotResetTheNewRecording() async {
    let callCount = LockIsolated(0)
    let firstStarted = AsyncStream<Void>.makeStream()
    let releaseFirst = AsyncStream<Void>.makeStream()
    let model = withDependencies {
      $0.audioRecorder.startRecordingWithUpdates = { _ in
        let call = callCount.withValue {
          $0 += 1
          return $0
        }
        if call == 1 {
          firstStarted.continuation.yield()
          var iterator = releaseFirst.stream.makeAsyncIterator()
          await iterator.next()
          throw AudioRecorderError.noActiveRecording
        }
        return RecordingSession(
          stop: { self.recordingURL },
          cancel: {},
          delete: { _ in })
      }
    } operation: {
      AMAAnswerQuestionPageModel(question: .mock, addToShow: noopAdd)
    }

    let firstStart = Task { await model.recordButtonTapped() }
    var startedIterator = firstStarted.stream.makeAsyncIterator()
    await startedIterator.next()
    await model.recordButtonTapped()
    await model.recordButtonTapped()
    expectNoDifference(model.recordingPhase, .recording)

    releaseFirst.continuation.yield()
    await firstStart.value

    expectNoDifference(model.recordingPhase, .recording)
    #expect(model.presentedAlert == nil)
  }

  @Test func overlappingStopsOnlyStopTheRecordingSessionOnce() async {
    let stopCalls = LockIsolated(0)
    let gate = AsyncStream<Void>.makeStream()
    let started = AsyncStream<Void>.makeStream()
    let model = withDependencies {
      $0.audioRecorder.startRecordingWithUpdates = { _ in
        RecordingSession(
          stop: {
            stopCalls.withValue { $0 += 1 }
            started.continuation.yield(())
            var iterator = gate.stream.makeAsyncIterator()
            await iterator.next()
            return self.recordingURL
          }, cancel: {}, delete: { _ in })
      }
    } operation: {
      AMAAnswerQuestionPageModel(question: .mock, addToShow: noopAdd)
    }

    await model.recordButtonTapped()
    let firstStop = Task { await model.recordButtonTapped() }
    var startedIterator = started.stream.makeAsyncIterator()
    await startedIterator.next()
    await model.recordButtonTapped()
    gate.continuation.yield(())
    await firstStop.value

    expectNoDifference(stopCalls.value, 1)
    expectNoDifference(model.recordingPhase, .review)
  }

  @Test func reRecordingDeletesTheCompletedRecording() async {
    let deleted = LockIsolated<[URL]>([])
    let model = withDependencies {
      $0.audioRecorder.deleteRecording = { url in
        deleted.withValue { $0.append(url) }
      }
    } operation: {
      AMAAnswerQuestionPageModel(question: .mock, addToShow: noopAdd)
    }
    model.recordingPhase = .review
    model.recordingURL = recordingURL

    await model.recordButtonTapped()

    expectNoDifference(deleted.value, [recordingURL])
    expectNoDifference(model.recordingPhase, .idle)
  }

  @Test func successfulSubmitDeletesTheCompletedRecording() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let deleted = LockIsolated<[URL]>([])
    let model = makeSubmitModel(
      trailingDraft: .unchanged,
      onDelete: { url in deleted.withValue { $0.append(url) } })

    await model.addToShowButtonTapped()

    expectNoDifference(deleted.value, [recordingURL])
  }

  // MARK: - Helpers

  private func makeModel(
    question: ListenerQuestion,
    addToShow: @escaping @MainActor (AMAQuestionAnswer) async throws -> Void
  ) -> AMAAnswerQuestionPageModel {
    withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
      $0.voicetrackUploadService = .testValue
    } operation: {
      AMAAnswerQuestionPageModel(question: question, addToShow: addToShow)
    }
  }

  /// Builds a model already in the review phase with a recording, wired so `addToShowButtonTapped`
  /// runs the full submit pipeline. Each hook lets a test observe or fail a stage.
  private func makeSubmitModel(
    trailingDraft: AMATrailingSongDraft,
    existingTrailing: AudioBlock? = nil,
    configureCoordinator: () -> Void = {},
    onDelete: @escaping @Sendable (URL) -> Void = { _ in },
    onUpload: @escaping @Sendable () -> Void = {},
    onRegister: @escaping @Sendable () -> Void = {},
    onTrailing: @escaping @Sendable (String?) -> Void = { _ in },
    onAir: @escaping @Sendable () async throws -> Void = {}
  ) -> AMAAnswerQuestionPageModel {
    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
      $0.audioRecorder.deleteRecording = onDelete
      $0.voicetrackUploadService = VoicetrackUploadService(
        processVoicetrack: { _, _, _, _ in
          onUpload()
          return .mockWith(id: "answer-block")
        })
      $0.api.registerListenerQuestionAnswer = { _, _, _, _ in
        onRegister()
        return .mock
      }
      $0.api.updateListenerQuestionTrailingAudioBlock = { _, _, _, trailingId in
        onTrailing(trailingId)
        return .mock
      }
    } operation: {
      configureCoordinator()
      let model = AMAAnswerQuestionPageModel(
        question: .mockWith(
          id: "q1", stationId: "s1", audioBlock: .mockWith(id: "question-block"),
          trailingAudioBlock: existingTrailing),
        addToShow: { _ in try await onAir() })
      model.recordingPhase = .review
      model.recordingURL = recordingURL
      model.trailingDraft = trailingDraft
      return model
    }
    return model
  }

  /// Builds a review-mode model over an already-answered question, wired so a test can observe
  /// whether recording, upload, register, or trailing calls happen.
  private func makeReviewModel(
    existingTrailing: AudioBlock? = nil,
    onUpload: @escaping @Sendable () -> Void = {},
    onRegister: @escaping @Sendable () -> Void = {},
    onTrailing: @escaping @Sendable (String?) -> Void = { _ in },
    onAdd: @escaping @Sendable (AMAQuestionAnswer) async throws -> Void = { _ in }
  ) -> AMAAnswerQuestionPageModel {
    return withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
      $0.voicetrackUploadService = VoicetrackUploadService(
        processVoicetrack: { _, _, _, _ in
          onUpload()
          return .mockWith(id: "unexpected")
        })
      $0.api.registerListenerQuestionAnswer = { _, _, _, _ in
        onRegister()
        return .mock
      }
      $0.api.updateListenerQuestionTrailingAudioBlock = { _, _, _, trailingId in
        onTrailing(trailingId)
        return .mock
      }
    } operation: {
      AMAAnswerQuestionPageModel(
        answeredQuestion: .mockWith(
          id: "q1", stationId: "s1", status: .answered,
          audioBlock: .mockWith(id: "question-block"),
          answerAudioBlock: .mockWith(id: "answer-block"),
          trailingAudioBlock: existingTrailing),
        addToShow: onAdd)
    }
  }

  // MARK: - Review Mode

  @Test func reviewModeDoesNoRecorderOrUploadWork() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let uploadCalls = LockIsolated(0)
    let registerCalls = LockIsolated(0)
    let added = LockIsolated<[String]>([])
    let model = makeReviewModel(
      onUpload: { uploadCalls.withValue { $0 += 1 } },
      onRegister: { registerCalls.withValue { $0 += 1 } },
      onAdd: { qa in added.withValue { $0.append(qa.questionId) } })

    // `.testValue` audioRecorder reports an issue if any recorder endpoint is touched, so a
    // clean run here also proves review mode never prepares/records.
    await model.viewAppeared()
    await model.addToShowButtonTapped()

    #expect(uploadCalls.value == 0)
    #expect(registerCalls.value == 0)
    expectNoDifference(added.value, ["q1"])
    #expect(model.submissionPhase == .completed)
  }

  @Test func reviewModeWithUnchangedTrailingSkipsThePut() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let trailingCalls = LockIsolated(0)
    let model = makeReviewModel(
      existingTrailing: .mockWith(id: "existing"),
      onTrailing: { _ in trailingCalls.withValue { $0 += 1 } })

    await model.addToShowButtonTapped()

    #expect(trailingCalls.value == 0)
    #expect(model.submissionPhase == .completed)
  }

  @Test func reviewModeChangedTrailingSendsOnePutThenAdds() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let capturedTrailing = LockIsolated<String??>(nil)
    let added = LockIsolated<[String]>([])
    let model = makeReviewModel(
      existingTrailing: .mockWith(id: "existing"),
      onTrailing: { id in capturedTrailing.setValue(id) },
      onAdd: { qa in added.withValue { $0.append(qa.questionId) } })
    model.trailingDraft = .selected(.mockWith(id: "new-song"))

    await model.addToShowButtonTapped()

    #expect(capturedTrailing.value == .some(.some("new-song")))
    expectNoDifference(added.value, ["q1"])
    #expect(model.submissionPhase == .completed)
  }

  @Test func reviewModeRemovingTrailingAfterAFailedAddClearsItOnRetry() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var nav = MainContainerNavigationCoordinator()
    let trailingPuts = LockIsolated<[String?]>([])
    let addAttempts = LockIsolated(0)
    let added = LockIsolated<[String]>([])
    let model = makeReviewModel(
      onTrailing: { id in trailingPuts.withValue { $0.append(id) } },
      onAdd: { qa in
        addAttempts.withValue { $0 += 1 }
        if addAttempts.value == 1 { throw CancellationError() }
        added.withValue { $0.append(qa.questionId) }
      })

    model.trailingDraft = .selected(.mockWith(id: "song-b"))
    await model.addToShowButtonTapped()

    model.trailingDraft = .cleared
    await model.addToShowButtonTapped()

    expectNoDifference(trailingPuts.value, ["song-b", nil])
    expectNoDifference(added.value, ["q1"])
    #expect(model.submissionPhase == .completed)
  }
}
