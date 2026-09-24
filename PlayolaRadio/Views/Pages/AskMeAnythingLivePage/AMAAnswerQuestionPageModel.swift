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

/// How the page behaves. `.record` captures a new answer; `.reviewAnswer` opens an
/// already-answered question read-only — the recorder stays inert, the existing answer plays,
/// and only the trailing song and "Add to Show" remain actionable.
enum AMAAnswerMode: Equatable {
  case record
  case reviewAnswer
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
    addToShow: @escaping @MainActor (AMAQuestionAnswer) async throws -> Void
  ) {
    self.question = question
    self.addToShow = addToShow
    self.mode = .record
    self.persistedTrailingId = question.trailingAudioBlock?.id
    super.init()
  }

  init(
    answeredQuestion question: ListenerQuestion,
    addToShow: @escaping @MainActor (AMAQuestionAnswer) async throws -> Void
  ) {
    self.question = question
    self.addToShow = addToShow
    self.mode = .reviewAnswer
    self.answerDurationSeconds =
      question.answerAudioBlock.map { TimeInterval($0.durationMS) / 1000 }
      ?? 0
    self.persistedTrailingId = question.trailingAudioBlock?.id
    super.init()
  }

  // MARK: - Properties

  let question: ListenerQuestion
  let mode: AMAAnswerMode
  @ObservationIgnored let addToShow: @MainActor (AMAQuestionAnswer) async throws -> Void
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
  var trailingDraft: AMATrailingSongDraft = .unchanged

  // Submission (resumable)
  var submissionPhase: AMAAnswerSubmissionPhase = .notStarted
  private var uploadedAnswerBlock: AudioBlock?
  private var hasRegisteredAnswer = false
  private var persistedTrailingId: String?
  private var hasAired = false

  var presentedAlert: PlayolaAlert?

  // MARK: - Display Text

  var navigationTitle: String {
    switch mode {
    case .record: return "Answer \(question.listener?.firstName ?? "Listener")"
    case .reviewAnswer: return "Review Answer"
    }
  }
  let questionSectionTitle = "QUESTION"
  let responseSectionTitle = "YOUR RESPONSE"
  let idleInstruction = "Tap the mic to record your response"
  let idleMaxLength = "Up to 2:00"
  let idleRecordLabel = "Tap to start recording"
  let recordingLabel = "Recording"
  let stopRecordingLabel = "Stop recording"
  let reviewLabel = "Ready to review"
  let reRecordLabel = "Re-record"
  let addToShowLabel = "Add to Show"
  let attachSongLabel = "Attach a song"
  let changeSongLabel = "Change song"
  let pairingText = "This question and your answer stay together."
  let flowText = "Question → your answer → optional song"
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

  var questionMetaText: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return
      "\(formatter.localizedString(for: question.createdAt, relativeTo: now)) · Ask Me Anything"
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

  /// Once an answer is ready the full question transport collapses to a compact "▷ 0:08" chip so
  /// the review controls own the vertical space.
  var showQuestionChip: Bool { showReviewControls }
  var questionTransportOpacity: Double { showQuestionChip ? 0 : 1 }
  var questionChipOpacity: Double { showQuestionChip ? 1 : 0 }
  var questionTransportHeight: CGFloat { showQuestionChip ? 0 : 48 }
  var questionChipHeight: CGFloat { showQuestionChip ? 44 : 0 }
  var questionTransportInteractive: Bool { !showQuestionChip }
  var questionChipInteractive: Bool { showQuestionChip }

  // MARK: - Response State

  var showIdleResponse: Bool { mode == .record && recordingPhase == .idle }
  var showRecordingResponse: Bool { recordingPhase == .recording }
  var showReviewResponse: Bool { showReviewControls }

  var idleResponseOpacity: Double { showIdleResponse ? 1 : 0 }
  var recordingResponseOpacity: Double { showRecordingResponse ? 1 : 0 }
  var reviewResponseOpacity: Double { showReviewResponse ? 1 : 0 }

  /// Natural height when active, `0` to collapse — only one response block is ever active, so the
  /// card sizes to it.
  var idleResponseHeight: CGFloat? { showIdleResponse ? nil : 0 }
  var recordingResponseHeight: CGFloat? { showRecordingResponse ? nil : 0 }
  var reviewResponseHeight: CGFloat? { showReviewResponse ? nil : 0 }

  var idleResponseInteractive: Bool { showIdleResponse && controlsInteractive }
  var recordingResponseInteractive: Bool { showRecordingResponse && controlsInteractive }
  var reviewResponseInteractive: Bool { showReviewResponse && controlsInteractive }

  var tabBarVisibility: Visibility { recordingPhase == .recording ? .hidden : .automatic }

  var waveformSamples: [Float] { recordingState.waveformSamples }

  var showReviewControls: Bool { canSubmit }

  /// True once the host can add the Q&A to the show: a recorded answer must reach review; a
  /// previously-answered question is submittable immediately.
  var canSubmit: Bool {
    switch mode {
    case .record: return recordingPhase == .review
    case .reviewAnswer: return true
    }
  }

  // MARK: - Recording Display

  var recordingTimeText: String {
    "\(formatTime(recordingState.currentTime)) / \(formatTime(maxAnswerSeconds))"
  }

  // MARK: - Review Display

  var reviewStatusText: String { mode == .reviewAnswer ? "Your recorded answer" : reviewLabel }
  var answerDurationText: String {
    "\(formatTime(answerDurationSeconds)) / \(formatTime(maxAnswerSeconds))"
  }

  var answerPlayButtonIcon: String {
    answerPlaybackState.isPlaying ? "pause.fill" : "play.fill"
  }

  /// The re-record action only exists while recording a fresh answer; an already-answered question
  /// is immutable, so the row collapses in `.reviewAnswer`.
  var showReRecord: Bool { mode == .record }
  var reRecordOpacity: Double { showReRecord ? 1 : 0 }
  var reRecordHeight: CGFloat { showReRecord ? 44 : 0 }
  var reRecordInteractive: Bool { showReRecord && controlsInteractive }

  /// The audio the answer play/pause control renders: the freshly recorded file while recording,
  /// or the already-registered answer block when reviewing an answered question.
  private var answerPlaybackURL: URL? {
    switch mode {
    case .record: return recordingURL
    case .reviewAnswer: return question.answerAudioBlock?.downloadUrl
    }
  }

  // MARK: - Trailing Song Display

  var displayedTrailingSong: AudioBlock? {
    switch trailingDraft {
    case .selected(let block): return block
    case .cleared: return nil
    case .unchanged: return question.trailingAudioBlock
    }
  }

  var songSectionLabel: String {
    showAddSongButton ? "PLAY AFTER ANSWER · OPTIONAL" : "PLAY AFTER ANSWER"
  }

  var showAddSongButton: Bool { displayedTrailingSong == nil }
  var trailingSongTitle: String { displayedTrailingSong?.title ?? "" }
  var trailingSongSubtitle: String {
    guard let song = displayedTrailingSong else { return "" }
    return "\(song.artist) · \(formatTime(TimeInterval(song.durationMS) / 1000))"
  }

  var attachRowOpacity: Double { showAddSongButton ? 1 : 0 }
  var attachRowHeight: CGFloat { showAddSongButton ? 56 : 0 }
  var attachInteractive: Bool { showAddSongButton && controlsInteractive }
  var songRowOpacity: Double { showAddSongButton ? 0 : 1 }
  var songRowHeight: CGFloat { showAddSongButton ? 0 : 76 }
  var songRowInteractive: Bool { !showAddSongButton && controlsInteractive }
  var changeSongHeight: CGFloat { showAddSongButton ? 0 : 18 }

  // MARK: - Footer Display

  var pairingLineOpacity: Double { showReviewControls ? 1 : 0 }
  var pairingLineHeight: CGFloat { showReviewControls ? 16 : 0 }

  var playlistBehaviorText: String {
    guard let song = displayedTrailingSong else { return flowText }
    let questionText = formatTime(questionDuration)
    let answerText = formatTime(answerDurationSeconds)
    let songText = formatTime(TimeInterval(song.durationMS) / 1000)
    return "Question \(questionText) + answer \(answerText) + song \(songText)"
  }

  var addToShowEnabled: Bool { canSubmit && controlsInteractive }
  var addToShowBackground: Color { addToShowEnabled ? .playolaRed : .playolaSurfaceRaised }
  var addToShowForeground: Color { addToShowEnabled ? .playolaSurfaceBase : .playolaTextDisabled }

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
  var submissionStatusOpacity: Double { showSubmissionStatus ? 1 : 0 }

  var addToShowButtonTitle: String { isSubmitting ? "Adding…" : addToShowLabel }
  var controlsInteractive: Bool { !isSubmitting && !hasAired }

  // MARK: - View Lifecycle

  func viewAppeared() async {
    guard mode == .record else { return }
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
    guard mode == .record, controlsInteractive else { return }
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
      if answerPlaybackSession == nil, let url = answerPlaybackURL {
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
    guard canSubmit, !isSubmitting, !hasAired else { return }
    await submit()
  }

  func backButtonTapped() {
    guard !isSubmitting else { return }
    if mode == .record, recordingPhase == .review, !hasAired {
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
    uploadedAnswerBlock = nil
    hasRegisteredAnswer = false
  }

  private func submit() async {
    guard let jwt = auth.jwt else {
      presentedAlert = PlayolaAlert(
        title: "Sign In Required", message: "Sign in to add this to your show.",
        dismissButton: .cancel(Text("OK")))
      return
    }
    guard let questionBlock = question.audioBlock else {
      submissionPhase = .failed(
        error: "This question's audio isn't available yet. Try again shortly.")
      return
    }
    if mode == .record { submissionPhase = .converting }
    do {
      let answerBlock = try await resolvedAnswerBlock(jwt: jwt)
      try await applyTrailingIfNeeded(jwt: jwt)

      let payload = AMAQuestionAnswer(
        questionId: question.id,
        listenerName: question.listener?.firstName ?? "Listener",
        questionBlock: questionBlock,
        answerBlock: answerBlock,
        trailingBlock: displayedTrailingSong)
      submissionPhase = .scheduling
      try await addToShow(payload)
      hasAired = true
      submissionPhase = .completed
      navigationCoordinator.popToAskMeAnythingLive()
    } catch is CancellationError {
      submissionPhase = .failed(error: "Your answer was saved, but couldn't be added to this show.")
    } catch {
      // AMAAddToShowError is a LocalizedError, so its errorDescription surfaces here too.
      submissionPhase = .failed(error: error.localizedDescription)
    }
  }

  /// Returns the answer's `AudioBlock`, uploading + registering a freshly recorded answer as
  /// needed. An already-answered question never re-uploads or re-registers — its immutable block
  /// is returned directly.
  private func resolvedAnswerBlock(jwt: String) async throws -> AudioBlock {
    switch mode {
    case .record:
      let block = try await uploadIfNeeded(jwt: jwt)
      try await registerAnswerIfNeeded(jwt: jwt, audioBlock: block)
      return block
    case .reviewAnswer:
      guard let block = question.answerAudioBlock else { throw CancellationError() }
      return block
    }
  }

  private func uploadIfNeeded(jwt: String) async throws -> AudioBlock {
    if let existing = uploadedAnswerBlock { return existing }
    guard let url = recordingURL else { throw CancellationError() }
    await stopAnswerPlayback()
    let voicetrack = LocalVoicetrack(originalURL: url, title: "Response to \(listenerName)")
    let audioBlock = try await voicetrackUploadService.processVoicetrack(
      voicetrack, question.stationId, jwt
    ) { [weak self] status in
      self?.handleUploadStatusChange(status)
    }
    uploadedAnswerBlock = audioBlock
    return audioBlock
  }

  private func registerAnswerIfNeeded(jwt: String, audioBlock: AudioBlock) async throws {
    guard !hasRegisteredAnswer else { return }
    submissionPhase = .linkingAnswer
    _ = try await api.registerListenerQuestionAnswer(
      jwt, question.stationId, question.id, audioBlock.id)
    hasRegisteredAnswer = true
  }

  /// Applies the trailing song only when it actually differs from what the server already has,
  /// so opening review with an unchanged trailing issues no PUT.
  private func applyTrailingIfNeeded(jwt: String) async throws {
    let desired = displayedTrailingSong?.id
    guard desired != persistedTrailingId else { return }
    submissionPhase = .applyingTrailing
    _ = try await api.updateListenerQuestionTrailingAudioBlock(
      jwt, question.stationId, question.id, desired)
    persistedTrailingId = desired
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
