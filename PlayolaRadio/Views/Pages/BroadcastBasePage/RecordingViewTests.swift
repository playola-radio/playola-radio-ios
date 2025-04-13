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
                          stopRecording: { recordingURL },
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
  }
}

//@Suite("Recording Tests")
//struct RecordingTests {
//
//    @Test("Successfully record and stop recording")
//    func recordingFlow() async throws {
//        let recordingURL = URL(fileURLWithPath: "/test/recording.m4a")
//        let mockInfo = RecordingInfo(averagePower: -20, peakPower: -10, duration: 1.5)
//
//        withDependencies {
//            $0.audioRecorder = AudioRecorder(
//                startRecording: { recordingURL },
//                stopRecording: { recordingURL },
//                pauseRecording: { },
//                resumeRecording: { },
//                currentRecordingInfo: { mockInfo },
//                isRecording: { true }
//            )
//        } operation: {
//            let model = RecordingViewModel()
//
//            // Test initial state
//            #expect(model.state == .idle)
//            #expect(model.recordingURL == nil)
//
//            // Start recording
//            var completedURL: URL?
//            model.startRecording { url in
//                completedURL = url
//            }
//
//            // Should transition through counting state
//            if case .counting(let count) = model.state {
//                #expect(count == 3)
//            } else {
//                throw ExpectedFailure("Expected counting state")
//            }
//
//            // Wait for countdown
//            try await Task.sleep(for: .seconds(3.5))
//
//            // Should be recording
//            #expect(model.state == .recording)
//            #expect(model.averagePower == mockInfo.averagePower)
//            #expect(model.peakPower == mockInfo.peakPower)
//            #expect(model.duration == mockInfo.duration)
//
//            // Stop recording
//            await model.stopRecording()
//
//            // Verify completion
//            #expect(model.state == .idle)
//            #expect(completedURL == recordingURL)
//        }
//    }
//
//    @Test("Handle recording permission denied")
//    func recordingFailure() async throws {
//        try await withDependencies {
//            $0.audioRecorder = AudioRecorder(
//                startRecording: { throw AudioRecorderError.permissionDenied },
//                stopRecording: { throw AudioRecorderError.notRecording },
//                pauseRecording: { },
//                resumeRecording: { },
//                currentRecordingInfo: { RecordingInfo(averagePower: 0, peakPower: 0, duration: 0) },
//                isRecording: { false }
//            )
//        } operation: {
//            let model = RecordingViewModel()
//
//            var completedURL: URL?
//            model.startRecording { url in
//                completedURL = url
//            }
//
//            try await Task.sleep(for: .seconds(3.5))
//
//            if case .error(let error) = model.state {
//                #expect((error as? AudioRecorderError) == AudioRecorderError.permissionDenied)
//            } else {
//                throw ExpectedFailure("Expected error state")
//            }
//
//            #expect(completedURL == nil)
//        }
//    }
//
//    @Test("Cleanup stops timers and resets state")
//    func cleanup() async throws {
//        try await withDependencies {
//            $0.audioRecorder = AudioRecorder(
//                startRecording: { URL(fileURLWithPath: "/test/recording.m4a") },
//                stopRecording: { URL(fileURLWithPath: "/test/recording.m4a") },
//                pauseRecording: { },
//                resumeRecording: { },
//                currentRecordingInfo: { RecordingInfo(averagePower: 0, peakPower: 0, duration: 0) },
//                isRecording: { false }
//            )
//        } operation: {
//            let model = RecordingViewModel()
//
//            model.startRecording { _ in }
//
//            if case .counting = model.state {
//                model.cleanup()
//
//                #expect(model.state == .idle)
//                #expect(model.recordingURL == nil)
//                #expect(model.averagePower == -160)
//                #expect(model.peakPower == -160)
//                #expect(model.duration == 0)
//            } else {
//                throw ExpectedFailure("Expected counting state")
//            }
//        }
//    }
//
//    @Test("Audio levels update during recording")
//    func audioLevels() async throws {
//        let mockInfo = RecordingInfo(averagePower: -30, peakPower: -20, duration: 2.0)
//
//        try await withDependencies {
//            $0.audioRecorder = AudioRecorder(
//                startRecording: { URL(fileURLWithPath: "/test/recording.m4a") },
//                stopRecording: { URL(fileURLWithPath: "/test/recording.m4a") },
//                pauseRecording: { },
//                resumeRecording: { },
//                currentRecordingInfo: { mockInfo },
//                isRecording: { true }
//            )
//        } operation: {
//            let model = RecordingViewModel()
//
//            model.startRecording { _ in }
//            try await Task.sleep(for: .seconds(3.5))
//
//            #expect(model.averagePower == mockInfo.averagePower)
//            #expect(model.peakPower == mockInfo.peakPower)
//            #expect(model.duration == mockInfo.duration)
//        }
//    }
//
//    @Test("Cancel recording prevents completion")
//    func cancelRecording() async throws {
//        try await withDependencies {
//            $0.audioRecorder = AudioRecorder(
//                startRecording: { URL(fileURLWithPath: "/test/recording.m4a") },
//                stopRecording: { URL(fileURLWithPath: "/test/recording.m4a") },
//                pauseRecording: { },
//                resumeRecording: { },
//                currentRecordingInfo: { RecordingInfo(averagePower: 0, peakPower: 0, duration: 0) },
//                isRecording: { true }
//            )
//        } operation: {
//            let model = RecordingViewModel()
//
//            var completionCalled = false
//            model.startRecording { _ in
//                completionCalled = true
//            }
//
//            model.cleanup()
//
//            #expect(model.state == .idle)
//            #expect(completionCalled == false)
//        }
//    }
//}
//
//struct ExpectedFailure: Error {
//    let message: String
//
//    init(_ message: String) {
//        self.message = message
//    }
//}
