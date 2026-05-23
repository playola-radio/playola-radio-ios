//
//  ListenerQuestionDetailPageTests.swift
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
struct ListenerQuestionDetailPageTests {

  // MARK: - Display Text Tests

  @Test
  func testNavigationTitleIsListenerQuestion() {
    let model = makeModel()
    #expect(model.navigationTitle == "Listener Question")
  }

  @Test
  func testQuestionSectionTitleIsQUESTION() {
    let model = makeModel()
    #expect(model.questionSectionTitle == "QUESTION")
  }

  @Test
  func testResponseSectionTitleIsYOURRESPONSE() {
    let model = makeModel()
    #expect(model.responseSectionTitle == "YOUR RESPONSE")
  }

  @Test
  func testDiscardButtonTitleIsDiscard() {
    let model = makeModel()
    #expect(model.discardButtonTitle == "Discard")
  }

  @Test
  func testUploadButtonTitleIsUploadResponse() {
    let model = makeModel()
    #expect(model.uploadButtonTitle == "Upload Response")
  }

  // MARK: - Listener Info Display Tests

  @Test
  func testListenerNameShowsFullName() {
    let model = makeModel(
      question: .mockWith(
        listener: .mockWith(firstName: "John", lastName: "Doe")
      ))
    #expect(model.listenerName == "John Doe")
  }

  @Test
  func testListenerNameShowsFirstNameOnlyWhenNoLastName() {
    let model = makeModel(
      question: .mockWith(
        listener: .mockWith(firstName: "John", lastName: nil)
      ))
    #expect(model.listenerName == "John")
  }

  @Test
  func testListenerNameShowsUnknownWhenNoListener() {
    let model = makeModel(question: .mockWith(listener: nil))
    #expect(model.listenerName == "Unknown Listener")
  }

  @Test
  func testListenerInitialsShowsBothInitials() {
    let model = makeModel(
      question: .mockWith(
        listener: .mockWith(firstName: "John", lastName: "Doe")
      ))
    #expect(model.listenerInitials == "JD")
  }

  @Test
  func testListenerInitialsShowsFirstInitialOnlyWhenNoLastName() {
    let model = makeModel(
      question: .mockWith(
        listener: .mockWith(firstName: "John", lastName: nil)
      ))
    #expect(model.listenerInitials == "J")
  }

  @Test
  func testListenerInitialsShowsQuestionMarkWhenNoListener() {
    let model = makeModel(question: .mockWith(listener: nil))
    #expect(model.listenerInitials == "?")
  }

  @Test
  func testListenerProfileImageUrlReturnsUrlWhenPresent() {
    let model = makeModel(
      question: .mockWith(
        listener: .mockWith(profileImageUrl: "https://example.com/image.jpg")
      ))
    #expect(model.listenerProfileImageUrl?.absoluteString == "https://example.com/image.jpg")
  }

  @Test
  func testListenerProfileImageUrlReturnsNilWhenNoUrl() {
    let model = makeModel(
      question: .mockWith(
        listener: .mockWith(profileImageUrl: nil)
      ))
    #expect(model.listenerProfileImageUrl == nil)
  }

  @Test
  func testListenerProfileImageUrlReturnsNilWhenNoListener() {
    let model = makeModel(question: .mockWith(listener: nil))
    #expect(model.listenerProfileImageUrl == nil)
  }

  // MARK: - Transcription Tests

  @Test
  func testTranscriptionShowsAudioBlockTranscription() {
    let audioBlock = AudioBlock.mockWith(transcription: "What's your favorite song?")
    let model = makeModel(question: .mockWith(audioBlock: audioBlock))
    #expect(model.transcription == "What's your favorite song?")
  }

  @Test
  func testTranscriptionShowsFallbackWhenNoAudioBlock() {
    let model = makeModel(question: .mockWith(audioBlock: nil))
    #expect(model.transcription == "No transcription available")
  }

  // MARK: - Recording Phase Tests

  @Test
  func testRecordButtonLabelInIdlePhase() {
    let model = makeModel()
    model.recordingPhase = .idle
    #expect(model.recordButtonLabel == "Tap to Record")
  }

