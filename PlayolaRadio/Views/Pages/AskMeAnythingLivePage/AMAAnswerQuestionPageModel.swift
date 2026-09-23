//
//  AMAAnswerQuestionPageModel.swift
//  PlayolaRadio
//

import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI

/// The optional trailing song a curator can schedule immediately after the Q&A pair.
/// `unchanged` leaves the question's existing trailing untouched (no PUT); `cleared` is an
/// explicit removal (PUT null); `selected` sets it (PUT the block id).
enum AMATrailingSongDraft: Equatable {
  case unchanged
  case selected(AudioBlock)
  case cleared
}

enum AMAAnswerSubmissionPhase: Equatable {
  case notStarted
  case converting
  case uploading(progress: Double)
  case normalizing
  case finalizing
  case linkingAnswer
  case applyingTrailing
  case scheduling
  case completed
  case failed(error: String)
}

@MainActor
@Observable
class AMAAnswerQuestionPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer
  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder
  @ObservationIgnored @Dependency(\.voicetrackUploadService) var voicetrackUploadService
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(
    question: ListenerQuestion,
    airQuestion: @escaping @MainActor (String) async throws -> Void
  ) {
    self.question = question
    self.airQuestion = airQuestion
    super.init()
  }

  // MARK: - Properties

  let question: ListenerQuestion
  @ObservationIgnored let airQuestion: @MainActor (String) async throws -> Void
  let maxAnswerSeconds: TimeInterval = 120

  // Question playback
  var questionPlaybackState: PlaybackState = .idle
  @ObservationIgnored private var questionPlaybackSession: PlaybackSession?

  // Answer recording
  var recordingPhase: AnswerRecordingPhase = .idle
  var recordingState: RecordingState = .idle
  @ObservationIgnored private var recordingSession: RecordingSession?
  var recordingURL: URL?
  private var answerDurationSeconds: TimeInterval = 0

  // Answer playback
  var answerPlaybackState: PlaybackState = .idle
  @ObservationIgnored private var answerPlaybackSession: PlaybackSession?

  // Trailing song draft
  var trailingDraft: AMATrailingSongDraft = .unchanged {
    didSet { hasAppliedTrailing = false }
  }

  // Submission (resumable)
  var submissionPhase: AMAAnswerSubmissionPhase = .notStarted
  private var uploadedAudioBlockId: String?
  private var hasRegisteredAnswer = false
  private var hasAppliedTrailing = false
  private var hasAired = false

  var presentedAlert: PlayolaAlert?

  // MARK: - Display Text

  var navigationTitle: String { "Answer \(question.listener?.firstName ?? "Listener")" }
  let questionSectionTitle = "QUESTION"
  let responseSectionTitle = "YOUR RESPONSE"
  let idlePrompt = "Tap the mic to record your response"
  let idleHint = "Up to 2:00"
  let idleRecordLabel = "Tap to start recording"
  let recordingLabel = "Recording"
  let stopRecordingLabel = "Stop recording"
  let reviewLabel = "Ready to review"
  let reRecordLabel = "Re-record"
  let addToShowLabel = "Add to Show"
  let addSongLabel = "Add a song after this"
  let changeSongLabel = "Change song"
  let removeSongLabel = "Remove"
  let missingTranscriptionText = "No transcription available"

  // MARK: - Listener Display

  var listenerName: String { question.listener?.fullName ?? "Listener" }

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

  var transcription: String { question.transcription ?? missingTranscriptionText }

  var timeAgoText: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: question.createdAt, relativeTo: now)
  }

  // MARK: - Question Playback Display

  var questionDuration: TimeInterval {
    if questionPlaybackState.duration > 0 { return questionPlaybackState.duration }
    guard let durationMS = question.durationMS else { return questionPlaybackState.duration }
    return TimeInterval(durationMS) / 1000
  }

  var questionDurationText: String { formatTime(questionDuration) }
  var questionPlaybackPositionText: String { formatTime(questionPlaybackState.currentTime) }

  var questionPlaybackProgress: Double {
    let duration = questionDuration
    guard duration > 0 else { return 0 }
    return min(1, max(0, questionPlaybackState.currentTime / duration))
  }

  var questionPlayButtonIcon: String {
    questionPlaybackState.isPlaying ? "stop.fill" : "play.fill"
  }

  // MARK: - Recording Display

  var recordingTimeText: String {
    "\(formatTime(recordingState.currentTime)) / \(formatTime(maxAnswerSeconds))"
  }

  var recordButtonIcon: String {
    switch recordingPhase {
    case .idle, .review: return "mic.fill"
    case .recording: return "stop.fill"
    }
  }

  var recordStatusText: String {
    switch recordingPhase {
    case .idle: return idlePrompt
    case .recording: return recordingLabel
    case .review: return reviewLabel
    }
  }

  var showRecordingIndicator: Bool { recordingPhase == .recording }

  var tabBarVisibility: Visibility { recordingPhase == .recording ? .hidden : .automatic }

  var waveformSamples: [Float] { recordingState.waveformSamples }

  var showWaveformPlaceholder: Bool {
    recordingPhase == .idle && waveformSamples.isEmpty
  }

  var showIdlePrompt: Bool { recordingPhase == .idle }
  var showReviewControls: Bool { recordingPhase == .review }

  // MARK: - Answer Playback Display

  var answerPlaybackPositionText: String { formatTime(answerPlaybackState.currentTime) }
  var answerDurationText: String {
    "\(formatTime(answerDurationSeconds)) / \(formatTime(maxAnswerSeconds))"
  }

  var answerPlayButtonIcon: String {
    answerPlaybackState.isPlaying ? "pause.fill" : "play.fill"
  }

  // MARK: - Trailing Song Display

  var displayedTrailingSong: AudioBlock? {
    switch trailingDraft {
    case .selected(let block): return block
    case .cleared: return nil
    case .unchanged: return question.trailingAudioBlock
    }
  }

  var showAddSongButton: Bool { displayedTrailingSong == nil }
  var trailingSongTitle: String { displayedTrailingSong?.title ?? "" }
  var trailingSongArtist: String { displayedTrailingSong?.artist ?? "" }
  var trailingSongArtworkURL: URL? { displayedTrailingSong?.imageUrl }

  // MARK: - Pair Total Display

  var pairTotalText: String {
    let questionSeconds = questionDuration
    let total = questionSeconds + answerDurationSeconds
    return "Question + answer · \(formatTime(total)) total"
  }

  // MARK: - Submission Display

  var isSubmitting: Bool {
    switch submissionPhase {
    case .notStarted, .completed, .failed: return false
    case .converting, .uploading, .normalizing, .finalizing, .linkingAnswer, .applyingTrailing,
      .scheduling:
      return true
    }
  }

  var showSubmissionStatus: Bool {
    switch submissionPhase {
    case .notStarted: return false
    default: return true
    }
  }

  var submissionStatusText: String {
    switch submissionPhase {
    case .notStarted: return ""
    case .converting: return "Converting audio…"
    case .uploading(let progress): return "Uploading \(Int(progress * 100))%"
    case .normalizing: return "Processing…"
    case .finalizing: return "Finalizing…"
    case .linkingAnswer: return "Saving your answer…"
    case .applyingTrailing: return "Adding your song…"
    case .scheduling: return "Adding to your show…"
    case .completed: return "Added!"
    case .failed(let error): return "Failed: \(error)"
    }
  }

  var addToShowButtonTitle: String { isSubmitting ? "Adding…" : addToShowLabel }
  var controlsInteractive: Bool { !isSubmitting && !hasAired }

  // MARK: - View Styling

  var controlsDisabled: Bool { !controlsInteractive }
  var recordingIndicatorOpacity: Double { showRecordingIndicator ? 1 : 0 }
  var reviewControlsOpacity: Double { showReviewControls ? 1 : 0 }
  var recordButtonSectionOpacity: Double { showReviewControls ? 0 : 1 }
  var submissionStatusOpacity: Double { showSubmissionStatus ? 1 : 0 }
  var submissionSpinnerOpacity: Double { isSubmitting ? 1 : 0 }
  var waveformPlaceholderOpacity: Double { showWaveformPlaceholder ? 1 : 0 }
  var idlePromptOpacity: Double { showIdlePrompt ? 1 : 0 }
  var addSongButtonOpacity: Double { showAddSongButton ? 1 : 0 }
  var trailingSongRowOpacity: Double { showAddSongButton ? 0 : 1 }
  var answerPlaybackProgress: Double { answerPlaybackState.progress }

  // MARK: - View Lifecycle

  func viewAppeared() async {
    do {
      try await audioRecorder.prepareForRecording()
    } catch {
      // Preparation failure only adds latency; recording still works.
    }
  }

  // MARK: - Question Playback Actions

  func playQuestionButtonTapped() async {
    guard let audioBlock = question.audioBlock, let downloadUrl = audioBlock.downloadUrl
    else { return }

    if questionPlaybackState.isPlaying {
      await stopQuestionPlayback()
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

  func questionScrubberDragged(locationX: CGFloat, trackWidth: CGFloat) async {
    guard trackWidth > 0 else { return }
    let percent = min(1, max(0, locationX / trackWidth))
    let target = TimeInterval(percent) * questionDuration
    guard target.isFinite else { return }
    await questionPlaybackSession?.seek(target)
  }

  // MARK: - Recording Actions

  func recordButtonTapped() async {
    guard controlsInteractive else { return }
    switch recordingPhase {
    case .idle: await startRecording()
    case .recording: await stopRecording()
    case .review: await reRecord()
    }
  }

  // MARK: - Answer Playback Actions

  func answerPlayPauseButtonTapped() async {
    if answerPlaybackState.isPlaying {
      await answerPlaybackSession?.pause()
    } else {
      await stopQuestionPlayback()
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

  func answerScrubberDragged(locationX: CGFloat, trackWidth: CGFloat) async {
    guard trackWidth > 0 else { return }
    let percent = min(1, max(0, locationX / trackWidth))
    let target = TimeInterval(percent) * answerPlaybackState.duration
    guard target.isFinite else { return }
    await answerPlaybackSession?.seek(target)
  }

  // MARK: - Trailing Song Actions

  func addSongButtonTapped() {
    presentSongPicker()
  }

  func changeSongButtonTapped() {
    presentSongPicker()
  }

  func removeSongButtonTapped() {
    trailingDraft = .cleared
  }

  // MARK: - Submit / Navigation Actions

  func addToShowButtonTapped() async {
    guard recordingPhase == .review, !isSubmitting, !hasAired else { return }
    await submit()
  }

  func backButtonTapped() {
    guard !isSubmitting else { return }
    if recordingPhase == .review, !hasAired {
      presentedAlert = .discardRecordingConfirmation { [weak self] in
        Task { await self?.navigateBack() }
      }
    } else {
      Task { await navigateBack() }
    }
  }

  func viewDisappeared() async {
    await stopAllPlayback()
  }

  // MARK: - Private Recording Logic

  private func startRecording() async {
    await stopQuestionPlayback()
    await stopAnswerPlayback()
    do {
      recordingSession = try await audioRecorder.startRecordingWithUpdates { [weak self] state in
        guard let self else { return }
        recordingState = state
        if recordingPhase == .recording, state.currentTime >= maxAnswerSeconds {
          Task { await self.stopRecording() }
        }
      }
      recordingPhase = .recording
    } catch AudioRecorderError.permissionDenied {
      presentedAlert = .microphonePermissionDeniedAlert
    } catch {
      presentedAlert = .recordingFailedAlert(error.localizedDescription)
    }
  }

  private func stopRecording() async {
    guard recordingPhase == .recording else { return }
    let recordedSeconds = recordingState.currentTime
    do {
      let url = try await recordingSession?.stop()
      recordingURL = url
      answerDurationSeconds = min(recordedSeconds, maxAnswerSeconds)
      recordingSession = nil
      recordingPhase = .review
    } catch {
      presentedAlert = .recordingFailedAlert(error.localizedDescription)
    }
  }

  private func reRecord() async {
    await stopAnswerPlayback()
    if let url = recordingURL { await recordingSession?.delete(url) }
    recordingURL = nil
    recordingState = .idle
    recordingPhase = .idle
    answerDurationSeconds = 0
    resetSubmissionProgress()
  }

  private func resetSubmissionProgress() {
    submissionPhase = .notStarted
    uploadedAudioBlockId = nil
    hasRegisteredAnswer = false
    hasAppliedTrailing = false
  }

  private func submit() async {
    guard let jwt = auth.jwt else {
      presentedAlert = PlayolaAlert(
        title: "Sign In Required", message: "Sign in to add this to your show.",
        dismissButton: .cancel(Text("OK")))
      return
    }
    submissionPhase = .converting
    do {
      let audioBlockId = try await uploadIfNeeded(jwt: jwt)
      try await registerAnswerIfNeeded(jwt: jwt, audioBlockId: audioBlockId)
      try await applyTrailingIfNeeded(jwt: jwt)

      submissionPhase = .scheduling
      try await airQuestion(question.id)
      hasAired = true
      submissionPhase = .completed
      navigationCoordinator.popToAskMeAnythingLive()
    } catch is CancellationError {
      submissionPhase = .failed(error: "Your show is no longer available.")
    } catch {
      submissionPhase = .failed(error: error.localizedDescription)
    }
  }

  private func uploadIfNeeded(jwt: String) async throws -> String {
    if let existing = uploadedAudioBlockId { return existing }
    guard let url = recordingURL else { throw CancellationError() }
    await stopAnswerPlayback()
    let voicetrack = LocalVoicetrack(originalURL: url, title: "Response to \(listenerName)")
    let audioBlock = try await voicetrackUploadService.processVoicetrack(
      voicetrack, question.stationId, jwt
    ) { [weak self] status in
      self?.handleUploadStatusChange(status)
    }
    uploadedAudioBlockId = audioBlock.id
    return audioBlock.id
  }

  private func registerAnswerIfNeeded(jwt: String, audioBlockId: String) async throws {
    guard !hasRegisteredAnswer else { return }
    submissionPhase = .linkingAnswer
    _ = try await api.registerListenerQuestionAnswer(
      jwt, question.stationId, question.id, audioBlockId)
    hasRegisteredAnswer = true
  }

  private func applyTrailingIfNeeded(jwt: String) async throws {
    guard !hasAppliedTrailing else { return }
    switch trailingDraft {
    case .unchanged:
      break
    case .selected(let block):
      submissionPhase = .applyingTrailing
      _ = try await api.updateListenerQuestionTrailingAudioBlock(
        jwt, question.stationId, question.id, block.id)
    case .cleared:
      submissionPhase = .applyingTrailing
      _ = try await api.updateListenerQuestionTrailingAudioBlock(
        jwt, question.stationId, question.id, nil)
    }
    hasAppliedTrailing = true
  }

  private func handleUploadStatusChange(_ status: LocalVoicetrackStatus) {
    switch status {
    case .converting: submissionPhase = .converting
    case .uploading(let progress): submissionPhase = .uploading(progress: progress)
    case .normalizing: submissionPhase = .normalizing
    case .finalizing: submissionPhase = .finalizing
    case .completed: submissionPhase = .finalizing
    case .failed(let error): submissionPhase = .failed(error: error)
    }
  }

  private func presentSongPicker() {
    let picker = CuratorSongPickerPageModel(stationId: question.stationId)
    picker.onAddSong = { [weak self] audioBlock in
      guard let self else { return }
      trailingDraft = .selected(audioBlock)
    }
    picker.onDismiss = { [weak self] in
      self?.navigationCoordinator.presentedSheet = nil
    }
    navigationCoordinator.presentedSheet = .curatorSongPicker(picker)
  }

  private func navigateBack() async {
    await stopAllPlayback()
    if let url = recordingURL { await audioRecorder.deleteRecording(url) }
    navigationCoordinator.pop()
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
    let totalSeconds = Int(max(0, seconds))
    return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
  }
}
