//
//  RecordWithMultiStepPromptTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct RecordWithMultiStepPromptTests {

  private func makeModel() -> RecordWithMultiStepPromptModel {
    withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
    } operation: {
      RecordWithMultiStepPromptModel(
        screenTitle: "Record Intro",
        eyebrow: "RECORD AN INTRO",
        guideBadge: "OPTIONAL GUIDE",
        title: "Record a short introduction.",
        subtitle: "Introduce the AMA and tell listeners how to send a question.",
        steps: [
          RecordPromptStep(id: 1, label: "INTRODUCE", detail: "Say hello."),
          RecordPromptStep(id: 2, label: "EXPLAIN", detail: "Explain the AMA."),
          RecordPromptStep(id: 3, label: "DIRECT", detail: "Tell them to tap Question."),
        ],
        trackLabel: "INTRO",
        isUpsideDown: true)
    }
  }

  // MARK: - Configured Content

  @Test func exposesConfiguredContent() {
    let model = makeModel()

    expectNoDifference(model.screenTitle, "Record Intro")
    expectNoDifference(model.eyebrow, "RECORD AN INTRO")
    expectNoDifference(model.guideBadge, "OPTIONAL GUIDE")
    expectNoDifference(model.title, "Record a short introduction.")
    expectNoDifference(
      model.subtitle, "Introduce the AMA and tell listeners how to send a question.")
    expectNoDifference(model.trackLabel, "INTRO")
    expectNoDifference(model.steps.count, 3)
  }

  // MARK: - Ready State

  @Test func appearsInReadyState() {
    let model = makeModel()

    expectNoDifference(model.recordingPhase, .ready)
    expectNoDifference(model.statusLabel, "READY")
    expectNoDifference(model.elapsedTime, "0:00")
    expectNoDifference(model.recordButtonTitle, "Start recording")
    expectNoDifference(model.recordButtonSystemImage, "mic.fill")
    #expect(model.showsCues)
    #expect(model.showsRecorder)
    #expect(!model.showsReview)
  }

  @Test func readyWaveformIsMuted() {
    let model = makeModel()

    #expect(model.waveformBars.allSatisfy { $0.color == .playolaTextTertiary })
  }

  @Test func waveformHasFifteenBars() {
    let model = makeModel()

    expectNoDifference(model.waveformBars.count, 15)
  }

  // MARK: - Recording Lifecycle

  @Test func recordButtonTappedStartsRecording() async {
    let startCalled = LockIsolated(false)
    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = AudioRecorderClient(
        requestPermission: { true },
        prepareForRecording: {},
        startRecording: {},
        stopRecording: { URL(fileURLWithPath: "/tmp/test.wav") },
        currentTime: { 0 },
        deleteRecording: { _ in },
        getAudioLevel: { 0 },
        startRecordingWithUpdates: { _ in
          startCalled.setValue(true)
          return RecordingSession(
            stop: { URL(fileURLWithPath: "/tmp/test.wav") }, cancel: {}, delete: { _ in })
        })
    } operation: {
      makeReadyModel()
    }

    await model.recordButtonTapped()

    #expect(startCalled.value)
    expectNoDifference(model.recordingPhase, .recording)
    expectNoDifference(model.statusLabel, "RECORDING")
    expectNoDifference(model.recordButtonTitle, "Stop recording")
    expectNoDifference(model.recordButtonSystemImage, "square.fill")
  }

  @Test func recordButtonTappedWhileRecordingMovesToReview() async {
    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = AudioRecorderClient(
        requestPermission: { true },
        prepareForRecording: {},
        startRecording: {},
        stopRecording: { URL(fileURLWithPath: "/tmp/recorded.wav") },
        currentTime: { 0 },
        deleteRecording: { _ in },
        getAudioLevel: { 0 },
        startRecordingWithUpdates: { _ in
          RecordingSession(
            stop: { URL(fileURLWithPath: "/tmp/recorded.wav") }, cancel: {}, delete: { _ in })
        })
    } operation: {
      makeReadyModel()
    }

    await model.recordButtonTapped()
    await model.recordButtonTapped()

    expectNoDifference(model.recordingPhase, .review)
    expectNoDifference(model.recordingURL, URL(fileURLWithPath: "/tmp/recorded.wav"))
    #expect(!model.showsRecorder)
    #expect(model.showsReview)
    expectNoDifference(model.reviewStatusLabel, "RECORDED")
    expectNoDifference(model.reRecordButtonTitle, "Re-record")
    expectNoDifference(model.useRecordingButtonTitle, "Use recording")
  }

  @Test func startRecordingDeniedShowsPermissionAlert() async {
    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = AudioRecorderClient(
        requestPermission: { false },
        prepareForRecording: {},
        startRecording: {},
        stopRecording: { URL(fileURLWithPath: "/tmp/test.wav") },
        currentTime: { 0 },
        deleteRecording: { _ in },
        getAudioLevel: { 0 },
        startRecordingWithUpdates: { _ in
          throw AudioRecorderError.permissionDenied
        })
    } operation: {
      makeReadyModel()
    }

    await model.recordButtonTapped()

    #expect(model.presentedAlert != nil)
    expectNoDifference(model.recordingPhase, .ready)
  }

  @Test func rapidRecordTapsStartOneRecording() async {
    let startCount = LockIsolated(0)
    let (started, startedContinuation) = AsyncStream<Void>.makeStream()
    let (release, releaseContinuation) = AsyncStream<Void>.makeStream()
    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = AudioRecorderClient(
        requestPermission: { true },
        prepareForRecording: {},
        startRecording: {},
        stopRecording: { URL(fileURLWithPath: "/tmp/test.wav") },
        currentTime: { 0 },
        deleteRecording: { _ in },
        getAudioLevel: { 0 },
        startRecordingWithUpdates: { _ in
          let count = startCount.withValue {
            $0 += 1
            return $0
          }
          if count == 1 {
            startedContinuation.yield()
            for await _ in release.prefix(1) {}
          }
          return RecordingSession(
            stop: { URL(fileURLWithPath: "/tmp/test.wav") }, cancel: {}, delete: { _ in })
        })
    } operation: {
      makeReadyModel()
    }

    let firstTap = Task { await model.recordButtonTapped() }
    for await _ in started.prefix(1) {}
    await model.recordButtonTapped()
    releaseContinuation.yield()
    await firstTap.value

    expectNoDifference(startCount.value, 1)
  }

  // MARK: - Review Actions

  @Test func reRecordReturnsToReadyState() async {
    let model = makeModel()
    model.recordingPhase = .review
    model.recordingURL = URL(fileURLWithPath: "/tmp/recorded.wav")

    await model.reRecordButtonTapped()

    expectNoDifference(model.recordingPhase, .ready)
    #expect(model.recordingURL == nil)
    #expect(model.showsRecorder)
  }

  @Test func useRecordingHandsOffThenPops() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let handedOff = LockIsolated<URL?>(nil)
    let deleted = LockIsolated<URL?>(nil)
    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
      $0.audioRecorder.deleteRecording = { deleted.setValue($0) }
    } operation: {
      makeReadyModel()
    }
    coordinator.push(.recordWithMultiStepPromptPage(model))
    model.recordingPhase = .review
    model.recordingURL = URL(fileURLWithPath: "/tmp/recorded.wav")
    model.onUseRecording = { url, _ in handedOff.setValue(url) }

    await model.useRecordingButtonTapped()

    expectNoDifference(handedOff.value, URL(fileURLWithPath: "/tmp/recorded.wav"))
    expectNoDifference(deleted.value, URL(fileURLWithPath: "/tmp/recorded.wav"))
    #expect(model.recordingURL == nil)
    #expect(model.presentedAlert == nil)
    #expect(coordinator.path.isEmpty)
  }

  @Test func rapidUseRecordingTapsStartOneUpload() async {
    let uploadCount = LockIsolated(0)
    let (started, startedContinuation) = AsyncStream<Void>.makeStream()
    let (release, releaseContinuation) = AsyncStream<Void>.makeStream()
    let model = makeModel()
    model.recordingPhase = .review
    model.recordingURL = URL(fileURLWithPath: "/tmp/recorded.wav")
    model.onUseRecording = { _, _ in
      let count = uploadCount.withValue {
        $0 += 1
        return $0
      }
      if count == 1 {
        startedContinuation.yield()
        for await _ in release.prefix(1) {}
      }
    }

    let firstTap = Task { await model.useRecordingButtonTapped() }
    for await _ in started.prefix(1) {}
    await model.useRecordingButtonTapped()
    releaseContinuation.yield()
    await firstTap.value

    expectNoDifference(uploadCount.value, 1)
  }

  @Test func useRecordingDrivesProgressToUploading() async {
    let model = makeModel()
    model.recordingPhase = .review
    model.recordingURL = URL(fileURLWithPath: "/tmp/recorded.wav")
    model.onUseRecording = { _, report in
      await report(.saving)
      await report(.uploading(0.5))
      await report(.finishing)
    }

    await model.useRecordingButtonTapped()

    expectNoDifference(model.recordingPhase, .uploading)
    expectNoDifference(model.uploadProgress, 1)
  }

  @Test func useRecordingFailureShowsErrorAndStaysInReview() async {
    let model = makeModel()
    model.recordingPhase = .review
    model.recordingURL = URL(fileURLWithPath: "/tmp/recorded.wav")
    model.onUseRecording = { _, _ in throw RecordPromptError.notAuthenticated }

    await model.useRecordingButtonTapped()

    #expect(model.presentedAlert != nil)
    expectNoDifference(model.recordingPhase, .review)
  }

  // MARK: - Progress Screen

  @Test func savingPhaseExposesStepOneContent() {
    let model = makeModel()
    model.recordingPhase = .saving

    expectNoDifference(model.navTitle, "Saving Recording")
    expectNoDifference(model.headerEyebrow, "SAVING RECORDING")
    expectNoDifference(model.headerBadge, "STEP 1 OF 2")
    expectNoDifference(model.headerTitle, "Uploading your recording\u{2026}")
    expectNoDifference(model.progressLabel, "Saving\u{2026}")
    expectNoDifference(model.progressValue, "Preparing")
    #expect(model.showsProgress)
    #expect(!model.showsReview)
    #expect(!model.showsRecorder)
    #expect(!model.backButtonEnabled)
  }

  @Test func uploadingPhaseShowsPercentAndCompletedFirstStep() {
    let model = makeModel()
    model.recordingPhase = .uploading
    model.uploadProgress = 0.68

    expectNoDifference(model.navTitle, "Uploading Recording")
    expectNoDifference(model.headerBadge, "STEP 2 OF 2")
    expectNoDifference(model.progressLabel, "Uploading\u{2026}")
    expectNoDifference(model.progressValue, "68%")
    expectNoDifference(model.progressFraction, 0.68)
    expectNoDifference(model.progressSteps.first?.label, "Saved on this device")
  }

  @Test func backButtonDuringUploadIsIgnored() {
    let model = makeModel()
    model.recordingPhase = .uploading

    model.backButtonTapped()

    #expect(model.presentedAlert == nil)
    expectNoDifference(model.recordingPhase, .uploading)
  }

  @Test func backButtonInReviewAsksToDiscard() {
    let model = makeModel()
    model.recordingPhase = .review
    model.recordingURL = URL(fileURLWithPath: "/tmp/recorded.wav")

    model.backButtonTapped()

    #expect(model.presentedAlert != nil)
    expectNoDifference(model.recordingPhase, .review)
  }

  // MARK: - Cue Helpers

  @Test func numberTextIsZeroPadded() {
    let model = makeModel()

    expectNoDifference(model.numberText(for: model.steps[0]), "01")
    expectNoDifference(model.numberText(for: model.steps[1]), "02")
    expectNoDifference(model.numberText(for: model.steps[2]), "03")
  }

  @Test func cueRowsUseNeutralColors() {
    let model = makeModel()

    expectNoDifference(model.cueNumberForegroundColor, .playolaTextSecondary)
    expectNoDifference(model.cueLabelColor, .playolaTextSecondary)
    expectNoDifference(model.cueNumberBackgroundColor, .playolaSurfaceControl)
  }

  @Test func dividerIsHiddenAfterLastStep() {
    let model = makeModel()

    expectNoDifference(model.dividerColor(after: model.steps[0]), .playolaGlassHairline)
    expectNoDifference(model.dividerColor(after: model.steps[2]), .clear)
  }

  // MARK: - Rotation & Chrome

  @Test func upsideDownRotatesHalfTurn() {
    let model = makeModel()

    expectNoDifference(model.rotationDegrees, 180)
  }

  @Test func rightSideUpDoesNotRotate() {
    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
    } operation: {
      RecordWithMultiStepPromptModel(
        screenTitle: "Record", eyebrow: "RECORD", guideBadge: nil,
        title: "Title", subtitle: nil,
        steps: [RecordPromptStep(id: 1, label: "ONE", detail: "First.")],
        trackLabel: "TRACK", isUpsideDown: false)
    }

    expectNoDifference(model.rotationDegrees, 0)
  }

  @Test func tabBarIsHidden() {
    let model = makeModel()

    #expect(model.tabBarVisibility == .hidden)
  }

  // MARK: - Factory & Navigation

  @Test func askMeAnythingIntroFactoryConfiguresThreeSteps() {
    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
    } operation: {
      RecordWithMultiStepPromptModel.askMeAnythingIntro(stationId: "station-abc")
    }

    expectNoDifference(model.steps.map(\.label), ["INTRODUCE", "EXPLAIN", "DIRECT"])
    #expect(model.isUpsideDown)
    #expect(model.onUseRecording != nil)
  }

  @Test func backButtonTappedPopsNavigation() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = makeModel()
    coordinator.push(.recordWithMultiStepPromptPage(model))

    model.backButtonTapped()

    #expect(coordinator.path.isEmpty)
  }

  @Test func recordIntroTappedPushesRecordPrompt() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let setup = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
    } operation: {
      AskMeAnythingSetupPageModel(stationId: "station-abc")
    }
    setup.recordIntroButtonTapped()

    expectNoDifference(coordinator.path.count, 1)
    guard case .recordWithMultiStepPromptPage = coordinator.path.last else {
      Issue.record("expected recordWithMultiStepPromptPage on the stack")
      return
    }
  }

  // MARK: - Helpers

  private func makeReadyModel() -> RecordWithMultiStepPromptModel {
    RecordWithMultiStepPromptModel(
      screenTitle: "Record Intro",
      eyebrow: "RECORD AN INTRO",
      guideBadge: "OPTIONAL GUIDE",
      title: "Record a short introduction.",
      subtitle: "Introduce the AMA and tell listeners how to send a question.",
      steps: [
        RecordPromptStep(id: 1, label: "INTRODUCE", detail: "Say hello."),
        RecordPromptStep(id: 2, label: "EXPLAIN", detail: "Explain the AMA."),
        RecordPromptStep(id: 3, label: "DIRECT", detail: "Tell them to tap Question."),
      ],
      trackLabel: "INTRO",
      isUpsideDown: true)
  }
}
