//
//  RecordPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import ConcurrencyExtras
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct RecordPageTests {
  // MARK: - Lifecycle

  @Test
  func testViewAppearedPreparesForRecording() async {
    let prepareCalled = LockIsolated(false)

    await withDependencies {
      $0.audioRecorder.prepareForRecording = {
        prepareCalled.setValue(true)
      }
    } operation: {
      let model = RecordPageModel()

      await model.viewAppeared()

      #expect(prepareCalled.value)
    }
  }

  // MARK: - Done Button

  @Test
  func testShouldShowDoneButtonTrueOnlyInIdlePhase() {
    let model = RecordPageModel()

    model.recordingPhase = .idle
    #expect(model.shouldShowDoneButton)

    model.recordingPhase = .recording
    #expect(!model.shouldShowDoneButton)

    model.recordingPhase = .review
    #expect(!model.shouldShowDoneButton)
  }

  @Test
  func testOnDoneTappedDismissesSheet() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = RecordPageModel()
    coordinator.presentedSheet = .recordPage(model)

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
      let model = RecordPageModel()
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
      let model = RecordPageModel()

      await model.onRecordTapped()

      #expect(
        !startRecordingCalled.value, "Recording should not start when permission is denied")
      #expect(model.recordingPhase == .idle)
      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Microphone Access Required")
    }
  }

  @Test
  func testOnRecordTappedShowsAlertOnError() async {
    await withDependencies {
      $0.audioRecorder.requestPermission = { true }
      $0.audioRecorder.startRecording = {
        throw AudioRecorderError.permissionDenied
      }
    } operation: {
      let model = RecordPageModel()

      await model.onRecordTapped()

      #expect(model.recordingPhase == .idle)
      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Recording Error")
    }
  }

  @Test
  func testOnStopTappedStopsRecordingAndChangesPhase() async {
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

      #expect(model.recordingPhase == .review)
      #expect(model.recordingURL == expectedURL)
      #expect(model.recordingDuration == 5.0)
    }
  }

  @Test
  func testOnStopTappedShowsAlertOnError() async {
    await withDependencies {
      $0.audioRecorder.currentTime = { 0 }
      $0.audioRecorder.stopRecording = {
        throw AudioRecorderError.noActiveRecording
      }
    } operation: {
      let model = RecordPageModel()
      model.recordingPhase = .recording

      await model.onStopTapped()

      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Recording Error")
    }
  }

  // MARK: - Re-record

  @Test
  func testOnReRecordTappedResetsToIdleState() async {
    let model = RecordPageModel()
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
    let model = RecordPageModel()
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

    let model = RecordPageModel()
    coordinator.presentedSheet = .recordPage(model)

    await model.confirmDiscard()

    #expect(coordinator.presentedSheet == nil)
  }

  // MARK: - Accept Recording

  @Test
  func testOnAcceptRecordingTappedCallsCallbackAndDismisses() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let expectedURL = URL(fileURLWithPath: "/tmp/test.wav")
    let receivedURL = LockIsolated<URL?>(nil)

    let model = RecordPageModel()
    model.recordingURL = expectedURL
    model.onRecordingAccepted = { url in
      receivedURL.setValue(url)
    }
    coordinator.presentedSheet = .recordPage(model)

    await model.onAcceptRecordingTapped()

    #expect(coordinator.presentedSheet == nil)
    #expect(receivedURL.value == expectedURL)
  }

  @Test
  func testOnAcceptRecordingTappedDoesNothingWithoutURL() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let callbackCalled = LockIsolated(false)

    let model = RecordPageModel()
    model.recordingURL = nil
    model.onRecordingAccepted = { _ in
      callbackCalled.setValue(true)
    }
    coordinator.presentedSheet = .recordPage(model)

    await model.onAcceptRecordingTapped()

    #expect(!callbackCalled.value)
    #expect(coordinator.presentedSheet != nil)
  }

  // MARK: - Playback

  @Test
  func testOnPlayPauseTappedPlaysWhenNotPlaying() async {
    let playCalled = LockIsolated(false)

    await withDependencies {
      $0.audioPlayer.play = { playCalled.setValue(true) }
      $0.audioPlayer.currentTime = { 0 }
      $0.audioPlayer.isPlaying = { true }
    } operation: {
      let model = RecordPageModel()
      model.isPlaying = false

      await model.onPlayPauseTapped()

      #expect(playCalled.value)
      #expect(model.isPlaying)
    }
  }

  @Test
  func testOnPlayPauseTappedPausesWhenPlaying() async {
    let pauseCalled = LockIsolated(false)

    await withDependencies {
      $0.audioPlayer.pause = { pauseCalled.setValue(true) }
    } operation: {
      let model = RecordPageModel()
      model.isPlaying = true

      await model.onPlayPauseTapped()

      #expect(pauseCalled.value)
      #expect(!model.isPlaying)
    }
  }

  @Test
  func testOnRewindTappedSeeksToZero() async {
    let seekTime = LockIsolated<TimeInterval?>(nil)

    await withDependencies {
      $0.audioPlayer.seek = { time in seekTime.setValue(time) }
    } operation: {
      let model = RecordPageModel()
      model.playbackPosition = 30.0

      await model.onRewindTapped()

      #expect(seekTime.value == 0)
      #expect(model.playbackPosition == 0)
    }
  }

  @Test
  func testSeekToUpdatesPlaybackPosition() async {
    let seekTime = LockIsolated<TimeInterval?>(nil)

    await withDependencies {
      $0.audioPlayer.seek = { time in seekTime.setValue(time) }
    } operation: {
      let model = RecordPageModel()
      model.recordingDuration = 60.0

      await model.seekTo(30.0)

      #expect(seekTime.value == 30.0)
      #expect(model.playbackPosition == 30.0)
    }
  }
}
