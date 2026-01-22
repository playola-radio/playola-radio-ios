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

@MainActor
@Observable
class AskQuestionPageModel: ViewModel {
  // MARK: - State

  let station: Station

  var recordingPhase: AskQuestionRecordingPhase = .idle
  var recordingDuration: TimeInterval = 0
  var playbackPosition: TimeInterval = 0
  var isPlaying: Bool = false
  var presentedAlert: PlayolaAlert?
  var recordingURL: URL?
  var waveformSamples: [Float] = []
  private var recordingTask: Task<Void, Never>?
  private var playbackTask: Task<Void, Never>?

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder
  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

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

  // MARK: - Init

  init(station: Station) {
    self.station = station
    super.init()
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
    mainContainerNavigationCoordinator.pop()
  }

  func submitTapped() async {
    // TODO: Upload question to server
    print("Submit question for station: \(station.curatorName)")
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