  @Test
  func testRecordButtonLabelInRecordingPhase() {
    let model = makeModel()
    model.recordingPhase = .recording
    #expect(model.recordButtonLabel == "Tap to Stop")
  }

  @Test
  func testRecordButtonLabelInReviewPhase() {
    let model = makeModel()
    model.recordingPhase = .review
    #expect(model.recordButtonLabel == "Try Again")
  }

  @Test
  func testRecordButtonIconInIdlePhase() {
    let model = makeModel()
    model.recordingPhase = .idle
    #expect(model.recordButtonIcon == "mic.fill")
  }

  @Test
  func testRecordButtonIconInRecordingPhase() {
    let model = makeModel()
    model.recordingPhase = .recording
    #expect(model.recordButtonIcon == "stop.fill")
  }

  @Test
  func testRecordButtonIconInReviewPhase() {
    let model = makeModel()
    model.recordingPhase = .review
    #expect(model.recordButtonIcon == "mic.fill")
  }

  @Test
  func testShowRecordingIndicatorTrueWhenRecording() {
    let model = makeModel()
    model.recordingPhase = .recording
    #expect(model.showRecordingIndicator)
  }

  @Test
  func testShowRecordingIndicatorFalseWhenIdle() {
    let model = makeModel()
    model.recordingPhase = .idle
    #expect(!model.showRecordingIndicator)
  }

  @Test
  func testShowRecordingIndicatorFalseWhenReview() {
    let model = makeModel()
    model.recordingPhase = .review
    #expect(!model.showRecordingIndicator)
  }

  // MARK: - Waveform Display Tests

  @Test
  func testShowWaveformPlaceholderTrueWhenIdleAndNoSamples() {
    let model = makeModel()
    model.recordingPhase = .idle
    model.recordingState = .idle
    #expect(model.showWaveformPlaceholder)
  }

  @Test
  func testShowWaveformPlaceholderFalseWhenRecording() {
    let model = makeModel()
    model.recordingPhase = .recording
    #expect(!model.showWaveformPlaceholder)
  }

  @Test
  func testShowWaveformPlaceholderFalseWhenHasSamples() {
    let model = makeModel()
    model.recordingPhase = .idle
    model.recordingState = RecordingState(
      currentTime: 1.0, waveformSamples: [0.5], isRecording: false)
    #expect(!model.showWaveformPlaceholder)
  }

  @Test
  func testWaveformPlaceholderText() {
    let model = makeModel()
    #expect(model.waveformPlaceholderText == "Your recording will appear here")
  }

  // MARK: - Answer Playback Display Tests

  @Test
  func testShowAnswerPlaybackControlsTrueWhenReview() {
    let model = makeModel()
    model.recordingPhase = .review
    #expect(model.showAnswerPlaybackControls)
  }

  @Test
  func testShowAnswerPlaybackControlsFalseWhenIdle() {
    let model = makeModel()
    model.recordingPhase = .idle
    #expect(!model.showAnswerPlaybackControls)
  }

  @Test
  func testShowAnswerPlaybackControlsFalseWhenRecording() {
    let model = makeModel()
    model.recordingPhase = .recording
    #expect(!model.showAnswerPlaybackControls)
  }

  @Test
  func testShowAnswerActionButtonsTrueWhenReviewAndNotUploading() {
    let model = makeModel()
    model.recordingPhase = .review
    model.uploadPhase = .notStarted
    #expect(model.showAnswerActionButtons)
  }

  @Test
  func testShowAnswerActionButtonsFalseWhenUploading() {
    let model = makeModel()
    model.recordingPhase = .review
    model.uploadPhase = .uploading(progress: 0.5)
    #expect(!model.showAnswerActionButtons)
  }

  @Test
  func testShowAnswerActionButtonsFalseWhenCompleted() {
    let model = makeModel()
    model.recordingPhase = .review
    model.uploadPhase = .completed
    #expect(!model.showAnswerActionButtons)
  }

  // MARK: - Upload Phase Tests

  @Test
  func testIsUploadingFalseWhenNotStarted() {
    let model = makeModel()
    model.uploadPhase = .notStarted
    #expect(!model.isUploading)
  }

