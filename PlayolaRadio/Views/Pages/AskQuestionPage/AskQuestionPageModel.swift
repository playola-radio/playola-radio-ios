//
//  AskQuestionPageModel.swift
//  PlayolaRadio
//

import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI

enum AskQuestionRecordingPhase: Equatable {
  case idle
  case recording
  case review
}

enum AskQuestionUploadPhase: Equatable {
  case notStarted
  case converting
  case uploading(progress: Double)
  case normalizing
  case finalizing
  case completed
  case failed(error: String)
}

@MainActor
@Observable
class AskQuestionPageModel: ViewModel {
  // MARK: - State

  let station: Station

  var recordingPhase: AskQuestionRecordingPhase = .idle
  var uploadPhase: AskQuestionUploadPhase = .notStarted
  var recordingDuration: TimeInterval = 0
  var playbackPosition: TimeInterval = 0
  var isPlaying: Bool = false
  var presentedAlert: PlayolaAlert?
  var recordingURL: URL?
  var waveformSamples: [Float] = []
  private var recordingTask: Task<Void, Never>?
  private var playbackTask: Task<Void, Never>?
  private var stationToResume: AnyStation?

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder
  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer
  @ObservationIgnored @Dependency(\.audioConverter) var audioConverter
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  @ObservationIgnored var stationPlayer: StationPlayer

  // MARK: - Computed Properties

  var curatorName: String {
    station.curatorName
  }

  var displayTime: String {
    formatTime(recordingDuration)
  }

  var playbackProgress: Double {
    guard recordingDuration > 0 else { return 0 }
    return playbackPosition / recordingDuration
  }

  var isUploading: Bool {
    switch uploadPhase {
    case .notStarted, .completed, .failed:
      return false
    case .converting, .uploading, .normalizing, .finalizing:
      return true
    }
  }

  var uploadStatusText: String {
    switch uploadPhase {
    case .notStarted:
      return ""
    case .converting:
      return "Converting audio..."
    case .uploading(let progress):
      return "Uploading \(Int(progress * 100))%"
    case .normalizing:
      return "Processing..."
    case .finalizing:
      return "Finalizing..."
    case .completed:
      return "Complete!"
    case .failed(let error):
      return "Failed: \(error)"
    }
  }

  // MARK: - Init

  init(station: Station, stationPlayer: StationPlayer? = nil) {
    self.station = station
    self.stationPlayer = stationPlayer ?? .shared
    super.init()
  }

  // MARK: - Lifecycle

  func viewAppeared() async {
    pauseStationIfPlaying()
    do {
      try await audioRecorder.prepareForRecording()
    } catch {
      // Preparation failed - recording will still work but may have latency
    }
  }

  // MARK: - Recording Actions

  func recordTapped() async {
    let hasPermission = await audioRecorder.requestPermission()
    guard hasPermission else {
      presentedAlert = .microphonePermissionDeniedAlert
      return
    }

    do {
      waveformSamples = []
      try await audioRecorder.startRecording()
      recordingPhase = .recording
      startRecordingUpdates()
    } catch {
      presentedAlert = .recordingFailedAlert(error.localizedDescription)
    }
  }

  func stopTapped() async {
    stopRecordingUpdates()
    do {
      let url = try await audioRecorder.stopRecording()
      recordingURL = url
      try await audioPlayer.loadFile(url)
      recordingDuration = await audioPlayer.duration()
      recordingPhase = .review
    } catch {
      presentedAlert = .recordingFailedAlert(error.localizedDescription)
    }
  }

