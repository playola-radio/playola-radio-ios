//
//  RecordIntroPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class RecordIntroPageTests: XCTestCase {
  override func setUp() {
    super.setUp()
    @Shared(.mainContainerNavigationCoordinator) var coordinator
    coordinator.presentedSheet = nil
  }

  private func makeModel() -> RecordIntroPageModel {
    RecordIntroPageModel(
      songTitle: "Test", songArtist: "Artist", songImageUrl: nil,
      stationId: "station-1", audioBlockId: "block-1")
  }

  // MARK: - Initial Properties

  func testInitialProperties() {
    let model = RecordIntroPageModel(
      songTitle: "Bohemian Rhapsody",
      songArtist: "Queen",
      songImageUrl: URL(string: "https://example.com/image.jpg"),
      stationId: "station-1",
      audioBlockId: "block-1"
    )

    XCTAssertEqual(model.songTitle, "Bohemian Rhapsody")
    XCTAssertEqual(model.songArtist, "Queen")
    XCTAssertEqual(model.songImageUrl, URL(string: "https://example.com/image.jpg"))
    XCTAssertEqual(model.navigationTitle, "Record Intro")
    XCTAssertEqual(model.instructionItems.count, 2)
    XCTAssertEqual(model.recordingPhase, .idle)
    XCTAssertNil(model.uploadStatus)
  }

  // MARK: - Lifecycle

  func testViewAppearedPreparesForRecording() async {
    let prepareCalled = LockIsolated(false)

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {
        prepareCalled.setValue(true)
      }
    } operation: {
      let model = makeModel()

      await model.viewAppeared()

      XCTAssertTrue(prepareCalled.value)
    }
  }

  // MARK: - Done Button

  func testShouldShowDoneButtonTrueOnlyInIdlePhase() {
    let model = makeModel()

    model.recordingPhase = .idle
    XCTAssertTrue(model.shouldShowDoneButton)

    model.recordingPhase = .recording
    XCTAssertFalse(model.shouldShowDoneButton)

    model.recordingPhase = .review
    XCTAssertFalse(model.shouldShowDoneButton)
  }

  func testShouldShowDoneButtonFalseWhenUploading() {
    let model = makeModel()
    model.recordingPhase = .idle
    model.uploadStatus = .converting
    XCTAssertFalse(model.shouldShowDoneButton)
  }

  func testOnDoneTappedDismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let model = makeModel()
    coordinator.presentedSheet = .recordIntroPage(model)

    XCTAssertNotNil(coordinator.presentedSheet)

    model.onDoneTapped()

    XCTAssertNil(coordinator.presentedSheet)
  }

  // MARK: - Recording

  func testOnRecordTappedRequestsPermissionBeforeRecording() async {
    let requestPermissionCalled = LockIsolated(false)
    let startRecordingCalled = LockIsolated(false)

    await withDependencies {
      $0.audioRecorder.requestPermission = {
        requestPermissionCalled.setValue(true)
        return true
      }
      $0.audioRecorder.startRecording = {
        XCTAssertTrue(
          requestPermissionCalled.value, "Permission should be requested before recording starts")
        startRecordingCalled.setValue(true)
      }
    } operation: {
      let model = makeModel()
      XCTAssertEqual(model.recordingPhase, .idle)

      await model.onRecordTapped()

      XCTAssertTrue(requestPermissionCalled.value)
      XCTAssertTrue(startRecordingCalled.value)
      XCTAssertEqual(model.recordingPhase, .recording)
    }
  }

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

      XCTAssertFalse(
        startRecordingCalled.value, "Recording should not start when permission is denied")
      XCTAssertEqual(model.recordingPhase, .idle)
      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Microphone Access Required")
    }
  }

  // MARK: - Stop Recording

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

      XCTAssertEqual(model.recordingPhase, .review)
      XCTAssertEqual(model.recordingURL, expectedURL)
      XCTAssertEqual(model.recordingDuration, 5.0)
    }
  }

  // MARK: - Re-record

  func testOnReRecordTappedResetsToIdleState() async {
    let model = makeModel()
    model.recordingPhase = .review
    model.recordingURL = URL(fileURLWithPath: "/tmp/test.wav")
    model.recordingDuration = 10.0
    model.playbackPosition = 5.0
    model.isPlaying = true

    await model.onReRecordTapped()

    XCTAssertEqual(model.recordingPhase, .idle)
    XCTAssertNil(model.recordingURL)
    XCTAssertEqual(model.recordingDuration, 0)
    XCTAssertEqual(model.playbackPosition, 0)
    XCTAssertFalse(model.isPlaying)
  }

  // MARK: - Discard

  func testOnDiscardTappedShowsConfirmationAlert() {
    let model = makeModel()
    model.recordingPhase = .review

    XCTAssertNil(model.presentedAlert)

    model.onDiscardTapped()

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Discard Recording?")
  }

  func testConfirmDiscardDismissesSheet() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let model = makeModel()
    coordinator.presentedSheet = .recordIntroPage(model)

    await model.confirmDiscard()

    XCTAssertNil(coordinator.presentedSheet)
  }

  // MARK: - Accept Recording (Upload)

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

        XCTAssertNotNil(model.uploadStatus)
        XCTAssertTrue(uploadCalled.value)
      }
    }
  }

  func testOnAcceptRecordingTappedDoesNothingWithoutURL() async {
    let model = makeModel()
    model.recordingURL = nil

    await model.onAcceptRecordingTapped()

    XCTAssertNil(model.uploadStatus)
  }

  func testUploadStatusTransitionsReflectedInProperties() {
    let model = makeModel()

    XCTAssertFalse(model.isUploading)
    XCTAssertFalse(model.shouldShowUploadStatus)
    XCTAssertFalse(model.shouldShowRetryButton)
    XCTAssertNil(model.uploadProgress)

    model.uploadStatus = .converting
    XCTAssertTrue(model.isUploading)
    XCTAssertTrue(model.shouldShowUploadStatus)
    XCTAssertEqual(model.uploadStatusLabel, "Converting...")
    XCTAssertNil(model.uploadProgress)

    model.uploadStatus = .uploading(progress: 0.5)
    XCTAssertTrue(model.isUploading)
    XCTAssertEqual(model.uploadStatusLabel, "Uploading...")
    XCTAssertEqual(model.uploadProgress, 0.5)

    model.uploadStatus = .registering
    XCTAssertTrue(model.isUploading)
    XCTAssertEqual(model.uploadStatusLabel, "Registering...")
    XCTAssertNil(model.uploadProgress)

    model.uploadStatus = .completed
    XCTAssertFalse(model.isUploading)
    XCTAssertTrue(model.shouldShowUploadStatus)
    XCTAssertEqual(model.uploadStatusLabel, "Upload Complete!")

    model.uploadStatus = .failed("Network error")
    XCTAssertFalse(model.isUploading)
    XCTAssertTrue(model.shouldShowRetryButton)
    XCTAssertEqual(model.uploadStatusLabel, "Upload Failed")
  }

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

        XCTAssertEqual(uploadCallCount.value, 1)
      }
    }
  }

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

        XCTAssertTrue(completedCalled.value)
        XCTAssertEqual(model.uploadStatus, .completed)
      }
    }
  }
}