  @Test
  func testIsUploadingTrueWhenConverting() {
    let model = makeModel()
    model.uploadPhase = .converting
    #expect(model.isUploading)
  }

  @Test
  func testIsUploadingTrueWhenUploading() {
    let model = makeModel()
    model.uploadPhase = .uploading(progress: 0.5)
    #expect(model.isUploading)
  }

  @Test
  func testIsUploadingTrueWhenNormalizing() {
    let model = makeModel()
    model.uploadPhase = .normalizing
    #expect(model.isUploading)
  }

  @Test
  func testIsUploadingTrueWhenFinalizing() {
    let model = makeModel()
    model.uploadPhase = .finalizing
    #expect(model.isUploading)
  }

  @Test
  func testIsUploadingFalseWhenCompleted() {
    let model = makeModel()
    model.uploadPhase = .completed
    #expect(!model.isUploading)
  }

  @Test
  func testIsUploadingFalseWhenFailed() {
    let model = makeModel()
    model.uploadPhase = .failed(error: "Some error")
    #expect(!model.isUploading)
  }

  @Test
  func testUploadStatusTextNotStarted() {
    let model = makeModel()
    model.uploadPhase = .notStarted
    #expect(model.uploadStatusText == "")
  }

  @Test
  func testUploadStatusTextConverting() {
    let model = makeModel()
    model.uploadPhase = .converting
    #expect(model.uploadStatusText == "Converting audio...")
  }

  @Test
  func testUploadStatusTextUploading() {
    let model = makeModel()
    model.uploadPhase = .uploading(progress: 0.5)
    #expect(model.uploadStatusText == "Uploading 50%")
  }

  @Test
  func testUploadStatusTextNormalizing() {
    let model = makeModel()
    model.uploadPhase = .normalizing
    #expect(model.uploadStatusText == "Processing...")
  }

  @Test
  func testUploadStatusTextFinalizing() {
    let model = makeModel()
    model.uploadPhase = .finalizing
    #expect(model.uploadStatusText == "Finalizing...")
  }

  @Test
  func testUploadStatusTextCompleted() {
    let model = makeModel()
    model.uploadPhase = .completed
    #expect(model.uploadStatusText == "Complete!")
  }

  @Test
  func testUploadStatusTextFailed() {
    let model = makeModel()
    model.uploadPhase = .failed(error: "Network error")
    #expect(model.uploadStatusText == "Failed: Network error")
  }

  @Test
  func testUploadProgressNotStarted() {
    let model = makeModel()
    model.uploadPhase = .notStarted
    #expect(model.uploadProgress == 0)
  }

  @Test
  func testUploadProgressConverting() {
    let model = makeModel()
    model.uploadPhase = .converting
    #expect(model.uploadProgress == 0.1)
  }

  @Test
  func testUploadProgressUploading() {
    let model = makeModel()
    model.uploadPhase = .uploading(progress: 0.5)
    #expect(abs(model.uploadProgress - 0.35) < 0.01)
  }

  @Test
  func testUploadProgressNormalizing() {
    let model = makeModel()
    model.uploadPhase = .normalizing
    #expect(model.uploadProgress == 0.65)
  }

  @Test
  func testUploadProgressFinalizing() {
    let model = makeModel()
    model.uploadPhase = .finalizing
    #expect(model.uploadProgress == 0.75)
  }

  @Test
  func testUploadProgressCompleted() {
    let model = makeModel()
    model.uploadPhase = .completed
    #expect(model.uploadProgress == 1.0)
  }

  @Test
  func testUploadProgressFailed() {
    let model = makeModel()
    model.uploadPhase = .failed(error: "Error")
    #expect(model.uploadProgress == 0)
  }

  @Test
  func testCanRecordTrueWhenNotUploadingAndNotCompleted() {
    let model = makeModel()
    model.uploadPhase = .notStarted
    #expect(model.canRecord)
  }

  @Test
  func testCanRecordFalseWhenUploading() {
    let model = makeModel()
    model.uploadPhase = .uploading(progress: 0.5)
    #expect(!model.canRecord)
  }

