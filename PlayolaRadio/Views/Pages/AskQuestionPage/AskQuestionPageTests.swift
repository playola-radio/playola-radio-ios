//
//  AskQuestionPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
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

  @Test
  func testInstructionsTextInvitesAnyMessage() {
    let model = AskQuestionPageModel(station: .mock)

    expectNoDifference(
      model.instructionsText,
      "Start with your name and where you’re listening from, then say or ask "
        + "whatever you want: a question, a shout-out, a story. "
        + "If they choose yours, your message and their response will air on the station."
    )
  }

  @Test
  func viewAppearedTracksViewedScreen() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {}
      $0.analytics.track = { event in capturedEvents.withValue { $0.append(event) } }
    } operation: {
      let model = AskQuestionPageModel(station: .mockWith(id: "station-123"))

      await model.viewAppeared()
    }

    expectNoDifference(
      capturedEvents.value, [.viewedScreen(screen: .askArtist, stationId: "station-123")])
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
      $0.audioRecorder.requestPermission = { true }
      $0.audioRecorder.startRecording = {}
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      await model.recordTapped()

      await model.stopTapped()

      #expect(model.recordingPhase == .review)
      #expect(model.recordingURL == expectedURL)
      #expect(model.recordingDuration == 5.0)
    }
  }

  @Test
  func testRecordTappedWithBuiltInMicAsksToFlipInsteadOfRecording() async {
    let startRecordingCalled = LockIsolated(false)

    await withMainSerialExecutor {
      await withDependencies {
        $0.audioRecorder.requestPermission = { true }
        $0.audioRecorder.usesExternalMicrophone = { false }
        $0.audioRecorder.startRecording = { startRecordingCalled.setValue(true) }
        $0.devicePose.updates = { AsyncStream { $0.yield(.upright) } }
      } operation: {
        let model = AskQuestionPageModel(station: .mock)

        await model.recordTapped()
        await Task.megaYield()

        expectNoDifference(model.flipToRecord.phase, .prompting)
        #expect(!startRecordingCalled.value)
        #expect(model.recordingPhase == .idle)
      }
    }
  }

  @Test
  func testSecondStopDoesNotStopTheRecorderAgain() async {
    let stopCount = LockIsolated(0)

    await withDependencies {
      $0.audioRecorder.requestPermission = { true }
      $0.audioRecorder.startRecording = {}
      $0.audioRecorder.currentTime = { 1 }
      $0.audioRecorder.stopRecording = {
        stopCount.withValue { $0 += 1 }
        return URL(fileURLWithPath: "/tmp/test-recording.wav")
      }
      $0.audioPlayer.loadFile = { _ in }
      $0.audioPlayer.duration = { 1 }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      await model.recordTapped()

      await model.stopTapped()
      await model.stopTapped()

      #expect(stopCount.value == 1)
      #expect(model.presentedAlert == nil)
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

  @Test
  func testReRecordTappedIsIgnoredWhileUploading() async {
    let deletedURLs = LockIsolated<[URL]>([])
    let url = URL(fileURLWithPath: "/tmp/test.wav")

    await withDependencies {
      $0.audioRecorder.deleteRecording = { url in deletedURLs.withValue { $0.append(url) } }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      model.recordingPhase = .review
      model.recordingURL = url
      model.recordingDuration = 10.0
      model.uploadPhase = .uploading(progress: 0.5)

      await model.reRecordTapped()

      expectNoDifference(model.recordingPhase, .review)
      expectNoDifference(model.recordingURL, url)
      expectNoDifference(model.recordingDuration, 10.0)
      #expect(deletedURLs.value.isEmpty)
    }
  }

  @Test
  func testReRecordButtonIsDisabledOnlyWhileUploading() {
    let model = AskQuestionPageModel(station: .mock)
    model.recordingPhase = .review

    model.uploadPhase = .notStarted
    expectNoDifference(model.isReRecordButtonDisabled, false)

    model.uploadPhase = .uploading(progress: 0.5)
    expectNoDifference(model.isReRecordButtonDisabled, true)

    model.uploadPhase = .failed(error: "boom")
    expectNoDifference(model.isReRecordButtonDisabled, false)
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

  @Test
  func testConfirmCancelWhileRecordingStopsAndDiscardsTheRecording() async {
    let partialURL = URL(fileURLWithPath: "/tmp/partial.wav")
    let stopCount = LockIsolated(0)
    let deletedURLs = LockIsolated<[URL]>([])
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    await withDependencies {
      $0.audioRecorder.requestPermission = { true }
      $0.audioRecorder.startRecording = {}
      $0.audioRecorder.currentTime = { 1 }
      $0.audioRecorder.stopRecording = {
        stopCount.withValue { $0 += 1 }
        return partialURL
      }
      $0.audioRecorder.deleteRecording = { url in deletedURLs.withValue { $0.append(url) } }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      coordinator.path = [.askQuestionPage(model)]
      await model.recordTapped()
      expectNoDifference(model.recordingPhase, .recording)

      await model.confirmCancel()

      expectNoDifference(stopCount.value, 1)
      expectNoDifference(deletedURLs.value, [partialURL])
      expectNoDifference(model.recordingPhase, .idle)
      #expect(coordinator.path.isEmpty)
    }
  }

  @Test
  func testConfirmCancelWhileStartingRecordingStopsAndDiscardsTheRecording() async {
    let partialURL = URL(fileURLWithPath: "/tmp/partial.wav")
    let stopCount = LockIsolated(0)
    let deletedURLs = LockIsolated<[URL]>([])
    let (startGate, releaseStart) = AsyncStream<Void>.makeStream()
    let (startStarted, signalStart) = AsyncStream<Void>.makeStream()
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    await withDependencies {
      $0.audioRecorder.requestPermission = { true }
      $0.audioRecorder.usesExternalMicrophone = { true }
      $0.audioRecorder.startRecording = {
        signalStart.yield()
        for await _ in startGate { break }
      }
      $0.audioRecorder.stopRecording = {
        stopCount.withValue { $0 += 1 }
        return partialURL
      }
      $0.audioRecorder.deleteRecording = { url in deletedURLs.withValue { $0.append(url) } }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      coordinator.path = [.askQuestionPage(model)]
      let starting = Task { await model.recordTapped() }
      for await _ in startStarted { break }

      await model.confirmCancel()
      releaseStart.yield()
      await starting.value

      expectNoDifference(stopCount.value, 1)
      expectNoDifference(deletedURLs.value, [partialURL])
      expectNoDifference(model.recordingPhase, .idle)
      #expect(coordinator.path.isEmpty)
    }
  }

  @Test
  func testViewDisappearedWhileRecordingStopsAndDiscardsTheRecording() async {
    let partialURL = URL(fileURLWithPath: "/tmp/partial.wav")
    let stopCount = LockIsolated(0)
    let deletedURLs = LockIsolated<[URL]>([])

    await withDependencies {
      $0.audioRecorder.requestPermission = { true }
      $0.audioRecorder.startRecording = {}
      $0.audioRecorder.currentTime = { 1 }
      $0.audioRecorder.stopRecording = {
        stopCount.withValue { $0 += 1 }
        return partialURL
      }
      $0.audioRecorder.deleteRecording = { url in deletedURLs.withValue { $0.append(url) } }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      await model.recordTapped()
      expectNoDifference(model.recordingPhase, .recording)

      await model.viewDisappeared()

      expectNoDifference(stopCount.value, 1)
      expectNoDifference(deletedURLs.value, [partialURL])
      expectNoDifference(model.recordingPhase, .idle)
    }
  }

  @Test
  func testViewDisappearedInReviewKeepsTheRecording() async {
    let stopCount = LockIsolated(0)
    let deletedURLs = LockIsolated<[URL]>([])

    await withDependencies {
      $0.audioRecorder.stopRecording = {
        stopCount.withValue { $0 += 1 }
        return URL(fileURLWithPath: "/tmp/unused.wav")
      }
      $0.audioRecorder.deleteRecording = { url in deletedURLs.withValue { $0.append(url) } }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      model.recordingPhase = .review
      model.recordingURL = URL(fileURLWithPath: "/tmp/test.wav")

      await model.viewDisappeared()

      expectNoDifference(stopCount.value, 0)
      #expect(deletedURLs.value.isEmpty)
      expectNoDifference(model.recordingPhase, .review)
    }
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

  // MARK: - Error Reporting

  private func makeSubmittableModel(
    reports: LockIsolated<[String]>? = nil,
    reportCount: LockIsolated<Int>? = nil,
    convertError: Error
  ) -> AskQuestionPageModel {
    let model = withDependencies {
      $0.audioPlayer.stop = {}
      $0.audioConverter.convertToM4A = { _ in throw convertError }
      $0.errorReporting.reportError = { _, tags in
        reports?.withValue { $0.append(tags["operation"] ?? "") }
        reportCount?.withValue { $0 += 1 }
      }
    } operation: {
      AskQuestionPageModel(station: .mock)
    }
    model.recordingURL = URL(fileURLWithPath: "/tmp/test.wav")
    return model
  }

  @Test
  func testSubmitTappedReportsFailureWithOperationTag() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let reports = LockIsolated<[String]>([])
    let model = makeSubmittableModel(reports: reports, convertError: APIError.dataNotValid)

    await model.submitTapped()

    expectNoDifference(reports.value, ["submitAskQuestion"])
    expectNoDifference(
      model.uploadPhase, .failed(error: APIError.dataNotValid.localizedDescription))
  }

  @Test
  func testSubmitTappedDoesNotReportConnectivityFailure() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let reportCount = LockIsolated(0)
    let model = makeSubmittableModel(
      reportCount: reportCount, convertError: URLError(.notConnectedToInternet))

    await model.submitTapped()

    expectNoDifference(reportCount.value, 0)
    expectNoDifference(
      model.uploadPhase,
      .failed(error: URLError(.notConnectedToInternet).localizedDescription))
  }

  @Test
  func testSubmitTappedDoesNotReportCancellation() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let reportCount = LockIsolated(0)
    let model = makeSubmittableModel(reportCount: reportCount, convertError: CancellationError())

    await model.submitTapped()

    expectNoDifference(reportCount.value, 0)
  }

  @Test
  func testStopTappedReportsRecordingFailureWithOperationTag() async {
    let reports = LockIsolated<[String]>([])

    await withDependencies {
      $0.audioRecorder.requestPermission = { true }
      $0.audioRecorder.startRecording = {}
      $0.audioRecorder.currentTime = { 0 }
      $0.audioRecorder.stopRecording = { throw APIError.dataNotValid }
      $0.errorReporting.reportError = { _, tags in
        reports.withValue { $0.append(tags["operation"] ?? "") }
      }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)
      await model.recordTapped()

      await model.stopTapped()

      expectNoDifference(reports.value, ["stopAskQuestionRecording"])
      #expect(model.presentedAlert != nil)
    }
  }

  @Test
  func testRecordTappedReportsStartRecordingFailureWithOperationTag() async {
    let reports = LockIsolated<[String]>([])

    await withDependencies {
      $0.audioRecorder.requestPermission = { true }
      $0.audioRecorder.startRecording = { throw APIError.dataNotValid }
      $0.errorReporting.reportError = { _, tags in
        reports.withValue { $0.append(tags["operation"] ?? "") }
      }
    } operation: {
      let model = AskQuestionPageModel(station: .mock)

      await model.recordTapped()

      expectNoDifference(reports.value, ["startAskQuestionRecording"])
      #expect(model.presentedAlert != nil)
    }
  }

  // MARK: - Alerts

  @Test
  func testQuestionSentSuccessAlertDoesNotPromiseANotification() {
    let alert = PlayolaAlert.questionSentSuccess(curatorName: "Bri Bagwell") {}

    expectNoDifference(
      alert.message,
      "If Bri Bagwell replies, your message and their reply will air on the station."
    )
  }
}
