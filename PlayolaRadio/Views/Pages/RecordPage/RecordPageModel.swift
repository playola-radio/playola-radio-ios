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
    // TODO: Start recording
    recordingPhase = .recording
  }

  func onStopTapped() async {
    // TODO: Stop recording, get URL
    recordingPhase = .review
  }

  // MARK: - Playback Actions

  func onPlayPauseTapped() {
    isPlaying.toggle()
    // TODO: Play/pause audio
  }

  func onRewindTapped() {
    playbackPosition = 0
    // TODO: Seek to beginning
  }

  // MARK: - Review Actions

  func onReRecordTapped() {
    // TODO: Delete current recording
    recordingURL = nil
    recordingDuration = 0
    playbackPosition = 0
    isPlaying = false
    recordingPhase = .idle
  }

  func onDiscardTapped() {
    // TODO: Show confirmation alert, then dismiss
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
