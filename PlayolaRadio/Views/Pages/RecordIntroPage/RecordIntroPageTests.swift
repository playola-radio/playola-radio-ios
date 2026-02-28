//
//  RecordIntroPageTests.swift
//  PlayolaRadio
//

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

  // MARK: - Initial Properties

  func testInitialProperties() {
    let model = RecordIntroPageModel(
      songTitle: "Bohemian Rhapsody",
      songArtist: "Queen",
      songImageUrl: URL(string: "https://example.com/image.jpg")
    )

    XCTAssertEqual(model.songTitle, "Bohemian Rhapsody")
    XCTAssertEqual(model.songArtist, "Queen")
    XCTAssertEqual(model.songImageUrl, URL(string: "https://example.com/image.jpg"))
    XCTAssertEqual(model.navigationTitle, "Record Intro")
    XCTAssertEqual(model.instructionItems.count, 2)
    XCTAssertEqual(model.recordingPhase, .idle)
  }

  // MARK: - Lifecycle

  func testViewAppearedPreparesForRecording() async {
    var prepareCalled = false

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {
        prepareCalled = true
      }
    } operation: {
      let model = RecordIntroPageModel(
        songTitle: "Test", songArtist: "Artist", songImageUrl: nil)

      await model.viewAppeared()

      XCTAssertTrue(prepareCalled)
    }
  }

  // MARK: - Done Button

  func testShouldShowDoneButtonTrueOnlyInIdlePhase() {
    let model = RecordIntroPageModel(
      songTitle: "Test", songArtist: "Artist", songImageUrl: nil)

    model.recordingPhase = .idle
    XCTAssertTrue(model.shouldShowDoneButton)

    model.recordingPhase = .recording
    XCTAssertFalse(model.shouldShowDoneButton)

    model.recordingPhase = .review
    XCTAssertFalse(model.shouldShowDoneButton)
  }

  func testOnDoneTappedDismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let model = RecordIntroPageModel(
      songTitle: "Test", songArtist: "Artist", songImageUrl: nil)
    coordinator.presentedSheet = .recordIntroPage(model)

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
      let model = RecordIntroPageModel(
        songTitle: "Test", songArtist: "Artist", songImageUrl: nil)
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
      let model = RecordIntroPageModel(
        songTitle: "Test", songArtist: "Artist", songImageUrl: nil)

      await model.onRecordTapped()

      XCTAssertFalse(startRecordingCalled, "Recording should not start when permission is denied")
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
      let model = RecordIntroPageModel(
        songTitle: "Test", songArtist: "Artist", songImageUrl: nil)
      model.recordingPhase = .recording

      await model.onStopTapped()

      XCTAssertEqual(model.recordingPhase, .review)
      XCTAssertEqual(model.recordingURL, expectedURL)
      XCTAssertEqual(model.recordingDuration, 5.0)
    }
  }

  // MARK: - Re-record

  func testOnReRecordTappedResetsToIdleState() {
    let model = RecordIntroPageModel(
      songTitle: "Test", songArtist: "Artist", songImageUrl: nil)
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

  func testOnDiscardTappedShowsConfirmationAlert() {
    let model = RecordIntroPageModel(
      songTitle: "Test", songArtist: "Artist", songImageUrl: nil)
    model.recordingPhase = .review

    XCTAssertNil(model.presentedAlert)

    model.onDiscardTapped()

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Discard Recording?")
  }

  func testConfirmDiscardDismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let model = RecordIntroPageModel(
      songTitle: "Test", songArtist: "Artist", songImageUrl: nil)
    coordinator.presentedSheet = .recordIntroPage(model)

    model.confirmDiscard()

    XCTAssertNil(coordinator.presentedSheet)
  }

  // MARK: - Accept Recording

  func testOnAcceptRecordingTappedCallsCallbackAndDismisses() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    let expectedURL = URL(fileURLWithPath: "/tmp/test.wav")
    var receivedURL: URL?

    let model = RecordIntroPageModel(
      songTitle: "Test", songArtist: "Artist", songImageUrl: nil)
    model.recordingURL = expectedURL
    model.onRecordingAccepted = { url in
      receivedURL = url
    }
    coordinator.presentedSheet = .recordIntroPage(model)

    model.onAcceptRecordingTapped()

    XCTAssertNil(coordinator.presentedSheet)

    await Task.yield()

    XCTAssertEqual(receivedURL, expectedURL)
  }

  func testOnAcceptRecordingTappedDoesNothingWithoutURL() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    var callbackCalled = false

    let model = RecordIntroPageModel(
      songTitle: "Test", songArtist: "Artist", songImageUrl: nil)
    model.recordingURL = nil
    model.onRecordingAccepted = { _ in
      callbackCalled = true
    }
    coordinator.presentedSheet = .recordIntroPage(model)

    model.onAcceptRecordingTapped()

    await Task.yield()

    XCTAssertFalse(callbackCalled)
    XCTAssertNotNil(coordinator.presentedSheet)
  }
}
