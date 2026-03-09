//
//  ListenerQuestionDetailPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import PlayolaPlayer
import Sharing
import Testing
import XCTest

@testable import PlayolaRadio

@MainActor
final class ListenerQuestionDetailPageTests: XCTestCase {

  // MARK: - Display Text Tests

  func testNavigationTitleIsListenerQuestion() {
    let model = makeModel()
    XCTAssertEqual(model.navigationTitle, "Listener Question")
  }

  func testQuestionSectionTitleIsQUESTION() {
    let model = makeModel()
    XCTAssertEqual(model.questionSectionTitle, "QUESTION")
  }

  func testResponseSectionTitleIsYOURRESPONSE() {
    let model = makeModel()
    XCTAssertEqual(model.responseSectionTitle, "YOUR RESPONSE")
  }

  func testDiscardButtonTitleIsDiscard() {
    let model = makeModel()
    XCTAssertEqual(model.discardButtonTitle, "Discard")
  }

  func testUploadButtonTitleIsUploadResponse() {
    let model = makeModel()
    XCTAssertEqual(model.uploadButtonTitle, "Upload Response")
  }

  // MARK: - Listener Info Display Tests

  func testListenerNameShowsFullName() {
    let model = makeModel(
      question: .mockWith(
        listener: .mockWith(firstName: "John", lastName: "Doe")
      ))
    XCTAssertEqual(model.listenerName, "John Doe")
  }

  func testListenerNameShowsFirstNameOnlyWhenNoLastName() {
    let model = makeModel(
      question: .mockWith(
        listener: .mockWith(firstName: "John", lastName: nil)
      ))
    XCTAssertEqual(model.listenerName, "John")
  }

  func testListenerNameShowsUnknownWhenNoListener() {
    let model = makeModel(question: .mockWith(listener: nil))
    XCTAssertEqual(model.listenerName, "Unknown Listener")
  }

  func testListenerInitialsShowsBothInitials() {
    let model = makeModel(
      question: .mockWith(
        listener: .mockWith(firstName: "John", lastName: "Doe")
      ))
    XCTAssertEqual(model.listenerInitials, "JD")
  }

  func testListenerInitialsShowsFirstInitialOnlyWhenNoLastName() {
    let model = makeModel(
      question: .mockWith(
        listener: .mockWith(firstName: "John", lastName: nil)
      ))
    XCTAssertEqual(model.listenerInitials, "J")
  }

  func testListenerInitialsShowsQuestionMarkWhenNoListener() {
    let model = makeModel(question: .mockWith(listener: nil))
    XCTAssertEqual(model.listenerInitials, "?")
  }

  func testListenerProfileImageUrlReturnsUrlWhenPresent() {
    let model = makeModel(
      question: .mockWith(
        listener: .mockWith(profileImageUrl: "https://example.com/image.jpg")
      ))
    XCTAssertEqual(model.listenerProfileImageUrl?.absoluteString, "https://example.com/image.jpg")
  }

  func testListenerProfileImageUrlReturnsNilWhenNoUrl() {
    let model = makeModel(
      question: .mockWith(
        listener: .mockWith(profileImageUrl: nil)
      ))
    XCTAssertNil(model.listenerProfileImageUrl)
  }

  func testListenerProfileImageUrlReturnsNilWhenNoListener() {
    let model = makeModel(question: .mockWith(listener: nil))
    XCTAssertNil(model.listenerProfileImageUrl)
  }

  // MARK: - Transcription Tests

  func testTranscriptionShowsAudioBlockTranscription() {
    let audioBlock = AudioBlock.mockWith(transcription: "What's your favorite song?")
    let model = makeModel(question: .mockWith(audioBlock: audioBlock))
    XCTAssertEqual(model.transcription, "What's your favorite song?")
  }

  func testTranscriptionShowsFallbackWhenNoAudioBlock() {
    let model = makeModel(question: .mockWith(audioBlock: nil))
    XCTAssertEqual(model.transcription, "No transcription available")
  }

  // MARK: - Recording Phase Tests

  func testRecordButtonLabelInIdlePhase() {
    let model = makeModel()
    model.recordingPhase = .idle
    XCTAssertEqual(model.recordButtonLabel, "Tap to Record")
  }

