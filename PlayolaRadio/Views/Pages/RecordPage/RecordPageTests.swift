//
//  RecordPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

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
    var prepareCalled = false

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {
        prepareCalled = true
      }
    } operation: {
      let model = RecordPageModel()

      await model.viewAppeared()

      XCTAssertTrue(prepareCalled)
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
    var requestPermissionCalled = false
    var startRecordingCalled = false

    await withDependencies {
      $0.audioRecorder.requestPermission = {
        requestPermissionCalled = true
        return true
      }
      $0.audioRecorder.startRecording = {
        XCTAssertTrue(
          requestPermissionCalled, "Permission should be requested before recording starts")
        startRecordingCalled = true
      }
    } operation: {
      let model = RecordPageModel()
      XCTAssertEqual(model.recordingPhase, .idle)

      await model.onRecordTapped()

      XCTAssertTrue(requestPermissionCalled)
      XCTAssertTrue(startRecordingCalled)
      XCTAssertEqual(model.recordingPhase, .recording)
    }
  }

  func testOnRecordTappedDoesNotRecordWhenPermissionDenied() async {
    var startRecordingCalled = false

    await withDependencies {
      $0.audioRecorder.requestPermission = { false }
      $0.audioRecorder.startRecording = {
        startRecordingCalled = true
      }
    } operation: {
      let model = RecordPageModel()

      await model.onRecordTapped()

      XCTAssertFalse(startRecordingCalled, "Recording should not start when permission is denied")
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

  func testOnReRecordTapped_ResetsToIdleState() {
    let model = RecordPageModel()
    model.recordingPhase = .review
    model.recordingURL = URL(fileURLWithPath: "/tmp/test.wav")
    model.recordingDuration = 10.0
    model.playbackPosition = 5.0
    model.isPlaying = true

    model.onReRecordTapped()

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

  func testConfirmDiscard_DismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let model = RecordPageModel()
    coordinator.presentedSheet = .recordPage(model)

    model.confirmDiscard()

    XCTAssertNil(coordinator.presentedSheet)
  }

  // MARK: - Accept Recording

  func testOnAcceptRecordingTapped_CallsCallbackAndDismisses() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let expectedURL = URL(fileURLWithPath: "/tmp/test.wav")
    let callbackExpectation = XCTestExpectation(description: "onRecordingAccepted called")
    var receivedURL: URL?

    let model = RecordPageModel()
    model.recordingURL = expectedURL
    model.onRecordingAccepted = { url in
      receivedURL = url
      callbackExpectation.fulfill()
    }
    coordinator.presentedSheet = .recordPage(model)

    model.onAcceptRecordingTapped()

    // Sheet dismisses immediately
    XCTAssertNil(coordinator.presentedSheet)

    await fulfillment(of: [callbackExpectation], timeout: 1.0)
    XCTAssertEqual(receivedURL, expectedURL)
  }

  func testOnAcceptRecordingTapped_DoesNothingWithoutURL() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    var callbackCalled = false

    let model = RecordPageModel()
    model.recordingURL = nil
    model.onRecordingAccepted = { _ in
      callbackCalled = true
    }
    coordinator.presentedSheet = .recordPage(model)

    model.onAcceptRecordingTapped()

    // Allow any spawned Task to complete
    await Task.yield()

    XCTAssertFalse(callbackCalled)
    XCTAssertNotNil(coordinator.presentedSheet)
  }

  // MARK: - Playback

  func testOnPlayPauseTapped_PlaysWhenNotPlaying() async {
    var playCalled = false

    await withDependencies {
      $0.audioPlayer.play = { playCalled = true }
      $0.audioPlayer.currentTime = { 0 }
      $0.audioPlayer.isPlaying = { true }
    } operation: {
      let model = RecordPageModel()
      model.isPlaying = false

      model.onPlayPauseTapped()
      // Allow Task to execute
      try? await Task.sleep(for: .milliseconds(10))

      XCTAssertTrue(playCalled)
      XCTAssertTrue(model.isPlaying)
    }
  }

  func testOnPlayPauseTapped_PausesWhenPlaying() async {
    var pauseCalled = false

    await withDependencies {
      $0.audioPlayer.pause = { pauseCalled = true }
    } operation: {
      let model = RecordPageModel()
      model.isPlaying = true

      model.onPlayPauseTapped()
      // Allow Task to execute
      try? await Task.sleep(for: .milliseconds(10))

      XCTAssertTrue(pauseCalled)
      XCTAssertFalse(model.isPlaying)
    }
  }

  func testOnRewindTapped_SeeksToZero() async {
    var seekTime: TimeInterval?

    await withDependencies {
      $0.audioPlayer.seek = { time in seekTime = time }
    } operation: {
      let model = RecordPageModel()
      model.playbackPosition = 30.0

      model.onRewindTapped()
      // Allow Task to execute
      try? await Task.sleep(for: .milliseconds(10))

      XCTAssertEqual(seekTime, 0)
      XCTAssertEqual(model.playbackPosition, 0)
    }
  }

  func testSeekTo_UpdatesPlaybackPosition() async {
    var seekTime: TimeInterval?

    await withDependencies {
      $0.audioPlayer.seek = { time in seekTime = time }
    } operation: {
      let model = RecordPageModel()
      model.recordingDuration = 60.0

      model.seekTo(30.0)
      // Allow Task to execute
      try? await Task.sleep(for: .milliseconds(10))

      XCTAssertEqual(seekTime, 30.0)
      XCTAssertEqual(model.playbackPosition, 30.0)
    }
  }
}
