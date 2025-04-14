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
import Sharing
import PlayolaPlayer

@MainActor
@Observable
class RecordingViewModel: ViewModel {
  var completionHandler: ((AudioBlock) -> Void)?
  var stationId: String

  init(stationId: String, completionHandler: ((AudioBlock?) -> Void)? = nil) {
    self.stationId = stationId
    self.completionHandler = completionHandler
    super.init()
  }

  @ObservationIgnored @Dependency(\.audioRecorder) private var audioRecorder
  @ObservationIgnored @Dependency(\.continuousClock) private var clock
  @ObservationIgnored @Dependency(\.genericApiClient) private var apiClient
  @ObservationIgnored @Shared(.auth) private var auth

  private var meterUpdateTimerTask: Task<Never, Error>?

  enum RecordButtonImage: String {
    case record = "record.circle"
    case stop = "stop.circle.fill"
  }

  enum StatusViews: Equatable {
    case idle(String)
    case counting(Int)
    case recording
    case processing(String)
    case completed
    case error(String)

    static func == (lhs: StatusViews, rhs: StatusViews) -> Bool {
      switch (lhs, rhs) {
      case (.idle(let lhsMessage), .idle(let rhsMessage)):
        return lhsMessage == rhsMessage
      case (.counting(let lhsCount), .counting(let rhsCount)):
        return lhsCount == rhsCount
      case (.recording, .recording):
        return true
      case (.processing(let lhsMsg), .processing(let rhsMsg)):
        return lhsMsg == rhsMsg
      case (.error(let lhsMessage), .error(let rhsMessage)):
        return lhsMessage == rhsMessage
      case (.completed, .completed):
        return true
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
    activeStatusView = .processing("Processing Audio")
    do {
      let localVoicetrack = try await audioRecorder.stopRecording()
      activeStatusView = .processing("Getting Upload Permission")
      let uploadInfo = try await apiClient.getVoicetrackPresignedUrl(self.stationId, auth)
      try await uploadVoicetrack(localVoicetrack, uploadInfo: uploadInfo)
    } catch (let error) {
      activeStatusView = .error(error.localizedDescription)
      recordButtonEnabled = true
      showCancelButton = true
    }
  }

  private func uploadVoicetrack(_ localVoicetrack: LocalVoicetrack, uploadInfo: PresignedUrlUploadInfo) async throws {
    self.activeStatusView = .processing("Uploading Voicetrack...")
    try await apiClient.uploadFileToPresignedUrl(
        uploadInfo.presignedUrl,
        localVoicetrack.fileURL
    ) { progress in
        // Update status with upload progress
        Task { @MainActor in
            self.activeStatusView = .processing("Uploading Voicetrack: \(Int(progress * 100))%")
        }
    }
    // After successful upload, create the voicetrack
    await createVoicetrack(localVoicetrack, s3Key: uploadInfo.s3Key)
  }

  private func createVoicetrack(_ localVoicetrack: LocalVoicetrack, s3Key: String) async {
    do {
        let audioBlock = try await apiClient.createVoicetrack(
            self.stationId,
            s3Key,
            localVoicetrack.durationMS,
            auth
        )
        self.activeStatusView = .completed
        completionHandler?(audioBlock)
    } catch (let error) {
        self.activeStatusView = .error(error.localizedDescription)
        self.recordButtonEnabled = true
        self.showCancelButton = true
    }
  }

  // MARK: - Properties
  var recordingURL: URL?
  var recordingInfo: RecordingInfo?

  // Metering
  var averagePower: Float = -160
  var peakPower: Float = -160
  var duration: TimeInterval = 0

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
