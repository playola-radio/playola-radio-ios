import Dependencies
import Foundation
import IssueReporting
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
  @ObservationIgnored @Dependency(\.stationPlayer) var stationPlayer

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
    case .uploaded(_, let path):
      // The local file survives until submit succeeds, so a resumed upload can still play back
      // and review before re-sending.
      recordingURL = URL(fileURLWithPath: path)
      recordingPhase = .review
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
  @ObservationIgnored private var isStartingRecording = false
  @ObservationIgnored private var isDismissed = false
  @ObservationIgnored private var recordingTask: Task<Void, Never>?
  @ObservationIgnored private var playbackTask: Task<Void, Never>?

  // MARK: - User Actions

  func viewAppeared() async {
    // The owner records and plays back over a live station; mute it so the station audio doesn't
    // bleed into the recording or talk over the playback. Matches every other capture/playback flow
    // (ContactPage, AskQuestion, WelcomeMessage, PlayerPage) that stops the station before taking
    // over the audio session.
    stationPlayer.stop()
    // Resuming from a persisted recording (.recorded / .uploaded after a kill): load it so review
    // shows a real duration and Play works. Otherwise prime the recorder for a fresh take.
    if let url = recordingURL {
      await withErrorReporting { try await audioPlayer.loadFile(url) }
      recordingDuration = await audioPlayer.duration()
    } else {
      // Priming the recorder stays non-fatal — a failure here surfaces to the user when they tap
      // Record (startRecording throws → congratsRecordingFailed) — but report it so the audio-session
      // setup failure isn't swallowed without a trace.
      await withErrorReporting { try await audioRecorder.prepareForRecording() }
    }
  }

  func viewDisappeared() async {
    // SwiftUI swipe-to-dismiss nils the sheet without routing through skip/send, so this is the only
    // teardown hook for an interactive dismissal — stop the mic/player and suppress re-prompt.
    isDismissed = true
    await stopActiveCapture()
    onClose()
  }

  func onRecordTapped() async {
    // Guard synchronously (before the first await) so a rapid double-tap can't start two recorder
    // sessions while permission/start are in flight.
    guard recordingPhase == .idle, !isStartingRecording else { return }
    isStartingRecording = true
    defer { isStartingRecording = false }
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
    let supersededURL = recordingURL
    recordingURL = nil
    recordingDuration = 0
    playbackPosition = 0
    isPlaying = false
    waveformSamples = []
    recordingPhase = .idle
    // Clear the resume flag too — otherwise re-recording from an `.uploaded`-resumed model (which
    // sets `readyToSubmit = true` in init) would leave `showsRecordButton` false and strand the
    // owner in review with no recording.
    readyToSubmit = false
    setState(.pending)
    if let supersededURL {
      try? FileManager.default.removeItem(at: supersededURL)
    }
    // `viewAppeared` only primes the recorder once (and only when there was no resume file), so
    // re-arm the audio session here or the next `startRecording()` runs on an unprepared session.
    // Non-fatal like the prime in `viewAppeared` (surfaces at record time), but report it so an
    // audio-session setup failure isn't swallowed without a trace.
    await withErrorReporting { try await audioRecorder.prepareForRecording() }
  }

  func sendButtonTapped() async {
    guard !isDismissed, !isSubmitting else { return }
    isSubmitting = true
    presentedAlert = nil
    uploadStatusText = ""
    defer { isSubmitting = false }

    // If we already have an uploaded audioBlock (resume after a failed/killed submit), only re-POST.
    if case .uploaded(let audioBlockId, _) = pendingCongratsActions[eventId]?.state {
      await submitCongrats(audioBlockId: audioBlockId)
      return
    }
    guard let url = recordingURL else { return }
    await uploadThenSubmit(url: url)
  }

  func skipButtonTapped() async {
    // Skip is disabled in the UI while a submit is in flight; guard here too so a stray call can't
    // race the upload/submit and flip an already-sending action to skipped.
    guard !isSubmitting else { return }
    await stopActiveCapture()
    setState(.skipped)
    cleanUpRecording()
    onClose()
  }

  func closeButtonTapped() async {
    isDismissed = true
    await stopActiveCapture()
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
  var playButtonTitle: String { isPlaying ? "Pause" : "Play" }
  var canSend: Bool { !isSubmitting && (readyToSubmit || recordingPhase == .review) }
  var canSkip: Bool { !isSubmitting }
  var canPlay: Bool { recordingURL != nil }
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
  var skipButtonOpacity: Double { canSkip ? 1 : 0.5 }
  var playButtonOpacity: Double { canPlay ? 1 : 0.5 }
  var uploadStatusOpacity: Double { uploadStatusText.isEmpty ? 0 : 1 }

  // MARK: - Private Helpers

  private func uploadThenSubmit(url: URL) async {
    guard let jwt = auth.jwt else {
      presentedAlert = .congratsRecordingFailed("Not signed in.")
      return
    }
    // A recording persisted by an earlier build (before the extension fix) can be WAV bytes inside a
    // `.m4a` file, which makes the converter fail. Normalize to the real container before handing it
    // off, and migrate the persisted state so resume/retry point at the corrected file.
    let uploadURL = Self.audioURLMatchingContent(url)
    if uploadURL != url {
      recordingURL = uploadURL
      setState(.recorded(localRecordingPath: uploadURL.path))
      try? FileManager.default.removeItem(at: url)
    }
    let voicetrack = LocalVoicetrack(originalURL: uploadURL, title: "Giveaway Congrats")
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
    setState(.uploaded(audioBlockId: audioBlock.id, localRecordingPath: uploadURL.path))
    guard !isDismissed else { return }
    await submitCongrats(audioBlockId: audioBlock.id)
  }

  private func submitCongrats(audioBlockId: String) async {
    // The owner skipped or dismissed while the upload was running — honor that and don't POST.
    guard !isDismissed, !isActionTerminal else { return }
    guard let jwt = auth.jwt else {
      presentedAlert = .congratsRecordingFailed("Not signed in.")
      return
    }
    do {
      try await api.recordGiveawayEventCongrats(jwt, eventId, audioBlockId)
      setState(.submitted)
      cleanUpRecording()
      onClose()
    } catch is GiveawayCongratsError {
      // The server window closed — retrying can never succeed. Mark terminal, clean up, and dismiss
      // (the terminal state keeps the arbiter from ever re-prompting) instead of looping the owner
      // on a retry alert.
      setState(.alreadyClosed)
      cleanUpRecording()
      onClose()
    } catch {
      // Stays `.uploaded` so the user can retry the POST without re-uploading.
      presentedAlert = .congratsSubmitFailed(error.localizedDescription)
    }
  }

  private var isActionTerminal: Bool {
    pendingCongratsActions[eventId]?.isTerminal ?? false
  }

  private func setState(_ state: CongratsActionState) {
    $pendingCongratsActions.withLock {
      // Never overwrite a terminal decision (skipped/submitted/alreadyClosed). A stale in-flight task
      // or another model instance must not resurrect or change a finished action.
      guard let existing = $0[eventId], !existing.isTerminal else { return }
      $0[eventId]?.state = state
    }
  }

  /// Tear down any in-flight recording or playback before the sheet closes, so the mic and the
  /// update loops don't keep running (and keeping `self` alive) after the owner dismisses the flow.
  private func stopActiveCapture() async {
    stopRecordingUpdates()
    stopPlaybackUpdates()
    if recordingPhase == .recording {
      _ = try? await audioRecorder.stopRecording()
    }
    await audioPlayer.stop()
    isPlaying = false
  }

  private func cleanUpRecording() {
    if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
  }

  /// Copy the recorder's output into Application Support so it survives a kill / app suspension during
  /// the upload (the recorder writes to a transient location).
  ///
  /// Name the copy by its real container (the recorder produces Linear PCM `.wav`). Renaming WAV bytes
  /// to `.m4a` makes `AVURLAsset` infer an MPEG-4 container from the extension, fail to parse the WAV
  /// bytes, and the converter throws "Audio conversion failed" on every Send.
  private static func persistRecording(_ source: URL) throws -> URL {
    let dir = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let ext =
      audioContainerExtension(of: source)
      ?? (source.pathExtension.isEmpty ? "wav" : source.pathExtension)
    let destination = dir.appendingPathComponent("congrats-\(UUID().uuidString).\(ext)")
    try? FileManager.default.removeItem(at: destination)
    try FileManager.default.copyItem(at: source, to: destination)
    return destination
  }

  /// Magic-byte container detection (`wav`/`m4a`), or nil if unrecognized. AVFoundation infers a file's
  /// container from its path extension, so this lets callers name files by their actual content instead
  /// of trusting a (possibly stale) extension.
  private static func audioContainerExtension(of url: URL) -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }
    guard let header = try? handle.read(upToCount: 12), header.count >= 8 else { return nil }
    let bytes = [UInt8](header)
    if bytes.count >= 12, Array(bytes[0..<4]) == Array("RIFF".utf8),
      Array(bytes[8..<12]) == Array("WAVE".utf8)
    {
      return "wav"
    }
    // An `ftyp` box marks an ISO Base Media file; confirm the major brand is MPEG-4 audio/video before
    // claiming `m4a`, so a MOV/HEIF/other ISO container isn't silently renamed.
    if Array(bytes[4..<8]) == Array("ftyp".utf8), bytes.count >= 12 {
      let knownM4ABrands = ["M4A ", "isom", "mp42", "mp41"].map { Array($0.utf8) }
      if knownM4ABrands.contains(Array(bytes[8..<12])) {
        return "m4a"
      }
    }
    return nil
  }

  /// If `url`'s extension doesn't match its actual container, copy the bytes into a correctly-named
  /// sibling so AVFoundation reads the real format. Returns the original URL when it already matches
  /// (or the content can't be identified).
  private static func audioURLMatchingContent(_ url: URL) -> URL {
    guard let contentExt = audioContainerExtension(of: url),
      url.pathExtension.lowercased() != contentExt
    else { return url }
    let corrected = url.deletingPathExtension().appendingPathExtension(contentExt)
    try? FileManager.default.removeItem(at: corrected)
    guard (try? FileManager.default.copyItem(at: url, to: corrected)) != nil else { return url }
    return corrected
  }

  private func startRecordingUpdates() {
    recordingTask?.cancel()
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
    playbackTask?.cancel()
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