  @Test
  func testCanRecordFalseWhenCompleted() {
    let model = makeModel()
    model.uploadPhase = .completed
    #expect(!model.canRecord)
  }

  @Test
  func testShowUploadStatusFalseWhenNotStarted() {
    let model = makeModel()
    model.uploadPhase = .notStarted
    #expect(!model.showUploadStatus)
  }

  @Test
  func testShowUploadStatusTrueWhenUploading() {
    let model = makeModel()
    model.uploadPhase = .uploading(progress: 0.5)
    #expect(model.showUploadStatus)
  }

  @Test
  func testShowUploadStatusTrueWhenLinkingAnswer() {
    let model = makeModel()
    model.uploadPhase = .linkingAnswer
    #expect(model.showUploadStatus)
  }

  // MARK: - Linking Answer Phase Tests

  @Test
  func testIsUploadingTrueWhenLinkingAnswer() {
    let model = makeModel()
    model.uploadPhase = .linkingAnswer
    #expect(model.isUploading)
  }

  @Test
  func testUploadStatusTextLinkingAnswer() {
    let model = makeModel()
    model.uploadPhase = .linkingAnswer
    #expect(model.uploadStatusText == "Registering response...")
  }

  @Test
  func testUploadProgressLinkingAnswer() {
    let model = makeModel()
    model.uploadPhase = .linkingAnswer
    #expect(model.uploadProgress == 0.85)
  }

  // MARK: - Upload Answer API Integration Tests

  @Test
  func testUploadButtonTappedCallsRegisterListenerQuestionAnswerAPI() async {
    let registerAnswerCalled = LockIsolated(false)
    let capturedStationId = LockIsolated<String?>(nil)
    let capturedQuestionId = LockIsolated<String?>(nil)
    let capturedAudioBlockId = LockIsolated<String?>(nil)

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
        registerAnswerCalled.setValue(true)
        capturedStationId.setValue(stationId)
        capturedQuestionId.setValue(questionId)
        capturedAudioBlockId.setValue(audioBlockId)
        return testQuestion
      }
    } operation: {
      ListenerQuestionDetailPageModel(question: testQuestion)
    }

    model.recordingPhase = AnswerRecordingPhase.review
    model.recordingURL = URL(fileURLWithPath: "/tmp/test-recording.wav")

    await model.uploadButtonTapped()

    #expect(registerAnswerCalled.value)
    #expect(capturedStationId.value == "test-station-789")
    #expect(capturedQuestionId.value == "test-question-123")
    #expect(capturedAudioBlockId.value == "uploaded-audio-block-456")
  }

  @Test
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

    #expect(model.uploadPhase == AnswerUploadPhase.completed)
  }

  @Test
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
      #expect(error == "Failed to link answer")
    } else {
      Issue.record("Expected failed phase, got: \(model.uploadPhase)")
    }
  }

  // MARK: - Question Playback Display Tests

  @Test
  func testQuestionPlayButtonIconShowsPlayWhenNotPlaying() {
    let model = makeModel()
    model.questionPlaybackState = .idle
    #expect(model.questionPlayButtonIcon == "play.fill")
  }

  @Test
  func testQuestionPlayButtonIconShowsStopWhenPlaying() {
    let model = makeModel()
    model.questionPlaybackState = PlaybackState(currentTime: 0, duration: 10, isPlaying: true)
    #expect(model.questionPlayButtonIcon == "stop.fill")
  }

  // MARK: - Answer Playback Display Tests

  @Test
  func testAnswerPlayButtonIconShowsPlayWhenNotPlaying() {
    let model = makeModel()
    model.answerPlaybackState = .idle
    #expect(model.answerPlayButtonIcon == "play.fill")
  }

  @Test
  func testAnswerPlayButtonIconShowsPauseWhenPlaying() {
    let model = makeModel()
    model.answerPlaybackState = PlaybackState(currentTime: 0, duration: 10, isPlaying: true)
    #expect(model.answerPlayButtonIcon == "pause.fill")
  }

  // MARK: - Recording Button Tapped Tests

  @Test
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

    #expect(startRecordingCalled.value)
  }

  @Test
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

    #expect(model.presentedAlert != nil)
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
