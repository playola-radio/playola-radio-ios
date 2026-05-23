//
//  AskQuestionPageTests.swift
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
struct AskQuestionPageTests {
  // MARK: - Init

  @Test
  func testInitStoresStation() {
    let station = Station.mockWith(id: "station-123", curatorName: "Test Curator")

    let model = AskQuestionPageModel(station: station)

    #expect(model.station.id == "station-123")
    #expect(model.station.curatorName == "Test Curator")
  }

  @Test
  func testCuratorNameReturnsCuratorName() {
    let station = Station.mockWith(curatorName: "Bri Bagwell")

    let model = AskQuestionPageModel(station: station)

    #expect(model.curatorName == "Bri Bagwell")
  }

  // MARK: - Recording

  @Test
  func testRecordTappedRequestsPermissionBeforeRecording() async {
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
      let model = AskQuestionPageModel(station: .mock)
      #expect(model.recordingPhase == .idle)

      await model.recordTapped()

      #expect(requestPermissionCalled.value)
      #expect(startRecordingCalled.value)
      #expect(model.recordingPhase == .recording)
    }
  }

  @Test
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

      #expect(!startRecordingCalled.value)
      #expect(model.recordingPhase == .idle)
      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Microphone Access Required")
    }
  }

  @Test
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

      #expect(model.recordingPhase == .review)
      #expect(model.recordingURL == expectedURL)
      #expect(model.recordingDuration == 5.0)
    }
  }

  // MARK: - Re-record

  @Test
  func testReRecordTappedResetsToIdleState() async {
    let model = AskQuestionPageModel(station: .mock)
    model.recordingPhase = .review
    model.recordingURL = URL(fileURLWithPath: "/tmp/test.wav")
    model.recordingDuration = 10.0
    model.playbackPosition = 5.0
    model.isPlaying = true

    await model.reRecordTapped()

    #expect(model.recordingPhase == .idle)
    #expect(model.recordingURL == nil)
    #expect(model.recordingDuration == 0)
    #expect(model.playbackPosition == 0)
    #expect(!model.isPlaying)
  }

  // MARK: - Cancel

  @Test
  func testCancelTappedShowsConfirmationWhenInReview() async {
    let model = AskQuestionPageModel(station: .mock)
    model.recordingPhase = .review

    #expect(model.presentedAlert == nil)

    await model.cancelTapped()

    #expect(model.presentedAlert != nil)
    #expect(model.presentedAlert?.title == "Discard Recording?")
  }

  @Test
  func testCancelTappedPopsNavigationWhenIdle() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = AskQuestionPageModel(station: .mock)
    coordinator.path = [.askQuestionPage(model)]
    model.recordingPhase = .idle

    await model.cancelTapped()

    #expect(coordinator.path.isEmpty)
  }

  @Test
  func testConfirmCancelPopsNavigation() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = AskQuestionPageModel(station: .mock)
    coordinator.path = [.askQuestionPage(model)]

    await model.confirmCancel()

    #expect(coordinator.path.isEmpty)
  }

  // MARK: - Playback

  @Test
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

      #expect(playCalled.value)
      #expect(model.isPlaying)
    }
  }

  @Test
  func testPlayPauseTappedPausesWhenPlaying() async {
    let pauseCalled = LockIsolated(false)

    await withDependencies {
      $0.audioPlayer.pause = { pauseCalled.setValue(true) }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      model.isPlaying = true

      await model.playPauseTapped()

      #expect(pauseCalled.value)
      #expect(!model.isPlaying)
    }
  }

  @Test
  func testRewindTappedSeeksToZero() async {
    let seekTime = LockIsolated<TimeInterval?>(nil)

    await withDependencies {
      $0.audioPlayer.seek = { time in seekTime.setValue(time) }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      model.playbackPosition = 30.0

      await model.rewindTapped()

      #expect(seekTime.value == 0)
      #expect(model.playbackPosition == 0)
    }
  }

  // MARK: - Display Time

  @Test
  func testDisplayTimeFormatsCorrectly() {
    let model = AskQuestionPageModel(station: .mock)

    model.recordingDuration = 0
    #expect(model.displayTime == "0:00")

    model.recordingDuration = 65
    #expect(model.displayTime == "1:05")

    model.recordingDuration = 3661
    #expect(model.displayTime == "1:01:01")
  }

  // MARK: - Station Pause/Resume on Page Lifecycle

  @Test
  func testViewAppearedPausesStationWhenPlaying() async {
    let playingStation = AnyStation.mock
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .playing(playingStation))

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {}
      $0.stationPlayer = stationPlayerMock
    } operation: {
      let model = AskQuestionPageModel(station: .mock)

      await model.viewAppeared()

      #expect(stationPlayerMock.stopCalledCount == 1)
    }
  }

  @Test
  func testViewAppearedDoesNotPauseStationWhenNotPlaying() async {
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .stopped)

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {}
      $0.stationPlayer = stationPlayerMock
    } operation: {
      let model = AskQuestionPageModel(station: .mock)

      await model.viewAppeared()

      #expect(stationPlayerMock.stopCalledCount == 0)
    }
  }

  @Test
  func testConfirmCancelResumesStationIfWasPaused() async {
    let playingStation = AnyStation.mock
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .playing(playingStation))
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {}
      $0.stationPlayer = stationPlayerMock
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      coordinator.path = [.askQuestionPage(model)]

      await model.viewAppeared()
      stationPlayerMock.callsToPlay = []

      await model.confirmCancel()

      #expect(stationPlayerMock.callsToPlay.count == 1)
      #expect(stationPlayerMock.callsToPlay.first?.id == playingStation.id)
    }
  }

  @Test
  func testConfirmCancelDoesNotResumeStationIfWasNotPaused() async {
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .stopped)
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {}
      $0.stationPlayer = stationPlayerMock
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      coordinator.path = [.askQuestionPage(model)]

      await model.viewAppeared()

      await model.confirmCancel()

      #expect(stationPlayerMock.callsToPlay.count == 0)
    }
  }

  // MARK: - Alerts

  @Test
  func testQuestionSentSuccessAlertIncludesCuratorName() {
    let alert = PlayolaAlert.questionSentSuccess(curatorName: "Bri Bagwell") {}

    #expect(
      alert.message?.contains("Bri Bagwell") ?? false,
      "Alert message should contain the curator name"
    )
  }
}
