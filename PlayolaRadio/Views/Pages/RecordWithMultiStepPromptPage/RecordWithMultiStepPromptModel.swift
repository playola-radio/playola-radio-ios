//
//  RecordWithMultiStepPromptModel.swift
//  PlayolaRadio
//

import Dependencies
import IdentifiedCollections
import Sharing
import SwiftUI

@MainActor
@Observable
class RecordWithMultiStepPromptModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder
  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer

  // MARK: - Shared State

  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(
    screenTitle: String,
    eyebrow: String,
    guideBadge: String?,
    title: String,
    subtitle: String?,
    steps: [RecordPromptStep],
    trackLabel: String,
    isUpsideDown: Bool
  ) {
    self.screenTitle = screenTitle
    self.eyebrow = eyebrow
    self.guideBadge = guideBadge
    self.title = title
    self.subtitle = subtitle
    self.steps = IdentifiedArray(uniqueElements: steps)
    self.trackLabel = trackLabel
    self.isUpsideDown = isUpsideDown
    super.init()
  }

  // MARK: - Properties

  let screenTitle: String
  let eyebrow: String
  let guideBadge: String?
  let title: String
  let subtitle: String?
  let steps: IdentifiedArrayOf<RecordPromptStep>
  let trackLabel: String
  let isUpsideDown: Bool

  /// Handles the finished recording (e.g. upload), reporting progress back so the model can drive
  /// the saving/uploading screen. Injected so the recorder stays generic while the model owns the
  /// surrounding progress/error UI and the pop back to the caller.
  @ObservationIgnored var onUseRecording:
    (
      @Sendable (URL, @escaping @MainActor @Sendable (RecordUploadProgress) -> Void) async throws ->
        Void
    )?

  var recordingPhase: RecordPromptPhase = .ready
  var recordingState: RecordingState = .idle
  var recordingURL: URL?
  var recordedDuration: TimeInterval = 0
  @ObservationIgnored private var recordingSession: RecordingSession?
  var playbackState: PlaybackState = .idle
  @ObservationIgnored private var playbackSession: PlaybackSession?
  var uploadProgress: Double = 0
  var presentedAlert: PlayolaAlert?
  @ObservationIgnored private var isRecordingActionInFlight = false
  @ObservationIgnored private var isLeaving = false

  // MARK: - User Actions

  func viewAppeared() async {
    isLeaving = false
    try? await audioRecorder.prepareForRecording()
  }

  func viewDisappeared() async {
    isLeaving = true
    await teardown()
  }

  func backButtonTapped() {
    switch recordingPhase {
    case .saving, .uploading:
      return
    case .review:
      presentedAlert = .discardRecordingConfirmation { [weak self] in
        self?.leave()
      }
    case .ready, .recording:
      leave()
    }
  }

  func recordButtonTapped() async {
    guard !isRecordingActionInFlight else { return }
    isRecordingActionInFlight = true
    defer { isRecordingActionInFlight = false }
    switch recordingPhase {
    case .ready: await startRecording()
    case .recording: await stopRecording()
    case .review, .saving, .uploading: break
    }
  }

  func playButtonTapped() async {
    if playbackState.isPlaying {
      await playbackSession?.pause()
    } else if playbackSession == nil, let url = recordingURL {
      do {
        playbackSession = try await audioPlayer.startPlayback(url) { [weak self] state in
          self?.playbackState = state
        }
      } catch {
        presentedAlert = .audioPlaybackError(error.localizedDescription)
      }
    } else {
      await playbackSession?.play()
    }
  }

  func reRecordButtonTapped() async {
    await stopPlayback()
    if let url = recordingURL {
      await audioRecorder.deleteRecording(url)
    }
    recordingURL = nil
    recordingSession = nil
    recordingState = .idle
    recordedDuration = 0
    recordingPhase = .ready
  }

  func useRecordingButtonTapped() async {
    guard recordingPhase == .review, let url = recordingURL else { return }
    uploadProgress = 0
    recordingPhase = .saving
    await stopPlayback()
    do {
      try await onUseRecording?(url) { [weak self] progress in
        self?.applyUploadProgress(progress)
      }
      await audioRecorder.deleteRecording(url)
      recordingURL = nil
      navigationCoordinator.pop()
    } catch {
      recordingPhase = .review
      presentedAlert = .recordingSaveFailed(error.localizedDescription)
    }
  }

  func scrubberDragged(locationX: CGFloat, trackWidth: CGFloat) async {
    guard trackWidth > 0 else { return }
    let percent = min(1, max(0, locationX / trackWidth))
    let target = TimeInterval(percent) * playbackDuration
    guard target.isFinite else { return }
    await playbackSession?.seek(target)
  }

  // MARK: - View Helpers

  var rotationDegrees: Double { isUpsideDown ? 180 : 0 }

  /// Hides the tab bar for the full-screen record flow so an accidental tab
  /// switch can't interrupt an in-progress recording.
  var tabBarVisibility: Visibility { .hidden }

  private var isRecording: Bool { recordingPhase == .recording }
  private var isReviewing: Bool { recordingPhase == .review }
  private var isProcessing: Bool { recordingPhase == .saving || recordingPhase == .uploading }

  var showsCues: Bool { recordingPhase == .ready || recordingPhase == .recording }
  var showsRecorder: Bool { recordingPhase == .ready || recordingPhase == .recording }
  var showsReview: Bool { isReviewing }
  var showsProgress: Bool { isProcessing }

  var backButtonEnabled: Bool { !isProcessing }
  var backButtonOpacity: Double { isProcessing ? 0.4 : 1 }

  var navTitle: String {
    switch recordingPhase {
    case .ready, .recording: return screenTitle
    case .review: return "Review Recording"
    case .saving: return "Saving Recording"
    case .uploading: return "Uploading Recording"
    }
  }

  // MARK: - Header

  var headerEyebrow: String {
    switch recordingPhase {
    case .ready, .recording: return eyebrow
    case .review: return "RECORDING SAVED"
    case .saving: return "SAVING RECORDING"
    case .uploading: return "UPLOADING RECORDING"
    }
  }

  var headerBadge: String? {
    switch recordingPhase {
    case .ready, .recording: return guideBadge
    case .review: return "READY TO REVIEW"
    case .saving: return "STEP 1 OF 2"
    case .uploading: return "STEP 2 OF 2"
    }
  }

  var headerTitle: String {
    switch recordingPhase {
    case .ready, .recording: return title
    case .review: return "How does it sound?"
    case .saving, .uploading: return "Uploading your recording\u{2026}"
    }
  }

  var headerSubtitle: String? {
    switch recordingPhase {
    case .ready, .recording: return subtitle
    case .review: return "Listen back, then re-record or use this recording."
    case .saving, .uploading: return "This should only take a moment."
    }
  }

  // MARK: - Recorder Card

  var statusLabel: String { isRecording ? "RECORDING" : "READY" }
  var statusPillColor: Color { isRecording ? .playolaWarmSurface : .playolaSurfaceControl }
  var statusAccentColor: Color { isRecording ? .playolaRed : .playolaTextSecondary }

  var elapsedTime: String { formatTime(recordingState.currentTime) }
  var meterBackgroundColor: Color { isRecording ? .playolaWarmBase : .playolaSurfaceSection }

  var recordButtonTitle: String { isRecording ? "Stop recording" : "Start recording" }
  var recordButtonSystemImage: String { isRecording ? "square.fill" : "mic.fill" }

  private let readyWaveformHeights: [CGFloat] = [4, 6, 4, 8, 4, 6, 4, 8, 4, 6, 4, 8, 4, 6, 4]
  private let liveWaveformBarCount = 15

  var waveformBars: IdentifiedArrayOf<RecordWaveformBar> {
    guard isRecording else {
      return IdentifiedArray(
        uniqueElements: readyWaveformHeights.enumerated().map { index, height in
          RecordWaveformBar(id: index, height: height, color: .playolaTextTertiary)
        })
    }
    let recent = recordingState.waveformSamples.suffix(liveWaveformBarCount)
    let padding = Array(repeating: Float(0), count: max(0, liveWaveformBarCount - recent.count))
    return IdentifiedArray(
      uniqueElements: (padding + recent).enumerated().map { index, sample in
        RecordWaveformBar(id: index, height: 4 + CGFloat(sample) * 32, color: .playolaRed)
      })
  }

  // MARK: - Review Card

  var reviewStatusLabel: String { "RECORDED" }
  var reRecordButtonTitle: String { "Re-record" }
  var reRecordButtonSystemImage: String { "arrow.counterclockwise" }
  var useRecordingButtonTitle: String { "Use recording" }
  var useRecordingButtonSystemImage: String { "checkmark" }

  // MARK: - Progress Card

  private let savingProgressFraction: Double = 0.2

  var progressIconSystemImage: String {
    recordingPhase == .uploading ? "icloud.and.arrow.up" : "square.and.arrow.down"
  }

  var progressCardTitle: String { "Saving and Uploading" }

  var progressLabel: String {
    recordingPhase == .uploading ? "Uploading\u{2026}" : "Saving\u{2026}"
  }

  var progressValue: String {
    guard recordingPhase == .uploading else { return "Preparing" }
    return "\(Int((uploadProgress * 100).rounded()))%"
  }

  var progressFraction: Double {
    recordingPhase == .uploading ? uploadProgress : savingProgressFraction
  }

  var progressSteps: IdentifiedArrayOf<RecordProgressStep> {
    if recordingPhase == .uploading {
      return IdentifiedArray(uniqueElements: [
        RecordProgressStep(
          id: 0, systemImage: "checkmark", iconColor: .playolaTextPrimary,
          iconBackgroundColor: .playolaRed, label: "Saved on this device",
          labelColor: .playolaTextPrimary),
        RecordProgressStep(
          id: 1, systemImage: "icloud.and.arrow.up", iconColor: .playolaRed,
          iconBackgroundColor: .playolaWarmSurface, label: "Uploading to Playola",
          labelColor: .playolaTextPrimary),
      ])
    }
    return IdentifiedArray(uniqueElements: [
      RecordProgressStep(
        id: 0, systemImage: "arrow.triangle.2.circlepath", iconColor: .playolaRed,
        iconBackgroundColor: .playolaWarmSurface, label: "Saving",
        labelColor: .playolaTextPrimary),
      RecordProgressStep(
        id: 1, systemImage: "icloud.and.arrow.up", iconColor: .playolaTextTertiary,
        iconBackgroundColor: .playolaSurfaceControl, label: "Uploading to Playola",
        labelColor: .playolaTextTertiary),
    ])
  }

  private var playbackDuration: TimeInterval {
    playbackState.duration > 0 ? playbackState.duration : recordedDuration
  }

  var reviewDurationText: String { formatTime(playbackDuration) }
  var playbackElapsedText: String { formatTime(playbackState.currentTime) }
  var playbackTotalText: String { formatTime(playbackDuration) }
  var playButtonSystemImage: String { playbackState.isPlaying ? "pause.fill" : "play.fill" }

  var playbackProgress: Double {
    guard playbackDuration > 0 else { return 0 }
    return min(1, max(0, playbackState.currentTime / playbackDuration))
  }

  private let reviewWaveformHeights: [CGFloat] = [
    16, 28, 38, 22, 44, 32, 20, 40, 26, 34, 18, 30,
  ]

  var reviewWaveformBars: IdentifiedArrayOf<RecordWaveformBar> {
    let progress = playbackProgress
    let count = reviewWaveformHeights.count
    return IdentifiedArray(
      uniqueElements: reviewWaveformHeights.enumerated().map { index, height in
        let played = Double(index) / Double(count) < progress
        return RecordWaveformBar(
          id: index, height: height, color: played ? .playolaRed : .playolaTextSecondary)
      })
  }

  // MARK: - Cue Helpers

  func numberText(for step: RecordPromptStep) -> String {
    String(format: "%02d", step.id)
  }

  var cueNumberBackgroundColor: Color { .playolaSurfaceControl }
  var cueNumberForegroundColor: Color { .playolaTextSecondary }
  var cueLabelColor: Color { .playolaTextSecondary }

  func dividerColor(after step: RecordPromptStep) -> Color {
    step.id == steps.last?.id ? .clear : .playolaGlassHairline
  }

  // MARK: - Private Helpers

  private func applyUploadProgress(_ progress: RecordUploadProgress) {
    switch progress {
    case .saving:
      recordingPhase = .saving
    case .uploading(let fraction):
      recordingPhase = .uploading
      uploadProgress = min(1, max(0, fraction))
    case .finishing:
      recordingPhase = .uploading
      uploadProgress = 1
    }
  }

  private func startRecording() async {
    await stopPlayback()
    do {
      let session = try await audioRecorder.startRecordingWithUpdates { [weak self] state in
        self?.recordingState = state
      }
      guard !isLeaving else {
        await session.cancel()
        return
      }
      recordingSession = session
      recordingPhase = .recording
    } catch AudioRecorderError.permissionDenied {
      if !isLeaving {
        presentedAlert = .microphonePermissionDeniedAlert
      }
    } catch {
      if !isLeaving {
        presentedAlert = .recordingFailedAlert(error.localizedDescription)
      }
    }
  }

  private func stopRecording() async {
    let captured = recordingState.currentTime
    do {
      let url = try await recordingSession?.stop()
      recordingURL = url
      recordedDuration = captured
      recordingSession = nil
      recordingPhase = .review
    } catch {
      presentedAlert = .recordingFailedAlert(error.localizedDescription)
    }
  }

  private func stopPlayback() async {
    await playbackSession?.stop()
    playbackSession = nil
    playbackState = .idle
  }

  private func leave() {
    isLeaving = true
    navigationCoordinator.pop()
    Task { await discardRecording() }
  }

  private func discardRecording() async {
    await teardown()
    if let url = recordingURL {
      await audioRecorder.deleteRecording(url)
      recordingURL = nil
    }
  }

  private func teardown() async {
    await stopPlayback()
    await recordingSession?.cancel()
    recordingSession = nil
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

extension RecordWithMultiStepPromptModel {
  static func askMeAnythingIntro(stationId: String) -> RecordWithMultiStepPromptModel {
    let model = RecordWithMultiStepPromptModel(
      screenTitle: "Record Intro",
      eyebrow: "RECORD AN INTRO",
      guideBadge: "OPTIONAL GUIDE",
      title: "Record a short introduction.",
      subtitle: "Introduce the AMA and tell listeners how to send a question.",
      steps: [
        RecordPromptStep(id: 1, label: "INTRODUCE", detail: "Say hello and introduce yourself."),
        RecordPromptStep(
          id: 2,
          label: "EXPLAIN",
          detail: "Briefly explain that listeners can ask about your music, the station, "
            + "or what you\u{2019}re working on."),
        RecordPromptStep(
          id: 3, label: "DIRECT", detail: "Tell listeners to tap Question in the player."),
      ],
      trackLabel: "INTRO",
      isUpsideDown: true)
    model.onUseRecording = { url, reportProgress in
      @Dependency(\.introUploadService) var introUploadService
      @Shared(.auth) var auth
      guard let jwt = auth.jwt else { throw RecordPromptError.notAuthenticated }
      try await introUploadService.uploadIntro(jwt, url, stationId, "Intro", nil) { status in
        switch status {
        case .converting: reportProgress(.saving)
        case .uploading(let progress): reportProgress(.uploading(progress))
        case .registering, .completed, .failed: reportProgress(.finishing)
        }
      }
    }
    return model
  }
}

enum RecordPromptError: Error {
  case notAuthenticated
}

enum RecordPromptPhase: Equatable {
  case ready
  case recording
  case review
  case saving
  case uploading
}

enum RecordUploadProgress: Equatable {
  case saving
  case uploading(Double)
  case finishing
}

struct RecordPromptStep: Identifiable, Equatable {
  let id: Int
  let label: String
  let detail: String
}

struct RecordWaveformBar: Identifiable, Equatable {
  let id: Int
  let height: CGFloat
  let color: Color
}

struct RecordProgressStep: Identifiable, Equatable {
  let id: Int
  let systemImage: String
  let iconColor: Color
  let iconBackgroundColor: Color
  let label: String
  let labelColor: Color
}

extension PlayolaAlert {
  static func recordingSaveFailed(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Couldn\u{2019}t Save Recording",
      message: message,
      dismissButton: .cancel(Text("OK")))
  }
}
