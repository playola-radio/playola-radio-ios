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

  // MARK: - Shared State

  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Initialization

  let songTitle: String
  let songArtist: String
  let songImageUrl: URL?

  init(songTitle: String, songArtist: String, songImageUrl: URL?) {
    self.songTitle = songTitle
    self.songArtist = songArtist
    self.songImageUrl = songImageUrl
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
  private var recordingTask: Task<Void, Never>?
  private var playbackTask: Task<Void, Never>?

  // MARK: - Callbacks

  var onRecordingAccepted: ((URL) async -> Void)?

  // MARK: - View Helpers

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
    guard let url = recordingURL else { return }
    mainContainerNavigationCoordinator.presentedSheet = nil
    Task {
      await onRecordingAccepted?(url)
    }
  }

  func onDoneTapped() {
    mainContainerNavigationCoordinator.presentedSheet = nil
  }

  // MARK: - Private Helpers

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
