//
//  ListenerQuestionDetailPageModel.swift
//  PlayolaRadio
//

import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI

enum AnswerRecordingPhase: Equatable {
  case idle
  case recording
  case review
}

enum AnswerUploadPhase: Equatable {
  case notStarted
  case converting
  case uploading(progress: Double)
  case normalizing
  case finalizing
  case linkingAnswer
  case completed
  case failed(error: String)
}

@MainActor
@Observable
class ListenerQuestionDetailPageModel: ViewModel {
  // MARK: - State

  let question: ListenerQuestion

  // Question playback
  var questionPlaybackState: PlaybackState = .idle
  private var questionPlaybackSession: PlaybackSession?

  // Answer recording
  var recordingPhase: AnswerRecordingPhase = .idle
  var recordingState: RecordingState = .idle
  private var recordingSession: RecordingSession?
  var recordingURL: URL?

  // Answer playback
  var answerPlaybackState: PlaybackState = .idle
  private var answerPlaybackSession: PlaybackSession?

  // Upload
  var uploadPhase: AnswerUploadPhase = .notStarted
  var presentedAlert: PlayolaAlert?

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer
  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder
  @ObservationIgnored @Dependency(\.voicetrackUploadService) var voicetrackUploadService
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Display Text

  let navigationTitle = "Listener Question"
  let questionSectionTitle = "QUESTION"
  let responseSectionTitle = "YOUR RESPONSE"
  let discardButtonTitle = "Discard"
  let uploadButtonTitle = "Upload Response"

  var recordButtonLabel: String {
    switch recordingPhase {
    case .idle: return "Tap to Record"
    case .recording: return "Tap to Stop"
    case .review: return "Try Again"
    }
  }

  // MARK: - Listener Info Display

  var listenerName: String {
    question.listener?.fullName ?? "Unknown Listener"
  }

  var listenerInitials: String {
    guard let listener = question.listener else { return "?" }
    let first = listener.firstName.prefix(1)
    let last = listener.lastName?.prefix(1) ?? ""
    return "\(first)\(last)".uppercased()
  }

  var listenerProfileImageUrl: URL? {
    guard let urlString = question.listener?.profileImageUrl else { return nil }
    return URL(string: urlString)
  }

  var transcription: String {
    question.transcription ?? "No transcription available"
  }