  func testRecordButtonLabelInRecordingPhase() {
    let model = makeModel()
    model.recordingPhase = .recording
    XCTAssertEqual(model.recordButtonLabel, "Tap to Stop")
  }

  func testRecordButtonLabelInReviewPhase() {
    let model = makeModel()
    model.recordingPhase = .review
    XCTAssertEqual(model.recordButtonLabel, "Try Again")
  }

  func testRecordButtonIconInIdlePhase() {
    let model = makeModel()
    model.recordingPhase = .idle
    XCTAssertEqual(model.recordButtonIcon, "mic.fill")
  }

  func testRecordButtonIconInRecordingPhase() {
    let model = makeModel()
    model.recordingPhase = .recording
    XCTAssertEqual(model.recordButtonIcon, "stop.fill")
  }

  func testRecordButtonIconInReviewPhase() {
    let model = makeModel()
    model.recordingPhase = .review
    XCTAssertEqual(model.recordButtonIcon, "mic.fill")
  }

  func testShowRecordingIndicatorTrueWhenRecording() {
    let model = makeModel()
    model.recordingPhase = .recording
    XCTAssertTrue(model.showRecordingIndicator)
  }

  func testShowRecordingIndicatorFalseWhenIdle() {
    let model = makeModel()
    model.recordingPhase = .idle
    XCTAssertFalse(model.showRecordingIndicator)
  }

  func testShowRecordingIndicatorFalseWhenReview() {
    let model = makeModel()
    model.recordingPhase = .review
    XCTAssertFalse(model.showRecordingIndicator)
  }

  // MARK: - Waveform Display Tests

  func testShowWaveformPlaceholderTrueWhenIdleAndNoSamples() {
    let model = makeModel()
    model.recordingPhase = .idle
    model.recordingState = .idle
    XCTAssertTrue(model.showWaveformPlaceholder)
  }

  func testShowWaveformPlaceholderFalseWhenRecording() {
    let model = makeModel()
    model.recordingPhase = .recording
    XCTAssertFalse(model.showWaveformPlaceholder)
  }

  func testShowWaveformPlaceholderFalseWhenHasSamples() {
    let model = makeModel()
    model.recordingPhase = .idle
    model.recordingState = RecordingState(
      currentTime: 1.0, waveformSamples: [0.5], isRecording: false)
    XCTAssertFalse(model.showWaveformPlaceholder)
  }

  func testWaveformPlaceholderText() {
    let model = makeModel()
    XCTAssertEqual(model.waveformPlaceholderText, "Your recording will appear here")
  }

  // MARK: - Answer Playback Display Tests

  func testShowAnswerPlaybackControlsTrueWhenReview() {
    let model = makeModel()
    model.recordingPhase = .review
    XCTAssertTrue(model.showAnswerPlaybackControls)
  }

  func testShowAnswerPlaybackControlsFalseWhenIdle() {
    let model = makeModel()
    model.recordingPhase = .idle
    XCTAssertFalse(model.showAnswerPlaybackControls)
  }

  func testShowAnswerPlaybackControlsFalseWhenRecording() {
    let model = makeModel()
    model.recordingPhase = .recording
    XCTAssertFalse(model.showAnswerPlaybackControls)
  }

  func testShowAnswerActionButtonsTrueWhenReviewAndNotUploading() {
    let model = makeModel()
    model.recordingPhase = .review
    model.uploadPhase = .notStarted
    XCTAssertTrue(model.showAnswerActionButtons)
  }

  func testShowAnswerActionButtonsFalseWhenUploading() {
    let model = makeModel()
    model.recordingPhase = .review
    model.uploadPhase = .uploading(progress: 0.5)
    XCTAssertFalse(model.showAnswerActionButtons)
  }

  func testShowAnswerActionButtonsFalseWhenCompleted() {
    let model = makeModel()
    model.recordingPhase = .review
    model.uploadPhase = .completed
    XCTAssertFalse(model.showAnswerActionButtons)
  }

  // MARK: - Upload Phase Tests

