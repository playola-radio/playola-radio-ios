//
//  AskQuestionPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class AskQuestionPageTests: XCTestCase {
  override func setUp() {
    super.setUp()
    @Shared(.mainContainerNavigationCoordinator) var coordinator
    coordinator.path = []
  }

  // MARK: - Init

  func testInitStoresStation() {
    let station = Station.mockWith(id: "station-123", curatorName: "Test Curator")

    let model = AskQuestionPageModel(station: station)

    XCTAssertEqual(model.station.id, "station-123")
    XCTAssertEqual(model.station.curatorName, "Test Curator")
  }

  func testCuratorNameReturnsCuratorName() {
    let station = Station.mockWith(curatorName: "Bri Bagwell")

    let model = AskQuestionPageModel(station: station)

    XCTAssertEqual(model.curatorName, "Bri Bagwell")
  }

  // MARK: - Recording

  func testRecordTappedRequestsPermissionBeforeRecording() async {
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
      let model = AskQuestionPageModel(station: .mock)
      XCTAssertEqual(model.recordingPhase, .idle)

      await model.recordTapped()

      XCTAssertTrue(requestPermissionCalled.value)
      XCTAssertTrue(startRecordingCalled.value)
      XCTAssertEqual(model.recordingPhase, .recording)
    }
  }

  func testRecordTappedShowsAlertWhenPermissionDenied() async {
    let startRecordingCalled = LockIsolated(false)

    await withDependencies {
      $0.audioRecorder.requestPermission = { false }
      $0.audioRecorder.startRecording = {
        startRecordingCalled.setValue(true)
      }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)

      await model.recordTapped()

      XCTAssertFalse(startRecordingCalled.value)
      XCTAssertEqual(model.recordingPhase, .idle)
      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Microphone Access Required")
    }
  }

  func testStopTappedTransitionsToReview() async {
    let expectedURL = URL(fileURLWithPath: "/tmp/test-recording.wav")

    await withDependencies {
      $0.audioRecorder.currentTime = { 5.0 }
      $0.audioRecorder.stopRecording = { expectedURL }
      $0.audioPlayer.loadFile = { _ in }
      $0.audioPlayer.duration = { 5.0 }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      model.recordingPhase = .recording

      await model.stopTapped()

      XCTAssertEqual(model.recordingPhase, .review)
      XCTAssertEqual(model.recordingURL, expectedURL)
      XCTAssertEqual(model.recordingDuration, 5.0)
    }
  }

  // MARK: - Re-record

  func testReRecordTappedResetsToIdleState() async {
    let model = AskQuestionPageModel(station: .mock)
    model.recordingPhase = .review
    model.recordingURL = URL(fileURLWithPath: "/tmp/test.wav")
    model.recordingDuration = 10.0
    model.playbackPosition = 5.0
    model.isPlaying = true

    await model.reRecordTapped()

    XCTAssertEqual(model.recordingPhase, .idle)
    XCTAssertNil(model.recordingURL)
    XCTAssertEqual(model.recordingDuration, 0)
    XCTAssertEqual(model.playbackPosition, 0)
    XCTAssertFalse(model.isPlaying)
  }

  // MARK: - Cancel

  func testCancelTappedShowsConfirmationWhenInReview() async {
    let model = AskQuestionPageModel(station: .mock)
    model.recordingPhase = .review

    XCTAssertNil(model.presentedAlert)

    await model.cancelTapped()

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Discard Recording?")
  }

  func testCancelTappedPopsNavigationWhenIdle() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator
    let model = AskQuestionPageModel(station: .mock)
    coordinator.path = [.askQuestionPage(model)]
    model.recordingPhase = .idle

    await model.cancelTapped()

    XCTAssertTrue(coordinator.path.isEmpty)
  }

  func testConfirmCancelPopsNavigation() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator
    let model = AskQuestionPageModel(station: .mock)
    coordinator.path = [.askQuestionPage(model)]

    await model.confirmCancel()

    XCTAssertTrue(coordinator.path.isEmpty)
  }

  // MARK: - Playback

  func testPlayPauseTappedPlaysWhenNotPlaying() async {
    let playCalled = LockIsolated(false)

    await withDependencies {
      $0.audioPlayer.play = { playCalled.setValue(true) }
      $0.audioPlayer.currentTime = { 0 }
      $0.audioPlayer.isPlaying = { true }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      model.isPlaying = false

      await model.playPauseTapped()

      XCTAssertTrue(playCalled.value)
      XCTAssertTrue(model.isPlaying)
    }
  }

  func testPlayPauseTappedPausesWhenPlaying() async {
    let pauseCalled = LockIsolated(false)

    await withDependencies {
      $0.audioPlayer.pause = { pauseCalled.setValue(true) }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      model.isPlaying = true

      await model.playPauseTapped()

      XCTAssertTrue(pauseCalled.value)
      XCTAssertFalse(model.isPlaying)
    }
  }

  func testRewindTappedSeeksToZero() async {
    let seekTime = LockIsolated<TimeInterval?>(nil)

    await withDependencies {
      $0.audioPlayer.seek = { time in seekTime.setValue(time) }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      model.playbackPosition = 30.0

      await model.rewindTapped()

      XCTAssertEqual(seekTime.value, 0)
      XCTAssertEqual(model.playbackPosition, 0)
    }
  }

  // MARK: - Display Time

  func testDisplayTimeFormatsCorrectly() {
    let model = AskQuestionPageModel(station: .mock)

    model.recordingDuration = 0
    XCTAssertEqual(model.displayTime, "0:00")

    model.recordingDuration = 65
    XCTAssertEqual(model.displayTime, "1:05")

    model.recordingDuration = 3661
    XCTAssertEqual(model.displayTime, "1:01:01")
  }

  // MARK: - Station Pause/Resume on Page Lifecycle

  func testViewAppearedPausesStationWhenPlaying() async {
    let playingStation = AnyStation.mock
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .playing(playingStation))

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {}
    } operation: {
      let model = AskQuestionPageModel(station: .mock, stationPlayer: stationPlayerMock)

      await model.viewAppeared()

      XCTAssertEqual(stationPlayerMock.stopCalledCount, 1)
    }
  }

  func testViewAppearedDoesNotPauseStationWhenNotPlaying() async {
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .stopped)

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {}
    } operation: {
      let model = AskQuestionPageModel(station: .mock, stationPlayer: stationPlayerMock)

      await model.viewAppeared()

      XCTAssertEqual(stationPlayerMock.stopCalledCount, 0)
    }
  }

  func testConfirmCancelResumesStationIfWasPaused() async {
    let playingStation = AnyStation.mock
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .playing(playingStation))
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {}
    } operation: {
      let model = AskQuestionPageModel(station: .mock, stationPlayer: stationPlayerMock)
      coordinator.path = [.askQuestionPage(model)]

      await model.viewAppeared()
      stationPlayerMock.callsToPlay = []

      await model.confirmCancel()

      XCTAssertEqual(stationPlayerMock.callsToPlay.count, 1)
      XCTAssertEqual(stationPlayerMock.callsToPlay.first?.id, playingStation.id)
    }
  }

  func testConfirmCancelDoesNotResumeStationIfWasNotPaused() async {
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .stopped)
    @Shared(.mainContainerNavigationCoordinator) var coordinator

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {}
    } operation: {
      let model = AskQuestionPageModel(station: .mock, stationPlayer: stationPlayerMock)
      coordinator.path = [.askQuestionPage(model)]

      await model.viewAppeared()

      await model.confirmCancel()

      XCTAssertEqual(stationPlayerMock.callsToPlay.count, 0)
    }
  }

  // MARK: - Alerts

  func testQuestionSentSuccessAlertIncludesCuratorName() {
    let alert = PlayolaAlert.questionSentSuccess(curatorName: "Bri Bagwell") {}

    XCTAssertTrue(
      alert.message?.contains("Bri Bagwell") ?? false,
      "Alert message should contain the curator name"
    )
  }
}