  private func startRecordingUpdates() {
    recordingTask = Task {
      while !Task.isCancelled {
        recordingDuration = await audioRecorder.currentTime()
        let level = await audioRecorder.getAudioLevel()
        waveformSamples.append(level)
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  private func stopRecordingUpdates() {
    recordingTask?.cancel()
    recordingTask = nil
  }

  // MARK: - Playback Actions

  func playPauseTapped() {
    Task {
      if isPlaying {
        await audioPlayer.pause()
        stopPlaybackUpdates()
        isPlaying = false
      } else {
        await audioPlayer.play()
        startPlaybackUpdates()
        isPlaying = true
      }
    }
  }

  func rewindTapped() {
    Task {
      await audioPlayer.seek(0)
      playbackPosition = 0
    }
  }

  func seekTo(_ time: TimeInterval) {
    Task {
      await audioPlayer.seek(time)
      playbackPosition = time
    }
  }

  private func startPlaybackUpdates() {
    playbackTask = Task {
      while !Task.isCancelled {
        playbackPosition = await audioPlayer.currentTime()
        let playing = await audioPlayer.isPlaying()
        if !playing {
          isPlaying = false
          stopPlaybackUpdates()
          break
        }
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  private func stopPlaybackUpdates() {
    playbackTask?.cancel()
    playbackTask = nil
  }

  // MARK: - Review Actions

  func reRecordTapped() {
    stopPlaybackUpdates()
    Task {
      await audioPlayer.stop()
      if let url = recordingURL {
        await audioRecorder.deleteRecording(url)
      }
    }
    recordingURL = nil
    recordingDuration = 0
    playbackPosition = 0
    isPlaying = false
    waveformSamples = []
    recordingPhase = .idle
  }

  func cancelTapped() {
    if recordingPhase == .review {
      presentedAlert = .discardRecordingConfirmation { [weak self] in
        self?.confirmCancel()
      }
    } else {
      confirmCancel()
    }
  }

  func confirmCancel() {
    stopPlaybackUpdates()
    Task {
      await audioPlayer.stop()
      if let url = recordingURL {
        await audioRecorder.deleteRecording(url)
      }
    }
    resumeStationIfNeeded()
    mainContainerNavigationCoordinator.pop()
  }

  func submitTapped() async {
    guard let url = recordingURL, let jwt = auth.jwt else { return }

    stopPlaybackUpdates()
    await audioPlayer.stop()

    do {
      // Step 1: Convert to m4a
      uploadPhase = .converting
      let m4aURL = try await audioConverter.convertToM4A(url)
      let durationMS = try await audioConverter.getDuration(m4aURL)

      // Step 2: Get presigned URL for listener question
      uploadPhase = .uploading(progress: 0)
      let presignedResponse = try await api.getListenerQuestionPresignedURL(jwt, station.id)

      // Step 3: Upload to S3
      try await api.uploadToS3(
        presignedResponse.presignedUrl,
        m4aURL,
        "audio/mp4"
      ) { [weak self] progress in
        Task { @MainActor in
          self?.uploadPhase = .uploading(progress: progress)
        }
      }

      // Step 4: Wait for normalization
      uploadPhase = .normalizing
      try await waitForNormalization(jwt: jwt, s3Key: presignedResponse.s3Key)

      // Step 5: Create voicetrack AudioBlock
      uploadPhase = .finalizing
      let audioBlock = try await api.createVoicetrack(
        jwt, station.id, presignedResponse.s3Key, durationMS)

      // Step 6: Create listener question with the audioBlock
      _ = try await api.createListenerQuestion(jwt, station.id, audioBlock.id)

      // Step 7: Cleanup temp files
      try? FileManager.default.removeItem(at: m4aURL)

      // Step 8: Show success and dismiss
      uploadPhase = .completed
      presentedAlert = .questionSentSuccess(curatorName: station.curatorName) { [weak self] in
        self?.resumeStationIfNeeded()
        self?.mainContainerNavigationCoordinator.popToRoot()
      }

    } catch {
      print("DEBUG AskQuestionPage error: \(error)")
      uploadPhase = .failed(error: error.localizedDescription)
    }
  }

  private func waitForNormalization(jwt: String, s3Key: String) async throws {
    let maxWaitTimeSeconds = 120
    let pollIntervalSeconds: UInt64 = 2
    let startTime = Date()

    while Date().timeIntervalSince(startTime) < Double(maxWaitTimeSeconds) {
      let status = try await api.getVoicetrackStatus(jwt, station.id, s3Key)
      if status.ready {
        return
      }
      try await Task.sleep(nanoseconds: pollIntervalSeconds * 1_000_000_000)
    }

    throw AskQuestionError.normalizationTimeout
  }

  // MARK: - Helpers

  private func pauseStationIfPlaying() {
    if case .playing(let station) = stationPlayer.state.playbackStatus {
      stationToResume = station
      stationPlayer.stop()
    }
  }

  private func resumeStationIfNeeded() {
    if let station = stationToResume {
      stationPlayer.play(station: station)
      stationToResume = nil
    }
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
  }
}

// MARK: - Errors

enum AskQuestionError: LocalizedError {
  case normalizationTimeout

  var errorDescription: String? {
    switch self {
    case .normalizationTimeout:
      return "Audio processing timed out. Please try again."
    }
  }
}

// MARK: - Alerts

extension PlayolaAlert {
  static func questionSentSuccess(
    curatorName: String,
    onDismiss: @escaping () -> Void
  ) -> PlayolaAlert {
    PlayolaAlert(
      title: "Question Sent!",
      message:
        "If \(curatorName) answers it, your question and their response will air on the station, "
        + "and we'll let you know when it plays.",
      dismissButton: .default(Text("OK"), action: onDismiss)
    )
  }
}