  func testIsUploadingFalseWhenNotStarted() {
    let model = makeModel()
    model.uploadPhase = .notStarted
    XCTAssertFalse(model.isUploading)
  }

  func testIsUploadingTrueWhenConverting() {
    let model = makeModel()
    model.uploadPhase = .converting
    XCTAssertTrue(model.isUploading)
  }

  func testIsUploadingTrueWhenUploading() {
    let model = makeModel()
    model.uploadPhase = .uploading(progress: 0.5)
    XCTAssertTrue(model.isUploading)
  }

  func testIsUploadingTrueWhenNormalizing() {
    let model = makeModel()
    model.uploadPhase = .normalizing
    XCTAssertTrue(model.isUploading)
  }

  func testIsUploadingTrueWhenFinalizing() {
    let model = makeModel()
    model.uploadPhase = .finalizing
    XCTAssertTrue(model.isUploading)
  }

  func testIsUploadingFalseWhenCompleted() {
    let model = makeModel()
    model.uploadPhase = .completed
    XCTAssertFalse(model.isUploading)
  }

  func testIsUploadingFalseWhenFailed() {
    let model = makeModel()
    model.uploadPhase = .failed(error: "Some error")
    XCTAssertFalse(model.isUploading)
  }

  func testUploadStatusTextNotStarted() {
    let model = makeModel()
    model.uploadPhase = .notStarted
    XCTAssertEqual(model.uploadStatusText, "")
  }

  func testUploadStatusTextConverting() {
    let model = makeModel()
    model.uploadPhase = .converting
    XCTAssertEqual(model.uploadStatusText, "Converting audio...")
  }

  func testUploadStatusTextUploading() {
    let model = makeModel()
    model.uploadPhase = .uploading(progress: 0.5)
    XCTAssertEqual(model.uploadStatusText, "Uploading 50%")
  }

  func testUploadStatusTextNormalizing() {
    let model = makeModel()
    model.uploadPhase = .normalizing
    XCTAssertEqual(model.uploadStatusText, "Processing...")
  }

  func testUploadStatusTextFinalizing() {
    let model = makeModel()
    model.uploadPhase = .finalizing
    XCTAssertEqual(model.uploadStatusText, "Finalizing...")
  }

  func testUploadStatusTextCompleted() {
    let model = makeModel()
    model.uploadPhase = .completed
    XCTAssertEqual(model.uploadStatusText, "Complete!")
  }

  func testUploadStatusTextFailed() {
    let model = makeModel()
    model.uploadPhase = .failed(error: "Network error")
    XCTAssertEqual(model.uploadStatusText, "Failed: Network error")
  }

  func testUploadProgressNotStarted() {
    let model = makeModel()
    model.uploadPhase = .notStarted
    XCTAssertEqual(model.uploadProgress, 0)
  }

  func testUploadProgressConverting() {
    let model = makeModel()
    model.uploadPhase = .converting
    XCTAssertEqual(model.uploadProgress, 0.1)
  }

  func testUploadProgressUploading() {
    let model = makeModel()
    model.uploadPhase = .uploading(progress: 0.5)
    XCTAssertEqual(model.uploadProgress, 0.35, accuracy: 0.01)
  }

  func testUploadProgressNormalizing() {
    let model = makeModel()
    model.uploadPhase = .normalizing
    XCTAssertEqual(model.uploadProgress, 0.65)
  }

  func testUploadProgressFinalizing() {
    let model = makeModel()
    model.uploadPhase = .finalizing
    XCTAssertEqual(model.uploadProgress, 0.75)
  }

  func testUploadProgressCompleted() {
    let model = makeModel()
    model.uploadPhase = .completed
    XCTAssertEqual(model.uploadProgress, 1.0)
  }

  func testUploadProgressFailed() {
    let model = makeModel()
    model.uploadPhase = .failed(error: "Error")
    XCTAssertEqual(model.uploadProgress, 0)
  }

  func testCanRecordTrueWhenNotUploadingAndNotCompleted() {
    let model = makeModel()
    model.uploadPhase = .notStarted
    XCTAssertTrue(model.canRecord)
  }