  var timeAgoText: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: question.createdAt, relativeTo: Date())
  }

  // MARK: - Question Playback Display

  var questionDurationText: String {
    formatTime(questionPlaybackState.duration)
  }

  var questionPlaybackPositionText: String {
    formatTime(questionPlaybackState.currentTime)
  }

  var questionPlayButtonIcon: String {
    questionPlaybackState.isPlaying ? "stop.fill" : "play.fill"
  }

  // MARK: - Recording Display

  var recordingTimeText: String {
    formatTime(recordingState.currentTime)
  }

  var recordButtonIcon: String {
    switch recordingPhase {
    case .idle, .review: return "mic.fill"
    case .recording: return "stop.fill"
    }
  }

  var showRecordingIndicator: Bool {
    recordingPhase == .recording
  }

  var waveformSamples: [Float] {
    recordingState.waveformSamples
  }

  var showWaveformPlaceholder: Bool {
    recordingPhase == .idle && waveformSamples.isEmpty
  }

  var waveformPlaceholderText: String {
    "Your recording will appear here"
  }

  // MARK: - Answer Playback Display

  var answerPlaybackPositionText: String {
    formatTime(answerPlaybackState.currentTime)
  }

  var answerPlayButtonIcon: String {
    answerPlaybackState.isPlaying ? "pause.fill" : "play.fill"
  }

  var showAnswerPlaybackControls: Bool {
    recordingPhase == .review
  }

  var showAnswerActionButtons: Bool {
    recordingPhase == .review && !isUploading && uploadPhase != .completed
  }

  // MARK: - Upload Display

  var isUploading: Bool {
    switch uploadPhase {
    case .notStarted, .completed, .failed: return false
    case .converting, .uploading, .normalizing, .finalizing, .linkingAnswer: return true
    }
  }

  var showUploadStatus: Bool {
    uploadPhase != .notStarted
  }

  var uploadStatusText: String {
    switch uploadPhase {
    case .notStarted: return ""
    case .converting: return "Converting audio..."
    case .uploading(let progress): return "Uploading \(Int(progress * 100))%"
    case .normalizing: return "Processing..."
    case .finalizing: return "Finalizing..."
    case .linkingAnswer: return "Registering response..."
    case .completed: return "Complete!"
    case .failed(let error): return "Failed: \(error)"
    }
  }

  var uploadProgress: Double {
    switch uploadPhase {
    case .notStarted: return 0
    case .converting: return 0.1
    case .uploading(let progress): return 0.1 + (progress * 0.5)
    case .normalizing: return 0.65
    case .finalizing: return 0.75
    case .linkingAnswer: return 0.85
    case .completed: return 1.0
    case .failed: return 0
    }
  }

  var canRecord: Bool {
    !isUploading && uploadPhase != .completed
  }

  // MARK: - Init

  init(question: ListenerQuestion) {
    self.question = question
    super.init()
  }

  // MARK: - View Lifecycle

  func viewAppeared() async {
    do {
      try await audioRecorder.prepareForRecording()
    } catch {
      // Preparation failed - recording will still work but may have latency
    }
  }

  func viewDisappeared() async {
    await stopAllPlayback()
  }

  // MARK: - Question Playback Actions

  func playQuestionButtonTapped() async {
    guard let audioBlock = question.audioBlock,
      let downloadUrl = audioBlock.downloadUrl
    else { return }

    if questionPlaybackState.isPlaying {
      await questionPlaybackSession?.stop()
      questionPlaybackSession = nil
      questionPlaybackState = .idle
    } else {
      await stopAnswerPlayback()

      do {
        questionPlaybackSession = try await audioPlayer.startPlayback(downloadUrl) {
          [weak self] state in
          self?.questionPlaybackState = state
        }
      } catch {
        presentedAlert = .audioPlaybackError(error.localizedDescription)
      }
    }
  }

  // MARK: - Recording Actions

  func recordButtonTapped() async {
    switch recordingPhase {
    case .idle:
      await startRecording()
    case .recording:
      await stopRecording()
    case .review:
      await reRecord()
    }
  }

  func discardButtonTapped() {
    presentedAlert = .discardRecordingConfirmation { [weak self] in
      Task { await self?.discardRecording() }
    }
  }

  func uploadButtonTapped() async {
    await uploadAnswer()
  }

  // MARK: - Answer Playback Actions

  func answerPlayPauseButtonTapped() async {
    if answerPlaybackState.isPlaying {
      await answerPlaybackSession?.pause()
    } else {
      if answerPlaybackSession == nil, let url = recordingURL {
        do {
          answerPlaybackSession = try await audioPlayer.startPlayback(url) { [weak self] state in
            self?.answerPlaybackState = state
          }
        } catch {
          presentedAlert = .audioPlaybackError(error.localizedDescription)
        }
      } else {
        await answerPlaybackSession?.play()
      }
    }
  }

  func answerRewindButtonTapped() async {
    await answerPlaybackSession?.seek(0)
  }

  func answerScrubberDragged(to time: TimeInterval) async {
    await answerPlaybackSession?.seek(time)
  }

  // MARK: - Navigation Actions

  func backButtonTapped() {
    if recordingPhase == .review {
      presentedAlert = .discardRecordingConfirmation { [weak self] in
        Task { await self?.navigateBack() }
      }
    } else {
      Task { await navigateBack() }
    }
  }

  // MARK: - Private Recording Logic

  private func startRecording() async {
    await stopQuestionPlayback()

    do {
      recordingSession = try await audioRecorder.startRecordingWithUpdates { [weak self] state in
        self?.recordingState = state
      }
      recordingPhase = .recording
    } catch AudioRecorderError.permissionDenied {
      presentedAlert = .microphonePermissionDeniedAlert
    } catch {
      presentedAlert = .recordingFailedAlert(error.localizedDescription)
    }
  }

  private func stopRecording() async {
    do {
      let url = try await recordingSession?.stop()
      recordingURL = url
      recordingSession = nil
      recordingPhase = .review
    } catch {
      presentedAlert = .recordingFailedAlert(error.localizedDescription)
    }
  }

  private func reRecord() async {
    await stopAnswerPlayback()
    if let url = recordingURL {
      await recordingSession?.delete(url)
    }
    recordingURL = nil
    recordingState = .idle
    recordingPhase = .idle
    uploadPhase = .notStarted
  }

  private func discardRecording() async {
    await stopAnswerPlayback()
    if let url = recordingURL {
      await audioRecorder.deleteRecording(url)
    }
    recordingURL = nil
    recordingState = .idle
    recordingPhase = .idle
    uploadPhase = .notStarted
  }

  private func uploadAnswer() async {
    guard let url = recordingURL, let jwt = auth.jwt else { return }

    await stopAnswerPlayback()

    let voicetrack = LocalVoicetrack(originalURL: url, title: "Response to \(listenerName)")

    do {
      let audioBlock = try await voicetrackUploadService.processVoicetrack(
        voicetrack,
        question.stationId,
        jwt
      ) { [weak self] status in
        self?.handleUploadStatusChange(status)
      }

      uploadPhase = .linkingAnswer
      _ = try await api.registerListenerQuestionAnswer(
        jwt,
        question.stationId,
        question.id,
        audioBlock.id
      )

      uploadPhase = .completed
      presentedAlert = .answerUploadedSuccess { [weak self] in
        self?.mainContainerNavigationCoordinator.popToRoot()
      }
    } catch {
      uploadPhase = .failed(error: error.localizedDescription)
    }
  }

  private func handleUploadStatusChange(_ status: LocalVoicetrackStatus) {
    switch status {
    case .converting:
      uploadPhase = .converting
    case .uploading(let progress):
      uploadPhase = .uploading(progress: progress)
    case .normalizing:
      uploadPhase = .normalizing
    case .finalizing:
      uploadPhase = .finalizing
    case .completed:
      uploadPhase = .completed
    case .failed(let error):
      uploadPhase = .failed(error: error)
    }
  }

  private func navigateBack() async {
    await stopAllPlayback()
    if let url = recordingURL {
      await audioRecorder.deleteRecording(url)
    }
    mainContainerNavigationCoordinator.pop()
  }

  // MARK: - Private Playback Helpers

  private func stopQuestionPlayback() async {
    await questionPlaybackSession?.stop()
    questionPlaybackSession = nil
    questionPlaybackState = .idle
  }

  private func stopAnswerPlayback() async {
    await answerPlaybackSession?.stop()
    answerPlaybackSession = nil
    answerPlaybackState = .idle
  }

  private func stopAllPlayback() async {
    await stopQuestionPlayback()
    await stopAnswerPlayback()
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

// MARK: - Alerts

extension PlayolaAlert {
  static func answerUploadedSuccess(onDismiss: @escaping () -> Void) -> PlayolaAlert {
    PlayolaAlert(
      title: "Response Uploaded!",
      message: "Your response has been uploaded and will be added to your broadcast.",
      dismissButton: .default(Text("OK"), action: onDismiss)
    )
  }
}
