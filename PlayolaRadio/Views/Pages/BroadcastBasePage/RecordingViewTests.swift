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


enum RecordingViewTests {
  @MainActor @Suite("Starts And Stops Recorder")
  struct StartsAndStopsRecorder {
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
        let model = RecordingViewModel()

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
        RecordingViewModel()
      }
      model.recordButtonTapped()
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
        RecordingViewModel()
      }
      model.recordButtonTapped()
      await clock.advance(by: .seconds(5))
      #expect(model.activeStatusView == .recording)
      #expect(model.recordButtonEnabled == true)
      #expect(model.recordButtonImage == RecordingViewModel.RecordButtonImage.stop)
      #expect(model.showCancelButton == false)
      #expect(model.recordingURL == expectedUrl)
    }

    @MainActor
    @Test("Stop button tapped")
    func testStopButtonTapped() async throws {
      let recordingURL = URL(fileURLWithPath: "/test/recording.m4a")
      var completionCalled = false
      let expectedVoicetrack = LocalVoicetrack(fileURL: recordingURL, durationMS: 1000)

      let model = withDependencies {
        $0.audioRecorder = AudioRecorder(
          startRecording: { recordingURL },
          stopRecording: { expectedVoicetrack },
          pauseRecording: { },
          resumeRecording: { },
          currentRecordingInfo: { RecordingInfo(averagePower: -20, peakPower: -10, duration: 1.5) },
          isRecording: { true }
        )
      } operation: {
        RecordingViewModel { voicetrack in
          completionCalled = true
          #expect(voicetrack == expectedVoicetrack)
        }
      }

      // Set initial recording state
      model.activeStatusView = .recording
      model.recordButtonImage = .stop

      // Stop recording
      await model.stopButtonTapped()

      // Verify state changes
      #expect(completionCalled == true)
      #expect(model.activeStatusView == .processing)
    }

    @MainActor
    @Test("Handles error during stop recording")
    func testHandlesErrorDuringStopRecording() async throws {
      let expectedError = NSError(domain: "RecordingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording failed"])
      var completionCalled = false

      let model = withDependencies {
        $0.audioRecorder = AudioRecorder(
          startRecording: { URL(fileURLWithPath: "test") },
          stopRecording: { throw expectedError },
          pauseRecording: { },
          resumeRecording: { },
          currentRecordingInfo: { RecordingInfo(averagePower: -20, peakPower: -10, duration: 1.5) },
          isRecording: { true }
        )
      } operation: {
        RecordingViewModel { _ in
          completionCalled = true
        }
      }

      // Set initial recording state
      model.activeStatusView = .recording
      model.recordButtonImage = .stop
      model.showCancelButton = false

      // Stop recording
      await model.stopButtonTapped()

      // Verify error state
      #expect(completionCalled == false)
      #expect(model.activeStatusView == .error(expectedError.localizedDescription))
      #expect(model.recordButtonEnabled == true)
      #expect(model.showCancelButton == true)
    }
  }
}
