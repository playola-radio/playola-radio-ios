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

  // MARK: - Done Button

  func testOnDoneTapped_DismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let model = RecordPageModel()
    coordinator.presentedSheet = .recordPage(model)

    XCTAssertNotNil(coordinator.presentedSheet)

    model.onDoneTapped()

    XCTAssertNil(coordinator.presentedSheet)
  }

  // MARK: - Recording

  func testOnRecordTapped_StartsRecordingAndChangesPhase() async {
    var startRecordingCalled = false

    await withDependencies {
      $0.audioRecorder.startRecording = {
        startRecordingCalled = true
      }
    } operation: {
      let model = RecordPageModel()
      XCTAssertEqual(model.recordingPhase, .idle)

      await model.onRecordTapped()

      XCTAssertTrue(startRecordingCalled)
      XCTAssertEqual(model.recordingPhase, .recording)
    }
  }

  func testOnRecordTapped_ShowsAlertOnError() async {
    await withDependencies {
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

  func testOnDiscardTapped_DismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let model = RecordPageModel()
    coordinator.presentedSheet = .recordPage(model)

    model.onDiscardTapped()

    XCTAssertNil(coordinator.presentedSheet)
  }

  // MARK: - Accept Recording

  func testOnAcceptRecordingTapped_CallsCallbackAndDismisses() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let expectedURL = URL(fileURLWithPath: "/tmp/test.wav")
    var receivedURL: URL?

    let model = RecordPageModel()
    model.recordingURL = expectedURL
    model.onRecordingAccepted = { url in
      receivedURL = url
    }
    coordinator.presentedSheet = .recordPage(model)

    model.onAcceptRecordingTapped()

    XCTAssertEqual(receivedURL, expectedURL)
    XCTAssertNil(coordinator.presentedSheet)
  }

  func testOnAcceptRecordingTapped_DoesNothingWithoutURL() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    var callbackCalled = false

    let model = RecordPageModel()
    model.recordingURL = nil
    model.onRecordingAccepted = { _ in
      callbackCalled = true
    }
    coordinator.presentedSheet = .recordPage(model)

    model.onAcceptRecordingTapped()

    XCTAssertFalse(callbackCalled)
    XCTAssertNotNil(coordinator.presentedSheet)
  }
}
