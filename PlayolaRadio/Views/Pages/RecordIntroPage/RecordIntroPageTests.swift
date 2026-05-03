//
//  RecordIntroPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct RecordIntroPageTests {
  private func makeModel() -> RecordIntroPageModel {
    RecordIntroPageModel(
      songTitle: "Test", songArtist: "Artist", songImageUrl: nil,
      stationId: "station-1", audioBlockId: "block-1")
  }

  // MARK: - Initial Properties

  @Test
  func testInitialProperties() {
    let model = RecordIntroPageModel(
      songTitle: "Bohemian Rhapsody",
      songArtist: "Queen",
      songImageUrl: URL(string: "https://example.com/image.jpg"),
      stationId: "station-1",
      audioBlockId: "block-1"
    )

    #expect(model.songTitle == "Bohemian Rhapsody")
    #expect(model.songArtist == "Queen")
    #expect(model.songImageUrl == URL(string: "https://example.com/image.jpg"))
    #expect(model.navigationTitle == "Record Intro")
    #expect(model.instructionItems.count == 2)
    #expect(model.recordingPhase == .idle)
    #expect(model.uploadStatus == nil)
  }

  // MARK: - Lifecycle

  @Test
  func testViewAppearedPreparesForRecording() async {
    let prepareCalled = LockIsolated(false)

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {
        prepareCalled.setValue(true)
      }
    } operation: {
      let model = makeModel()

      await model.viewAppeared()

      #expect(prepareCalled.value)
    }
  }

  // MARK: - Done Button

  @Test
  func testShouldShowDoneButtonTrueOnlyInIdlePhase() {
    let model = makeModel()

    model.recordingPhase = .idle
    #expect(model.shouldShowDoneButton)

    model.recordingPhase = .recording
    #expect(!model.shouldShowDoneButton)

    model.recordingPhase = .review
    #expect(!model.shouldShowDoneButton)
  }

  @Test
  func testShouldShowDoneButtonFalseWhenUploading() {
    let model = makeModel()
    model.recordingPhase = .idle
    model.uploadStatus = .converting
    #expect(!model.shouldShowDoneButton)
  }

  @Test
  func testOnDoneTappedDismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = makeModel()
    coordinator.presentedSheet = .recordIntroPage(model)

    #expect(coordinator.presentedSheet != nil)

    model.onDoneTapped()

    #expect(coordinator.presentedSheet == nil)
  }

  // MARK: - Recording

  @Test
  func testOnRecordTappedRequestsPermissionBeforeRecording() async {
    let requestPermissionCalled = LockIsolated(false)
    let startRecordingCalled = LockIsolated(false)

    await withDependencies {
      $0.audioRecorder.requestPermission = {
        requestPermissionCalled.setValue(true)
        return true
      }
      $0.audioRecorder.startRecording = {
        #expect(
          requestPermissionCalled.value, "Permission should be requested before recording starts")
        startRecordingCalled.setValue(true)
      }
    } operation: {
      let model = makeModel()
      #expect(model.recordingPhase == .idle)

      await model.onRecordTapped()

      #expect(requestPermissionCalled.value)
      #expect(startRecordingCalled.value)
      #expect(model.recordingPhase == .recording)
    }
  }

  @Test
  func testOnRecordTappedDoesNotRecordWhenPermissionDenied() async {
    let startRecordingCalled = LockIsolated(false)

    await withDependencies {
      $0.audioRecorder.requestPermission = { false }
      $0.audioRecorder.startRecording = {
        startRecordingCalled.setValue(true)
      }
    } operation: {
      let model = makeModel()

      await model.onRecordTapped()

      #expect(
        !startRecordingCalled.value, "Recording should not start when permission is denied")
      #expect(model.recordingPhase == .idle)
      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Microphone Access Required")
    }
  }

  // MARK: - Stop Recording

  @Test
  func testOnStopTappedStopsRecordingAndChangesPhase() async {
    let expectedURL = URL(fileURLWithPath: "/tmp/test-recording.wav")

    await withDependencies {
      $0.audioRecorder.currentTime = { 5.0 }
      $0.audioRecorder.stopRecording = { expectedURL }
      $0.audioPlayer.loadFile = { _ in }
      $0.audioPlayer.duration = { 5.0 }
    } operation: {
      let model = makeModel()
      model.recordingPhase = .recording

      await model.onStopTapped()

      #expect(model.recordingPhase == .review)
      #expect(model.recordingURL == expectedURL)
      #expect(model.recordingDuration == 5.0)
    }
  }

  // MARK: - Re-record

  @Test
  func testOnReRecordTappedResetsToIdleState() async {
    let model = makeModel()
    model.recordingPhase = .review
    model.recordingURL = URL(fileURLWithPath: "/tmp/test.wav")
    model.recordingDuration = 10.0
    model.playbackPosition = 5.0
    model.isPlaying = true

    await model.onReRecordTapped()

    #expect(model.recordingPhase == .idle)
    #expect(model.recordingURL == nil)
    #expect(model.recordingDuration == 0)
    #expect(model.playbackPosition == 0)
    #expect(!model.isPlaying)
  }

  // MARK: - Discard

  @Test
  func testOnDiscardTappedShowsConfirmationAlert() {
    let model = makeModel()
    model.recordingPhase = .review

    #expect(model.presentedAlert == nil)

    model.onDiscardTapped()

    #expect(model.presentedAlert != nil)
    #expect(model.presentedAlert?.title == "Discard Recording?")
  }

  @Test
  func testConfirmDiscardDismissesSheet() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = makeModel()
    coordinator.presentedSheet = .recordIntroPage(model)

    await model.confirmDiscard()

    #expect(coordinator.presentedSheet == nil)
  }

  // MARK: - Accept Recording (Upload)

  @Test
  func testOnAcceptRecordingTappedStartsUpload() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let uploadCalled = LockIsolated(false)

    await withMainSerialExecutor {
      await withDependencies {
        $0.audioPlayer.stop = {}
        $0.continuousClock = ImmediateClock()
        $0.introUploadService.uploadIntro = { _, _, _, _, _, onStatus in
          uploadCalled.setValue(true)
          await onStatus(.completed)
        }
      } operation: {
        let model = makeModel()
        model.recordingURL = URL(fileURLWithPath: "/tmp/test.wav")
        model.recordingPhase = .review

        await model.onAcceptRecordingTapped()

        #expect(model.uploadStatus != nil)
        #expect(uploadCalled.value)
      }
    }
  }

  @Test
  func testOnAcceptRecordingTappedDoesNothingWithoutURL() async {
    let model = makeModel()
    model.recordingURL = nil

    await model.onAcceptRecordingTapped()

    #expect(model.uploadStatus == nil)
  }

  @Test
  func testUploadStatusTransitionsReflectedInProperties() {
    let model = makeModel()

    #expect(!model.isUploading)
    #expect(!model.shouldShowUploadStatus)
    #expect(!model.shouldShowRetryButton)
    #expect(model.uploadProgress == nil)

    model.uploadStatus = .converting
    #expect(model.isUploading)
    #expect(model.shouldShowUploadStatus)
    #expect(model.uploadStatusLabel == "Converting...")
    #expect(model.uploadProgress == nil)

    model.uploadStatus = .uploading(progress: 0.5)
    #expect(model.isUploading)
    #expect(model.uploadStatusLabel == "Uploading...")
    #expect(model.uploadProgress == 0.5)

    model.uploadStatus = .registering
    #expect(model.isUploading)
    #expect(model.uploadStatusLabel == "Registering...")
    #expect(model.uploadProgress == nil)

    model.uploadStatus = .completed
    #expect(!model.isUploading)
    #expect(model.shouldShowUploadStatus)
    #expect(model.uploadStatusLabel == "Upload Complete!")

    model.uploadStatus = .failed("Network error")
    #expect(!model.isUploading)
    #expect(model.shouldShowRetryButton)
    #expect(model.uploadStatusLabel == "Upload Failed")
  }

  @Test
  func testOnRetryTappedRestartsUpload() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let uploadCallCount = LockIsolated(0)

    await withMainSerialExecutor {
      await withDependencies {
        $0.audioPlayer.stop = {}
        $0.continuousClock = ImmediateClock()
        $0.introUploadService.uploadIntro = { _, _, _, _, _, onStatus in
          uploadCallCount.withValue { $0 += 1 }
          await onStatus(.completed)
        }
      } operation: {
        let model = makeModel()
        model.recordingURL = URL(fileURLWithPath: "/tmp/test.wav")
        model.uploadStatus = .failed("First attempt failed")

        await model.onRetryTapped()

        #expect(uploadCallCount.value == 1)
      }
    }
  }

  @Test
  func testUploadSuccessCallsOnUploadCompleted() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let completedCalled = LockIsolated(false)

    await withMainSerialExecutor {
      await withDependencies {
        $0.audioPlayer.stop = {}
        $0.continuousClock = ImmediateClock()
        $0.introUploadService.uploadIntro = { _, _, _, _, _, onStatus in
          await onStatus(.completed)
        }
      } operation: {
        let model = makeModel()
        model.recordingURL = URL(fileURLWithPath: "/tmp/test.wav")
        model.onUploadCompleted = {
          completedCalled.setValue(true)
        }

        await model.onAcceptRecordingTapped()

        #expect(completedCalled.value)
        #expect(model.uploadStatus == .completed)
      }
    }
  }
}
