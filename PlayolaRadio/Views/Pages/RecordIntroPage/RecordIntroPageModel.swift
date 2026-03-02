//
//  RecordIntroPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Sharing
import SwiftUI

@MainActor
@Observable
class RecordIntroPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder
  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer
  @ObservationIgnored @Dependency(\.introUploadService) var introUploadService

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Initialization

  let songTitle: String
  let songArtist: String
  let songImageUrl: URL?
  let stationId: String
  let audioBlockId: String?

  init(
    songTitle: String,
    songArtist: String,
    songImageUrl: URL?,
    stationId: String,
    audioBlockId: String?
  ) {
    self.songTitle = songTitle
    self.songArtist = songArtist
    self.songImageUrl = songImageUrl
    self.stationId = stationId
    self.audioBlockId = audioBlockId
    super.init()
  }

  // MARK: - Properties

  let navigationTitle = "Record Intro"

  let instructionItems = [
    "Please use a good external microphone for this.",
    "If you mess up, just keep recording! We'll edit it — you can lean on us!",
  ]

  var recordingPhase: RecordingPhase = .idle
  var recordingDuration: TimeInterval = 0
  var playbackPosition: TimeInterval = 0
  var isPlaying: Bool = false
  var presentedAlert: PlayolaAlert?
  var recordingURL: URL?
  var waveformSamples: [Float] = []
  var uploadStatus: IntroUploadStatus?
  private var recordingTask: Task<Void, Never>?
  private var playbackTask: Task<Void, Never>?

  // MARK: - Callbacks

  var onUploadCompleted: (() -> Void)?

  // MARK: - View Helpers

  var displayTime: String {
    formatTime(recordingDuration)
  }

  var playbackProgress: Double {
    guard recordingDuration > 0 else { return 0 }
    return playbackPosition / recordingDuration
  }

  var shouldShowDoneButton: Bool {
    recordingPhase == .idle && !isUploading
  }

  var isUploading: Bool {
    guard let uploadStatus else { return false }
    switch uploadStatus {
    case .completed, .failed: return false
    default: return true
    }
  }

  var shouldShowUploadStatus: Bool {
    uploadStatus != nil
  }

  var uploadStatusLabel: String {
    switch uploadStatus {
    case .converting: return "Converting..."
    case .uploading: return "Uploading..."
    case .registering: return "Registering..."
    case .completed: return "Upload Complete!"
    case .failed: return "Upload Failed"
    case .none: return ""
    }
  }

  var uploadProgress: Double? {
    if case .uploading(let progress) = uploadStatus {
      return progress
    }
    return nil
  }

  var shouldShowRetryButton: Bool {
    if case .failed = uploadStatus { return true }
    return false
  }

  let retryButtonLabel = "Retry"

  let idleWaveformPlaceholder = "Your recording will appear here"
  let tapToRecordLabel = "Tap to Record"
  let tapToStopLabel = "Tap to Stop"
  let tryAgainLabel = "Try Again"
  let recordingStatusLabel = "Recording"
  let discardButtonLabel = "Discard"
  let useRecordingButtonLabel = "Use Recording"

  // MARK: - User Actions

  func viewAppeared() async {
    do {
      try await audioRecorder.prepareForRecording()
    } catch {
      // Preparation failed - recording will still work but may have latency
    }
  }

  func onRecordTapped() async {
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

  func onStopTapped() async {
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

  func onPlayPauseTapped() {
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

  func onRewindTapped() {
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

  func onReRecordTapped() {
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

  func onDiscardTapped() {
    stopPlaybackUpdates()
    presentedAlert = .discardRecordingConfirmation { [weak self] in
      self?.confirmDiscard()
    }
  }

  func confirmDiscard() {
    Task {
      await audioPlayer.stop()
      if let url = recordingURL {
        await audioRecorder.deleteRecording(url)
      }
    }
    mainContainerNavigationCoordinator.presentedSheet = nil
  }

  func onAcceptRecordingTapped() {
    guard recordingURL != nil else { return }
    stopPlaybackUpdates()
    Task { await audioPlayer.stop() }
    isPlaying = false
    startUpload()
  }

  func onRetryTapped() {
    uploadStatus = nil
    startUpload()
  }

  func onDoneTapped() {
    mainContainerNavigationCoordinator.presentedSheet = nil
  }

  // MARK: - Private Helpers

  private func startUpload() {
    guard let url = recordingURL, let jwt = auth.jwt else { return }
    uploadStatus = .converting
    Task {
      do {
        try await introUploadService.uploadIntro(
          jwt,
          url,
          stationId,
          songTitle,
          audioBlockId
        ) { [weak self] status in
          self?.uploadStatus = status
        }
        uploadStatus = .completed
        onUploadCompleted?()
        try? await Task.sleep(for: .seconds(1))
        mainContainerNavigationCoordinator.presentedSheet = nil
      } catch {
        if case .failed = uploadStatus {
          // Status already set by the callback
        } else {
          uploadStatus = .failed(error.localizedDescription)
        }
      }
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
