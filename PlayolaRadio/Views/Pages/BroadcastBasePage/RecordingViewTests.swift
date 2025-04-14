//
//  RecordingViewTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/11/25.
//

import XCTest
import Dependencies
import AVFoundation
import Testing
@testable import PlayolaRadio
import Sharing


enum RecordingViewTests {
  @MainActor @Suite("Starts And Stops Recorder")
  struct StartsAndStopsRecorder {
    let stationId = UUID().uuidString
    @Shared(.auth) var auth = .mock

    @Test("Initial State")
    func testInitialState() async {
      let recordingURL = URL(fileURLWithPath: "/test/recording.m4a")
      let mockInfo = RecordingInfo(averagePower: -20, peakPower: -10, duration: 1.5)

      withDependencies {
        $0.audioRecorder = AudioRecorder(
          startRecording: { recordingURL },
          stopRecording: { LocalVoicetrack(fileURL: recordingURL,
                                           durationMS: 1000) },
          pauseRecording: { },
          resumeRecording: { },
          currentRecordingInfo: { mockInfo },
          isRecording: { true }
        )
      } operation: {
        let model = RecordingViewModel(stationId: "test-station-id")

        // Test initial state
        #expect(model.activeStatusView == .idle("Ready to record"))
        #expect(model.showCancelButton == true)
        #expect(model.recordButtonImage == .record)
        #expect(model.recordButtonColor == .red)
        #expect(model.recordButtonEnabled == true)
      }
    }

    @MainActor
    @Test("Executes Countdown and Starts Recorder")
    func testExecutesCountdownAndRecords() async throws {
      var recordCount = 0
      let clock = TestClock()
      let model = withDependencies {
        $0.continuousClock = clock
        $0.audioRecorder.startRecording = { @MainActor in
          recordCount += 1
          return URL(fileURLWithPath: "test")
        }
      } operation: {
        RecordingViewModel(stationId: stationId)
      }
      await model.recordButtonTapped()
      await clock.advance(by: .milliseconds(500))
      #expect(model.activeStatusView == .counting(3))
      await clock.advance(by: .seconds(1))
      #expect(model.activeStatusView == .counting(2))
      await clock.advance(by: .seconds(1))
      #expect(model.activeStatusView == .counting(1))
      await clock.advance(by: .seconds(1))
      #expect(model.activeStatusView == .recording)
      #expect(recordCount == 1)
    }

    @MainActor
    @Test("State during Recording")
    func testRecordingState() async throws {
      let clock = TestClock()
      let expectedUrl = URL(fileURLWithPath: "test")
      let model = withDependencies {
        $0.continuousClock = clock
        $0.audioRecorder.startRecording = { expectedUrl }
      } operation: {
        RecordingViewModel(stationId: stationId)
      }
      model.recordButtonTapped()
      await clock.advance(by: .seconds(5))
      #expect(model.activeStatusView == .recording)
      #expect(model.recordButtonEnabled == true)
      #expect(model.recordButtonImage == RecordingViewModel.RecordButtonImage.stop)
      #expect(model.showCancelButton == false)
      #expect(model.recordingURL == expectedUrl)
    }
  }
}
