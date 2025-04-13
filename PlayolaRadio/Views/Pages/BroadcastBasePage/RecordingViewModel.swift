//
//  RecordingViewModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/11/25.
//
import SwiftUI
import Foundation
import AVFoundation
import Dependencies

@MainActor
@Observable
class RecordingViewModel: ViewModel {
  var completionHandler: ((LocalVoicetrack) -> Void)?

  init(completionHandler: ((LocalVoicetrack) -> Void)?) {
    self.completionHandler = completionHandler
    super.init()
  }

  @ObservationIgnored @Dependency(\.audioRecorder) private var audioRecorder
  @ObservationIgnored @Dependency(\.continuousClock) private var clock

  private var meterUpdateTimerTask: Task<Never, Error>?

  enum RecordButtonImage: String {
    case record = "record.circle"
    case stop = "stop.circle.fill"
  }

  enum StatusViews: Equatable {
    case idle(String)
    case counting(Int)
    case recording
    case processing
    case error(String)

    static func == (lhs: StatusViews, rhs: StatusViews) -> Bool {
      switch (lhs, rhs) {
      case (.idle(let lhsMessage), .idle(let rhsMessage)):
        return lhsMessage == rhsMessage
      case (.counting(let lhsCount), .counting(let rhsCount)):
        return lhsCount == rhsCount
      case (.recording, .recording):
        return true
      case (.processing, .processing):
        return true
      case (.error(let lhsMessage), .error(let rhsMessage)):
        return lhsMessage == rhsMessage
      default:
        return false
      }
    }
  }

  var activeStatusView: StatusViews = .idle("Ready to record")
  var showCancelButton: Bool = true
  var recordButtonImage: RecordButtonImage = .record
  var recordButtonColor: Color = .red
  var recordButtonEnabled: Bool = true

  func cancelButtonTapped() {}

  func recordButtonTapped() {
    // if audio is running
    if recordButtonImage == .record {
      countdownAndStartRecording()
    } else {
      Task { await stopButtonTapped() }
    }
  }

  func stopButtonTapped() async {
    stopMeterUpdates()
    activeStatusView = .processing
    do {
      let voicetrack = try await audioRecorder.stopRecording()
      completionHandler?(voicetrack)
    } catch (let error) {
      activeStatusView = .error(error.localizedDescription)
      recordButtonEnabled = true
      showCancelButton = true
    }
  }


  // MARK: - Properties
  var recordingURL: URL?
  var recordingInfo: RecordingInfo?

  // Metering
  var averagePower: Float = -160
  var peakPower: Float = -160
  var duration: TimeInterval = 0

  private var countdownValue = 3

  override init() {
    super.init()
  }

  // MARK: - Public Methods

//  func stopRecording() {
//    guard case .recording = state else { return }
//    state = .processing
//
//    Task {
//      do {
//        stopMeterUpdates()
//        let url = try await audioRecorder.stopRecording()
//        recordingURL = url
//
//        // Create LocalVoicetrack
//        let voicetrack = LocalVoicetrack(
//          fileURL: url,
//          durationMS: Int(duration * 1000) // Convert seconds to milliseconds
//        )
//
//        completionHandler?(voicetrack)
//        state = .idle
//      } catch {
//        state = .error(error)
//      }
//    }
//  }

  // MARK: - Private Methods

  private func countdownAndStartRecording() {
    var count = 3
    self.activeStatusView = .counting(count)

    Task {
      while count > 0 {
        count -= 1
        try? await clock.sleep(for: .seconds(1))
        self.activeStatusView = .counting(count)
      }
      await beginRecording()
    }
  }

  private func beginRecording() async {
      do {
        self.activeStatusView = .recording
        self.recordButtonImage = .stop
        self.showCancelButton = false
        recordingURL = try await audioRecorder.startRecording()
        startMeterUpdates()
      } catch (let error) {
        self.activeStatusView = .error(error.localizedDescription)
      }
  }

  private func startMeterUpdates() {
    self.meterUpdateTimerTask = Task {
      while true {
        try await clock.sleep(for: .milliseconds(100))
        await self.updateMeter()
      }
    }
  }

  private func updateMeter() async {
    let info = await self.audioRecorder.currentRecordingInfo()
    self.averagePower = info.averagePower
    self.peakPower = info.peakPower
    self.duration = info.duration
    self.recordingInfo = info
  }

  private func stopMeterUpdates() {
    self.meterUpdateTimerTask?.cancel()
    self.meterUpdateTimerTask = nil
  }

  // MARK: - Cleanup

  func cleanup() {
    stopMeterUpdates()
  }

  deinit {
    Task{ @MainActor [weak self] in
      self?.cleanup()
    }
  }
}
