//
//  RecordPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import ConcurrencyExtras
import Dependencies
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class RecordPageTests: XCTestCase {
  override func setUp() {
    super.setUp()
    @Shared(.mainContainerNavigationCoordinator) var coordinator
    coordinator.presentedSheet = nil
  }

  // MARK: - Lifecycle

  func testViewAppeared_PreparesForRecording() async {
    let prepareCalled = LockIsolated(false)

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {
        prepareCalled.setValue(true)
      }
    } operation: {
      let model = RecordPageModel()

      await model.viewAppeared()

      XCTAssertTrue(prepareCalled.value)
    }
  }

  // MARK: - Done Button

  func testShouldShowDoneButton_TrueOnlyInIdlePhase() {
    let model = RecordPageModel()

    model.recordingPhase = .idle
    XCTAssertTrue(model.shouldShowDoneButton)

    model.recordingPhase = .recording
    XCTAssertFalse(model.shouldShowDoneButton)

    model.recordingPhase = .review
    XCTAssertFalse(model.shouldShowDoneButton)
  }

  func testOnDoneTapped_DismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let model = RecordPageModel()
    coordinator.presentedSheet = .recordPage(model)

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
      let model = RecordPageModel()
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
      let model = RecordPageModel()

      await model.onRecordTapped()

      XCTAssertFalse(
        startRecordingCalled.value, "Recording should not start when permission is denied")
      XCTAssertEqual(model.recordingPhase, .idle)
      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Microphone Access Required")
    }
  }

  func testOnRecordTapped_ShowsAlertOnError() async {
    await withDependencies {
      $0.audioRecorder.requestPermission = { true }
      $0.audioRecorder.startRecording = {
        throw AudioRecorderError.permissionDenied
      }
    } operation: {
      let model = RecordPageModel()

      await model.onRecordTapped()

      XCTAssertEqual(model.recordingPhase, .idle)
      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Recording Error")
    }
  }

  func testOnStopTapped_StopsRecordingAndChangesPhase() async {
    let expectedURL = URL(fileURLWithPath: "/tmp/test-recording.wav")

    await withDependencies {
      $0.audioRecorder.currentTime = { 5.0 }
      $0.audioRecorder.stopRecording = { expectedURL }
      $0.audioPlayer.loadFile = { _ in }
      $0.audioPlayer.duration = { 5.0 }
    } operation: {
      let model = RecordPageModel()
      model.recordingPhase = .recording

      await model.onStopTapped()

      XCTAssertEqual(model.recordingPhase, .review)
      XCTAssertEqual(model.recordingURL, expectedURL)
      XCTAssertEqual(model.recordingDuration, 5.0)
    }
  }

  func testOnStopTapped_ShowsAlertOnError() async {
    await withDependencies {
      $0.audioRecorder.currentTime = { 0 }
      $0.audioRecorder.stopRecording = {
        throw AudioRecorderError.noActiveRecording
      }
    } operation: {
      let model = RecordPageModel()
      model.recordingPhase = .recording

      await model.onStopTapped()

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Recording Error")
    }
  }

  // MARK: - Re-record

  func testOnReRecordTapped_ResetsToIdleState() async {
    let model = RecordPageModel()
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

  func testOnDiscardTapped_ShowsConfirmationAlert() {
    let model = RecordPageModel()
    model.recordingPhase = .review

    XCTAssertNil(model.presentedAlert)

    model.onDiscardTapped()

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Discard Recording?")
  }

  func testConfirmDiscard_DismissesSheet() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let model = RecordPageModel()
    coordinator.presentedSheet = .recordPage(model)

    await model.confirmDiscard()

    XCTAssertNil(coordinator.presentedSheet)
  }

  // MARK: - Accept Recording

  func testOnAcceptRecordingTapped_CallsCallbackAndDismisses() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let expectedURL = URL(fileURLWithPath: "/tmp/test.wav")
    let receivedURL = LockIsolated<URL?>(nil)

    let model = RecordPageModel()
    model.recordingURL = expectedURL
    model.onRecordingAccepted = { url in
      receivedURL.setValue(url)
    }
    coordinator.presentedSheet = .recordPage(model)

    await model.onAcceptRecordingTapped()

    XCTAssertNil(coordinator.presentedSheet)
    XCTAssertEqual(receivedURL.value, expectedURL)
  }

  func testOnAcceptRecordingTapped_DoesNothingWithoutURL() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let callbackCalled = LockIsolated(false)

    let model = RecordPageModel()
    model.recordingURL = nil
    model.onRecordingAccepted = { _ in
      callbackCalled.setValue(true)
    }
    coordinator.presentedSheet = .recordPage(model)

    await model.onAcceptRecordingTapped()

    XCTAssertFalse(callbackCalled.value)
    XCTAssertNotNil(coordinator.presentedSheet)
  }

  // MARK: - Playback

  func testOnPlayPauseTapped_PlaysWhenNotPlaying() async {
    let playCalled = LockIsolated(false)

    await withDependencies {
      $0.audioPlayer.play = { playCalled.setValue(true) }
      $0.audioPlayer.currentTime = { 0 }
      $0.audioPlayer.isPlaying = { true }
    } operation: {
      let model = RecordPageModel()
      model.isPlaying = false

      await model.onPlayPauseTapped()

      XCTAssertTrue(playCalled.value)
      XCTAssertTrue(model.isPlaying)
    }
  }

  func testOnPlayPauseTapped_PausesWhenPlaying() async {
    let pauseCalled = LockIsolated(false)

    await withDependencies {
      $0.audioPlayer.pause = { pauseCalled.setValue(true) }
    } operation: {
      let model = RecordPageModel()
      model.isPlaying = true

      await model.onPlayPauseTapped()

      XCTAssertTrue(pauseCalled.value)
      XCTAssertFalse(model.isPlaying)
    }
  }

  func testOnRewindTapped_SeeksToZero() async {
    let seekTime = LockIsolated<TimeInterval?>(nil)

    await withDependencies {
      $0.audioPlayer.seek = { time in seekTime.setValue(time) }
    } operation: {
      let model = RecordPageModel()
      model.playbackPosition = 30.0

      await model.onRewindTapped()

      XCTAssertEqual(seekTime.value, 0)
      XCTAssertEqual(model.playbackPosition, 0)
    }
  }

  func testSeekTo_UpdatesPlaybackPosition() async {
    let seekTime = LockIsolated<TimeInterval?>(nil)

    await withDependencies {
      $0.audioPlayer.seek = { time in seekTime.setValue(time) }
    } operation: {
      let model = RecordPageModel()
      model.recordingDuration = 60.0

      await model.seekTo(30.0)

      XCTAssertEqual(seekTime.value, 30.0)
      XCTAssertEqual(model.playbackPosition, 30.0)
    }
  }
}
