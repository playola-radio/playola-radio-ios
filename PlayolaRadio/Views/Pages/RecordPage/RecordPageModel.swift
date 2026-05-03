//
//  RecordPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import Dependencies
import Sharing
import SwiftUI

enum RecordingPhase: Equatable {
  case idle
  case recording
  case review
}

@MainActor
@Observable
class RecordPageModel: ViewModel {
  // MARK: - State

  var recordingPhase: RecordingPhase = .idle
  var recordingDuration: TimeInterval = 0
  var playbackPosition: TimeInterval = 0
  var isPlaying: Bool = false
  var presentedAlert: PlayolaAlert?
  var recordingURL: URL?
  var waveformSamples: [Float] = []
  private var recordingTask: Task<Void, Never>?
  private var playbackTask: Task<Void, Never>?

  // MARK: - Callbacks

  var onRecordingAccepted: ((URL) async -> Void)?

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder
  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Computed Properties

  var displayTime: String {
    formatTime(recordingDuration)
  }

  var playbackProgress: Double {
    guard recordingDuration > 0 else { return 0 }
    return playbackPosition / recordingDuration
  }

  var shouldShowDoneButton: Bool {
    recordingPhase == .idle
  }

  // MARK: - Lifecycle

  func viewAppeared() async {
    do {
      try await audioRecorder.prepareForRecording()
    } catch {
      // Preparation failed - recording will still work but may have latency
    }
  }

  // MARK: - Recording Actions

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

  func onPlayPauseTapped() async {
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

  func onRewindTapped() async {
    await audioPlayer.seek(0)
    playbackPosition = 0
  }

  func seekTo(_ time: TimeInterval) async {
    await audioPlayer.seek(time)
    playbackPosition = time
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

  func onReRecordTapped() async {
    stopPlaybackUpdates()
    await audioPlayer.stop()
    if let url = recordingURL {
      await audioRecorder.deleteRecording(url)
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
      Task { await self?.confirmDiscard() }
    }
  }

  func confirmDiscard() async {
    await audioPlayer.stop()
    if let url = recordingURL {
      await audioRecorder.deleteRecording(url)
    }
    mainContainerNavigationCoordinator.presentedSheet = nil
  }

  func onAcceptRecordingTapped() async {
    guard let url = recordingURL else { return }
    mainContainerNavigationCoordinator.presentedSheet = nil
    await onRecordingAccepted?(url)
  }

  func onDoneTapped() {
    mainContainerNavigationCoordinator.presentedSheet = nil
  }

  // MARK: - Helpers

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

extension PlayolaAlert {
  static func recordingFailedAlert(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Recording Error",
      message: message,
      dismissButton: .cancel(Text("OK")))
  }

  static func discardRecordingConfirmation(_ onConfirm: @escaping () -> Void) -> PlayolaAlert {
    PlayolaAlert(
      title: "Discard Recording?",
      message: "This recording will be permanently deleted.",
      primaryButtonText: "Discard",
      primaryAction: { onConfirm() },
      secondaryButtonText: "Cancel")
  }

  static var microphonePermissionDeniedAlert: PlayolaAlert {
    PlayolaAlert(
      title: "Microphone Access Required",
      message: "Please enable microphone access in Settings to record voice tracks.",
      dismissButton: .cancel(Text("OK")),
      secondaryButton: .default(
        Text("Settings"),
        action: {
          if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
          }
        }))
  }
}
