import Dependencies
import Foundation
import Observation
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class GiveawayCongratsSheetModel: ViewModel {

  enum Phase: Equatable { case idle, recording, review }

  // MARK: - Dependencies
  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder
  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer
  @ObservationIgnored @Dependency(\.voicetrackUploadService) var voicetrackUploadService
  @ObservationIgnored @Dependency(\.api) var api

  // MARK: - Shared State
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.pendingCongratsActions) var pendingCongratsActions

  // MARK: - Initialization
  private let eventId: String
  private let stationId: String
  private let winnerName: String?
  private let prizeName: String?
  private let onClose: () -> Void

  init(action: CongratsAction, onClose: @escaping () -> Void) {
    self.eventId = action.eventId
    self.stationId = action.stationId
    self.winnerName = action.winnerName
    self.prizeName = action.prizeName
    self.onClose = onClose
    super.init()
    switch action.state {
    case .recorded(let path):
      recordingURL = URL(fileURLWithPath: path)
      recordingPhase = .review
    case .uploaded:
      readyToSubmit = true
    default:
      break
    }
  }

  // MARK: - Properties
  var recordingPhase: Phase = .idle
  var recordingDuration: TimeInterval = 0
  var playbackPosition: TimeInterval = 0
  var isPlaying = false
  var waveformSamples: [Float] = []
  var isSubmitting = false
  var readyToSubmit = false  // reached at `.uploaded` — Send only re-POSTs (no re-record)
  var uploadStatusText = ""
  var presentedAlert: PlayolaAlert?

  @ObservationIgnored var recordingURL: URL?
  @ObservationIgnored private var recordingTask: Task<Void, Never>?
  @ObservationIgnored private var playbackTask: Task<Void, Never>?

  // MARK: - User Actions

  func viewAppeared() async {
    try? await audioRecorder.prepareForRecording()
  }

  func onRecordTapped() async {
    guard await audioRecorder.requestPermission() else {
      presentedAlert = .congratsMicPermissionDenied
      return
    }
    do {
      waveformSamples = []
      try await audioRecorder.startRecording()
      recordingPhase = .recording
      startRecordingUpdates()
    } catch {
      presentedAlert = .congratsRecordingFailed(error.localizedDescription)
    }
  }

  func onStopTapped() async {
    stopRecordingUpdates()
    do {
      let url = try await audioRecorder.stopRecording()
      let persisted = try Self.persistRecording(url)
      recordingURL = persisted
      try? await audioPlayer.loadFile(persisted)
      recordingDuration = await audioPlayer.duration()
      recordingPhase = .review
      setState(.recorded(localRecordingPath: persisted.path))
    } catch {
      presentedAlert = .congratsRecordingFailed(error.localizedDescription)
    }
  }

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

  func onReRecordTapped() async {
    stopPlaybackUpdates()
    await audioPlayer.stop()
    recordingURL = nil
    recordingDuration = 0
    playbackPosition = 0
    isPlaying = false
    waveformSamples = []
    recordingPhase = .idle
  }

  func sendButtonTapped() async {
    guard !isSubmitting else { return }
    isSubmitting = true
    presentedAlert = nil
    uploadStatusText = ""
    defer { isSubmitting = false }

    // If we already have an uploaded audioBlock (resume after a failed/killed submit), only re-POST.
    if case .uploaded(let audioBlockId) = pendingCongratsActions[eventId]?.state {
      await submitCongrats(audioBlockId: audioBlockId)
      return
    }
    guard let url = recordingURL else { return }
    await uploadThenSubmit(url: url)
  }

  func skipButtonTapped() {
    setState(.skipped)
    cleanUpRecording()
    onClose()
  }

  func closeButtonTapped() {
    onClose()
  }

  // MARK: - View Helpers
  var headline: String {
    let who = winnerName ?? "your winner"
    if let prizeName { return "Congratulate \(who) on winning \(prizeName)!" }
    return "Congratulate \(who)!"
  }
  var subtitle: String { "Record a short message — we'll play it on your station." }
  var skipButtonTitle: String { "Skip" }
  var recordButtonTitle: String { "Record" }
  var stopButtonTitle: String { "Stop" }
  var sendButtonTitle: String { isSubmitting ? "Sending…" : "Send" }
  var canSend: Bool { !isSubmitting && (readyToSubmit || recordingPhase == .review) }
  var showsRecordButton: Bool { !readyToSubmit && recordingPhase == .idle }
  var showsRecordingControls: Bool { recordingPhase == .recording }
  var showsReview: Bool { readyToSubmit || recordingPhase == .review }
  var durationText: String { Self.formatTime(recordingDuration) }

  // Opacity-driven view swaps (the view stays control-flow-free).
  var recordButtonOpacity: Double { showsRecordButton ? 1 : 0 }
  var recordingControlsOpacity: Double { showsRecordingControls ? 1 : 0 }
  var reviewControlsOpacity: Double { showsReview ? 1 : 0 }
  var sendButtonDisabled: Bool { !canSend }
  var sendButtonOpacity: Double { canSend ? 1 : 0.5 }
  var uploadStatusOpacity: Double { uploadStatusText.isEmpty ? 0 : 1 }

  // MARK: - Private Helpers

  private func uploadThenSubmit(url: URL) async {
    guard let jwt = auth.jwt else {
      presentedAlert = .congratsRecordingFailed("Not signed in.")
      return
    }
    let voicetrack = LocalVoicetrack(originalURL: url, title: "Giveaway Congrats")
    let audioBlock: AudioBlock
    do {
      audioBlock = try await voicetrackUploadService.processVoicetrack(voicetrack, stationId, jwt) {
        [weak self] status in
        self?.uploadStatusText = Self.statusText(status)
      }
    } catch {
      // Keep the recording (stays `.recorded`) so the user can retry without re-recording.
      presentedAlert = .congratsUploadFailed(error.localizedDescription)
      return
    }
    setState(.uploaded(audioBlockId: audioBlock.id))
    await submitCongrats(audioBlockId: audioBlock.id)
  }

  private func submitCongrats(audioBlockId: String) async {
    guard let jwt = auth.jwt else {
      presentedAlert = .congratsRecordingFailed("Not signed in.")
      return
    }
    do {
      try await api.recordGiveawayEventCongrats(jwt, eventId, audioBlockId)
      setState(.submitted)
      cleanUpRecording()
      onClose()
    } catch {
      // Stays `.uploaded` so the user can retry the POST without re-uploading.
      presentedAlert = .congratsSubmitFailed(error.localizedDescription)
    }
  }

  private func setState(_ state: CongratsActionState) {
    $pendingCongratsActions.withLock {
      $0[eventId]?.state = state
    }
  }

  private func cleanUpRecording() {
    if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
  }

  /// Copy the recorder's output into Application Support so it survives a kill / app suspension during
  /// the upload (the recorder writes to a transient location).
  private static func persistRecording(_ source: URL) throws -> URL {
    let dir = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let destination = dir.appendingPathComponent("congrats-\(UUID().uuidString).m4a")
    try? FileManager.default.removeItem(at: destination)
    try FileManager.default.copyItem(at: source, to: destination)
    return destination
  }

  private func startRecordingUpdates() {
    recordingTask = Task {
      while !Task.isCancelled {
        recordingDuration = await audioRecorder.currentTime()
        waveformSamples.append(await audioRecorder.getAudioLevel())
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
        if await !audioPlayer.isPlaying() {
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

  private static func statusText(_ status: LocalVoicetrackStatus) -> String {
    switch status {
    case .converting: return "Preparing…"
    case .uploading: return "Uploading…"
    case .normalizing: return "Processing…"
    case .finalizing: return "Finishing…"
    case .completed: return "Done"
    case .failed: return "Failed"
    }
  }

  private static func formatTime(_ time: TimeInterval) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}

extension PlayolaAlert {
  static var congratsMicPermissionDenied: PlayolaAlert {
    PlayolaAlert(
      title: "Microphone Access Needed",
      message: "Enable microphone access in Settings to record a congrats.",
      dismissButton: .cancel(Text("OK")))
  }
  static func congratsRecordingFailed(_ message: String) -> PlayolaAlert {
    PlayolaAlert(title: "Recording Failed", message: message, dismissButton: .cancel(Text("OK")))
  }
  static func congratsUploadFailed(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Upload Failed",
      message: "\(message) Your recording was kept — tap Send to try again.",
      dismissButton: .cancel(Text("OK")))
  }
  static func congratsSubmitFailed(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Couldn't Send", message: "\(message) Tap Send to try again.",
      dismissButton: .cancel(Text("OK")))
  }
}
