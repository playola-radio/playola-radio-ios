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

  // MARK: - Callbacks

  var onRecordingAccepted: ((URL) -> Void)?

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

  // MARK: - Lifecycle

  func viewAppeared() async {
    // TODO: Request microphone permission
  }

  // MARK: - Recording Actions

  func onRecordTapped() async {
    do {
      try await audioRecorder.startRecording()
      recordingPhase = .recording
    } catch {
      presentedAlert = .recordingFailedAlert(error.localizedDescription)
    }
  }

  func onStopTapped() async {
    do {
      recordingDuration = await audioRecorder.currentTime()
      let url = try await audioRecorder.stopRecording()
      recordingURL = url
      try await audioPlayer.loadFile(url)
      recordingDuration = await audioPlayer.duration()
      recordingPhase = .review
    } catch {
      presentedAlert = .recordingFailedAlert(error.localizedDescription)
    }
  }

  // MARK: - Playback Actions

  func onPlayPauseTapped() {
    Task {
      if isPlaying {
        await audioPlayer.pause()
        isPlaying = false
      } else {
        await audioPlayer.play()
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

  // MARK: - Review Actions

  func onReRecordTapped() {
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
    recordingPhase = .idle
  }

  func onDiscardTapped() {
    Task {
      await audioPlayer.stop()
      if let url = recordingURL {
        await audioRecorder.deleteRecording(url)
      }
    }
    mainContainerNavigationCoordinator.presentedSheet = nil
  }

  func onAcceptRecordingTapped() {
    guard let url = recordingURL else { return }
    onRecordingAccepted?(url)
    mainContainerNavigationCoordinator.presentedSheet = nil
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
    return String(format: "%02d:%02d:%02d", hours, minutes, secs)
  }
}

extension PlayolaAlert {
  static func recordingFailedAlert(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Recording Error",
      message: message,
      dismissButton: .cancel(Text("OK")))
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