  func testCanRecordFalseWhenUploading() {
    let model = makeModel()
    model.uploadPhase = .uploading(progress: 0.5)
    XCTAssertFalse(model.canRecord)
  }

  func testCanRecordFalseWhenCompleted() {
    let model = makeModel()
    model.uploadPhase = .completed
    XCTAssertFalse(model.canRecord)
  }

  func testShowUploadStatusFalseWhenNotStarted() {
    let model = makeModel()
    model.uploadPhase = .notStarted
    XCTAssertFalse(model.showUploadStatus)
  }

  func testShowUploadStatusTrueWhenUploading() {
    let model = makeModel()
    model.uploadPhase = .uploading(progress: 0.5)
    XCTAssertTrue(model.showUploadStatus)
  }

  func testShowUploadStatusTrueWhenLinkingAnswer() {
    let model = makeModel()
    model.uploadPhase = .linkingAnswer
    XCTAssertTrue(model.showUploadStatus)
  }

  // MARK: - Linking Answer Phase Tests

  func testIsUploadingTrueWhenLinkingAnswer() {
    let model = makeModel()
    model.uploadPhase = .linkingAnswer
    XCTAssertTrue(model.isUploading)
  }

  func testUploadStatusTextLinkingAnswer() {
    let model = makeModel()
    model.uploadPhase = .linkingAnswer
    XCTAssertEqual(model.uploadStatusText, "Registering response...")
  }

  func testUploadProgressLinkingAnswer() {
    let model = makeModel()
    model.uploadPhase = .linkingAnswer
    XCTAssertEqual(model.uploadProgress, 0.85)
  }

  // MARK: - Upload Answer API Integration Tests

  func testUploadButtonTappedCallsRegisterListenerQuestionAnswerAPI() async {
    var registerAnswerCalled = false
    var capturedStationId: String?
    var capturedQuestionId: String?
    var capturedAudioBlockId: String?

    let testQuestion = ListenerQuestion.mockWith(
      id: "test-question-123",
      stationId: "test-station-789"
    )
    let testAudioBlock = AudioBlock.mockWith(id: "uploaded-audio-block-456")

    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")

    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
      $0.voicetrackUploadService = VoicetrackUploadService(
        processVoicetrack: { _, _, _, onStatusChange in
          await onStatusChange(.completed)
          return testAudioBlock
        }
      )
      $0.api.registerListenerQuestionAnswer = { _, stationId, questionId, audioBlockId in
        registerAnswerCalled = true
        capturedStationId = stationId
        capturedQuestionId = questionId
        capturedAudioBlockId = audioBlockId
        return testQuestion
      }
    } operation: {
      ListenerQuestionDetailPageModel(question: testQuestion)
    }

    model.recordingPhase = AnswerRecordingPhase.review
    model.recordingURL = URL(fileURLWithPath: "/tmp/test-recording.wav")

    await model.uploadButtonTapped()

    XCTAssertTrue(registerAnswerCalled)
    XCTAssertEqual(capturedStationId, "test-station-789")
    XCTAssertEqual(capturedQuestionId, "test-question-123")
    XCTAssertEqual(capturedAudioBlockId, "uploaded-audio-block-456")
  }

  func testUploadButtonTappedSetsLinkingAnswerPhase() async {
    let testQuestion = ListenerQuestion.mockWith(
      id: "test-question-123",
      stationId: "test-station-789"
    )
    let testAudioBlock = AudioBlock.mockWith(id: "uploaded-audio-block-456")

    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")

    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
      $0.voicetrackUploadService = VoicetrackUploadService(
        processVoicetrack: { _, _, _, onStatusChange in
          await onStatusChange(.completed)
          return testAudioBlock
        }
      )
      $0.api.registerListenerQuestionAnswer = { _, _, _, _ in
        return testQuestion
      }
    } operation: {
      ListenerQuestionDetailPageModel(question: testQuestion)
    }

    model.recordingPhase = AnswerRecordingPhase.review
    model.recordingURL = URL(fileURLWithPath: "/tmp/test-recording.wav")

    await model.uploadButtonTapped()

    XCTAssertEqual(model.uploadPhase, AnswerUploadPhase.completed)
  }

  func testUploadButtonTappedSetsFailedPhaseOnAPIError() async {
    let testQuestion = ListenerQuestion.mockWith(
      id: "test-question-123",
      stationId: "test-station-789"
    )
    let testAudioBlock = AudioBlock.mockWith(id: "uploaded-audio-block-456")

    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: "test-jwt")

    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
      $0.voicetrackUploadService = VoicetrackUploadService(
        processVoicetrack: { _, _, _, onStatusChange in
          await onStatusChange(.completed)
          return testAudioBlock
        }
      )
      $0.api.registerListenerQuestionAnswer = { _, _, _, _ in
        throw APIError.validationError("Failed to link answer")
      }
    } operation: {
      ListenerQuestionDetailPageModel(question: testQuestion)
    }

    model.recordingPhase = AnswerRecordingPhase.review
    model.recordingURL = URL(fileURLWithPath: "/tmp/test-recording.wav")

    await model.uploadButtonTapped()

    if case .failed(let error) = model.uploadPhase {
      XCTAssertEqual(error, "Failed to link answer")
    } else {
      XCTFail("Expected failed phase, got: \(model.uploadPhase)")
    }
  }

  // MARK: - Question Playback Display Tests

  func testQuestionPlayButtonIconShowsPlayWhenNotPlaying() {
    let model = makeModel()
    model.questionPlaybackState = .idle
    XCTAssertEqual(model.questionPlayButtonIcon, "play.fill")
  }

  func testQuestionPlayButtonIconShowsStopWhenPlaying() {
    let model = makeModel()
    model.questionPlaybackState = PlaybackState(currentTime: 0, duration: 10, isPlaying: true)
    XCTAssertEqual(model.questionPlayButtonIcon, "stop.fill")
  }

  // MARK: - Answer Playback Display Tests

  func testAnswerPlayButtonIconShowsPlayWhenNotPlaying() {
    let model = makeModel()
    model.answerPlaybackState = .idle
    XCTAssertEqual(model.answerPlayButtonIcon, "play.fill")
  }

  func testAnswerPlayButtonIconShowsPauseWhenPlaying() {
    let model = makeModel()
    model.answerPlaybackState = PlaybackState(currentTime: 0, duration: 10, isPlaying: true)
    XCTAssertEqual(model.answerPlayButtonIcon, "pause.fill")
  }

  // MARK: - Recording Button Tapped Tests

  func testRecordButtonTappedRequestsPermissionWhenIdle() async {
    let startRecordingCalled = LockIsolated(false)
    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.voicetrackUploadService = .testValue
      $0.audioRecorder = AudioRecorderClient(
        requestPermission: { true },
        prepareForRecording: {},
        startRecording: {},
        stopRecording: { URL(fileURLWithPath: "/tmp/test.wav") },
        currentTime: { 0 },
        deleteRecording: { _ in },
        getAudioLevel: { 0 },
        startRecordingWithUpdates: { _ in
          startRecordingCalled.setValue(true)
          return RecordingSession(
            stop: { URL(fileURLWithPath: "/tmp/test.wav") }, cancel: {}, delete: { _ in })
        }
      )
    } operation: {
      ListenerQuestionDetailPageModel(question: .mock)
    }

    model.recordingPhase = .idle
    await model.recordButtonTapped()

    XCTAssertTrue(startRecordingCalled.value)
  }

  func testRecordButtonTappedShowsPermissionAlertWhenDenied() async {
    let model = withDependencies {
      $0.audioPlayer = .testValue
      $0.voicetrackUploadService = .testValue
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
        }
      )
    } operation: {
      ListenerQuestionDetailPageModel(question: .mock)
    }

    model.recordingPhase = .idle
    await model.recordButtonTapped()

    XCTAssertNotNil(model.presentedAlert)
  }

  // MARK: - Helper

  private func makeModel(question: ListenerQuestion = .mock) -> ListenerQuestionDetailPageModel {
    withDependencies {
      $0.audioPlayer = .testValue
      $0.audioRecorder = .testValue
      $0.voicetrackUploadService = .testValue
    } operation: {
      ListenerQuestionDetailPageModel(question: question)
    }
  }
}
