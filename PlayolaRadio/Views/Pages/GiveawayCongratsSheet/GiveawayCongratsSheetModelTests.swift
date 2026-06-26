import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

// Serialized: these tests mutate the file-backed `@Shared(.pendingCongratsActions)` store under a
// shared key, so parallel Swift Testing could interleave across `await` points and cross-contaminate
// the on-disk state.
@MainActor
@Suite(.serialized)
struct GiveawayCongratsSheetModelTests {
  private func recordedAction() -> CongratsAction {
    CongratsAction(
      eventId: "e1", stationId: "s1", winnerName: "Jo", prizeName: "Two tickets",
      congratsExpiresAt: nil, state: .recorded(localRecordingPath: "/tmp/r.m4a"), startedAt: Date())
  }

  @Test func headlineUsesWinnerAndPrize() {
    let model = GiveawayCongratsSheetModel(action: recordedAction(), onClose: {})
    #expect(model.headline == "Congratulate Jo on winning Two tickets!")
  }

  @Test func sendUploadsThenSubmitsAndMarksSubmitted() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock { $0 = ["e1": recordedAction()] }
    let block = AudioBlock.mockWith()
    var congratsPosted: (String, String)?
    let model = withDependencies {
      $0.voicetrackUploadService.processVoicetrack = { _, _, _, _ in block }
      $0.api.recordGiveawayEventCongrats = { _, eventId, audioBlockId in
        congratsPosted = (eventId, audioBlockId)
      }
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    await model.sendButtonTapped()
    expectNoDifference(actions["e1"]?.state, CongratsActionState.submitted)
    expectNoDifference(congratsPosted?.0, "e1")
    expectNoDifference(congratsPosted?.1, block.id)
  }

  @Test func uploadFailureStaysRecordedForRetry() async {
    struct Boom: Error {}
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock { $0 = ["e1": recordedAction()] }
    let model = withDependencies {
      $0.voicetrackUploadService.processVoicetrack = { _, _, _, _ in throw Boom() }
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    await model.sendButtonTapped()
    // Recording is not lost; user can retry.
    #expect(actions["e1"]?.localRecordingPath == "/tmp/r.m4a")
    #expect(model.presentedAlert != nil)
  }

  @Test func postFailureStaysUploadedForRetry() async {
    struct Boom: Error {}
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock {
      $0 = [
        "e1": CongratsAction(
          eventId: "e1", stationId: "s1", winnerName: nil, prizeName: nil, congratsExpiresAt: nil,
          state: .uploaded(audioBlockId: "ab1", localRecordingPath: "/tmp/r.m4a"),
          startedAt: Date())
      ]
    }
    let model = withDependencies {
      $0.api.recordGiveawayEventCongrats = { _, _, _ in throw Boom() }
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    await model.sendButtonTapped()  // reached at .uploaded → re-POST only
    #expect(actions["e1"]?.audioBlockId == "ab1")  // stays uploaded, retryable
    #expect(model.presentedAlert != nil)
  }

  @Test func dismissDuringUploadDoesNotPostCongrats() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock { $0 = ["e1": recordedAction()] }
    let block = AudioBlock.mockWith(id: "ab1")
    let postedCongrats = LockIsolated(false)
    let (uploadStartedStream, uploadStartedContinuation) = AsyncStream<Void>.makeStream()
    let (releaseUploadStream, releaseUploadContinuation) = AsyncStream<Void>.makeStream()
    var uploadStarted = uploadStartedStream.makeAsyncIterator()
    let model = withDependencies {
      $0.voicetrackUploadService.processVoicetrack = { _, _, _, _ in
        uploadStartedContinuation.yield()
        var releaseUpload = releaseUploadStream.makeAsyncIterator()
        _ = await releaseUpload.next()
        return block
      }
      $0.api.recordGiveawayEventCongrats = { _, _, _ in postedCongrats.setValue(true) }
      $0.audioPlayer.stop = {}
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    let sendTask = Task { await model.sendButtonTapped() }
    _ = await uploadStarted.next()
    await model.viewDisappeared()
    releaseUploadContinuation.yield()
    await sendTask.value
    #expect(!postedCongrats.value)
    expectNoDifference(
      actions["e1"]?.state,
      CongratsActionState.uploaded(audioBlockId: "ab1", localRecordingPath: "/tmp/r.m4a"))
  }

  @Test func skipMarksSkippedAndCloses() async {
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock { $0 = ["e1": recordedAction()] }
    let closed = LockIsolated(false)
    let model = withDependencies {
      $0.audioPlayer.stop = {}
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: { closed.setValue(true) })
    }
    await model.skipButtonTapped()
    expectNoDifference(actions["e1"]?.state, CongratsActionState.skipped)
    #expect(closed.value)
  }

  @Test func windowClosedMarksActionTerminalAndCloses() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock {
      $0 = [
        "e1": CongratsAction(
          eventId: "e1", stationId: "s1", winnerName: nil, prizeName: nil, congratsExpiresAt: nil,
          state: .uploaded(audioBlockId: "ab1", localRecordingPath: "/tmp/r.m4a"), startedAt: Date()
        )
      ]
    }
    let closed = LockIsolated(false)
    let model = withDependencies {
      $0.api.recordGiveawayEventCongrats = { _, _, _ in throw GiveawayCongratsError.windowClosed }
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: { closed.setValue(true) })
    }
    await model.sendButtonTapped()
    // A closed window is terminal — no retry loop; the action is marked closed and the sheet dismisses.
    expectNoDifference(actions["e1"]?.state, CongratsActionState.alreadyClosed)
    #expect(closed.value)
    #expect(model.presentedAlert == nil)
  }

  @Test func reRecordReArmsTheRecorder() async {
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock { $0 = ["e1": recordedAction()] }
    let prepared = LockIsolated(0)
    let model = withDependencies {
      $0.audioPlayer.stop = {}
      $0.audioRecorder.prepareForRecording = { prepared.withValue { $0 += 1 } }
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    await model.onReRecordTapped()
    // The next take must run on a freshly prepared session, not the one stopRecording() left behind.
    #expect(prepared.value == 1)
    #expect(model.recordingPhase == .idle)
  }

  @Test func reRecordFromUploadedResumeReturnsToRecordButton() async {
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    let action = CongratsAction(
      eventId: "e1", stationId: "s1", winnerName: "Jo", prizeName: "P", congratsExpiresAt: nil,
      state: .uploaded(audioBlockId: "ab1", localRecordingPath: "/tmp/r.m4a"), startedAt: Date())
    $actions.withLock { $0 = ["e1": action] }
    let model = withDependencies {
      $0.audioPlayer.stop = {}
      $0.audioRecorder.prepareForRecording = {}
    } operation: {
      GiveawayCongratsSheetModel(action: action, onClose: {})
    }
    #expect(model.readyToSubmit)  // resumed uploaded → review state
    await model.onReRecordTapped()
    // Re-record must drop the resume flag so the Record button comes back (not stranded in review).
    #expect(!model.readyToSubmit)
    #expect(model.showsRecordButton)
    // The discarded uploaded take must not be restored or re-sent if this model is killed before
    // the next stop-recording pass persists a replacement.
    expectNoDifference(actions["e1"]?.state, CongratsActionState.pending)
  }

  @Test func playButtonTitleReflectsPlaybackState() {
    let model = GiveawayCongratsSheetModel(action: recordedAction(), onClose: {})
    #expect(model.playButtonTitle == "Play")
    model.isPlaying = true
    #expect(model.playButtonTitle == "Pause")
  }

  @Test func skipIsIgnoredWhileSubmitting() async {
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock { $0 = ["e1": recordedAction()] }
    let closed = LockIsolated(false)
    let model = withDependencies {
      $0.audioPlayer.stop = {}
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: { closed.setValue(true) })
    }
    model.isSubmitting = true
    await model.skipButtonTapped()
    // A skip mid-submit must not flip the action or close the sheet out from under the upload.
    #expect(actions["e1"]?.state == .recorded(localRecordingPath: "/tmp/r.m4a"))
    #expect(!closed.value)
  }

  @Test func uploadedResumeIsReplayableAndSendable() {
    let action = CongratsAction(
      eventId: "e1", stationId: "s1", winnerName: "Jo", prizeName: "P", congratsExpiresAt: nil,
      state: .uploaded(audioBlockId: "ab1", localRecordingPath: "/tmp/r.m4a"), startedAt: Date())
    let model = GiveawayCongratsSheetModel(action: action, onClose: {})
    // Resuming an uploaded action after a kill still offers playback (local file survives) and Send.
    #expect(model.recordingURL?.path == "/tmp/r.m4a")
    #expect(model.canPlay)
    #expect(model.canSend)
    #expect(model.showsReview)
  }

  @Test func recordedResumeLoadsDurationForReview() async {
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock { $0 = ["e1": recordedAction()] }
    let loaded = LockIsolated<URL?>(nil)
    let model = withDependencies {
      $0.audioPlayer.loadFile = { url in loaded.setValue(url) }
      $0.audioPlayer.duration = { 7 }
      $0.stationPlayer = StationPlayerMock()
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    await model.viewAppeared()
    #expect(loaded.value?.path == "/tmp/r.m4a")
    #expect(model.recordingDuration == 7)
  }

  @Test func stopRecordingPreservesSourceExtensionForConverter() async throws {
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock {
      $0 = [
        "e1": CongratsAction(
          eventId: "e1", stationId: "s1", winnerName: nil, prizeName: nil, congratsExpiresAt: nil,
          state: .pending, startedAt: Date())
      ]
    }
    // The live recorder writes Linear PCM into a `.wav` container. A real RIFF/WAVE header mirrors that
    // so the persisted copy is named by its sniffed content, not a trusted extension.
    let source = FileManager.default.temporaryDirectory
      .appendingPathComponent("voicetrack_\(UUID().uuidString).wav")
    // RIFF / WAVE magic bytes.
    try Data([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45]).write(to: source)
    let model = withDependencies {
      $0.audioRecorder.stopRecording = { source }
      $0.audioPlayer.loadFile = { _ in }
      $0.audioPlayer.duration = { 5 }
      $0.stationPlayer = StationPlayerMock()
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    await model.onStopTapped()
    // Renaming WAV bytes to `.m4a` makes AVAssetExportSession fail ("Audio conversion failed") on
    // every Send — the persisted file must keep the recorder's container extension.
    #expect(model.recordingURL?.pathExtension == "wav")
    let persisted = try #require(model.recordingURL)
    #expect(FileManager.default.fileExists(atPath: persisted.path))
    try? FileManager.default.removeItem(at: persisted)
    try? FileManager.default.removeItem(at: source)
  }

  @Test func stopRecordingDetectsRealM4AByMajorBrand() async throws {
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock {
      $0 = [
        "e1": CongratsAction(
          eventId: "e1", stationId: "s1", winnerName: nil, prizeName: nil, congratsExpiresAt: nil,
          state: .pending, startedAt: Date())
      ]
    }
    // A genuine MPEG-4 audio file: `ftyp` box (4-byte size) + the `M4A ` major brand.
    let source = FileManager.default.temporaryDirectory
      .appendingPathComponent("voicetrack_\(UUID().uuidString)")
    try Data([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41, 0x20]).write(to: source)
    let model = withDependencies {
      $0.audioRecorder.stopRecording = { source }
      $0.audioPlayer.loadFile = { _ in }
      $0.audioPlayer.duration = { 5 }
      $0.stationPlayer = StationPlayerMock()
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    await model.onStopTapped()
    #expect(model.recordingURL?.pathExtension == "m4a")
    if let url = model.recordingURL { try? FileManager.default.removeItem(at: url) }
    try? FileManager.default.removeItem(at: source)
  }

  @Test func stopRecordingDoesNotMisclassifyQuickTimeAsM4A() async throws {
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock {
      $0 = [
        "e1": CongratsAction(
          eventId: "e1", stationId: "s1", winnerName: nil, prizeName: nil, congratsExpiresAt: nil,
          state: .pending, startedAt: Date())
      ]
    }
    // A QuickTime MOV also starts with an `ftyp` box, but its `qt  ` brand must not be read as M4A.
    let source = FileManager.default.temporaryDirectory
      .appendingPathComponent("voicetrack_\(UUID().uuidString).mov")
    try Data([0, 0, 0, 0x14, 0x66, 0x74, 0x79, 0x70, 0x71, 0x74, 0x20, 0x20]).write(to: source)
    let model = withDependencies {
      $0.audioRecorder.stopRecording = { source }
      $0.audioPlayer.loadFile = { _ in }
      $0.audioPlayer.duration = { 5 }
      $0.stationPlayer = StationPlayerMock()
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    await model.onStopTapped()
    // Unrecognized container falls back to the source extension — never silently renamed `.m4a`.
    #expect(model.recordingURL?.pathExtension == "mov")
    if let url = model.recordingURL { try? FileManager.default.removeItem(at: url) }
    try? FileManager.default.removeItem(at: source)
  }

  @Test func sendNormalizesStaleMislabeledRecordingBeforeConversion() async throws {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    // A recording persisted by the pre-fix build: WAV bytes inside a `.m4a` file.
    let stale = FileManager.default.temporaryDirectory
      .appendingPathComponent("congrats-\(UUID().uuidString).m4a")
    // RIFF / WAVE magic bytes in a file the pre-fix build mislabeled `.m4a`.
    try Data([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45]).write(to: stale)
    $actions.withLock {
      $0 = [
        "e1": CongratsAction(
          eventId: "e1", stationId: "s1", winnerName: nil, prizeName: nil, congratsExpiresAt: nil,
          state: .recorded(localRecordingPath: stale.path), startedAt: Date())
      ]
    }
    let uploadedExt = LockIsolated<String?>(nil)
    let model = withDependencies {
      $0.voicetrackUploadService.processVoicetrack = { voicetrack, _, _, _ in
        uploadedExt.setValue(voicetrack.originalURL.pathExtension)
        return AudioBlock.mockWith()
      }
      $0.api.recordGiveawayEventCongrats = { _, _, _ in }
      $0.stationPlayer = StationPlayerMock()
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    await model.sendButtonTapped()
    // The converter must receive a file whose extension matches its WAV bytes, not the stale `.m4a`.
    expectNoDifference(uploadedExt.value, "wav")
    if let url = model.recordingURL { try? FileManager.default.removeItem(at: url) }
    try? FileManager.default.removeItem(at: stale)
  }

  @Test func viewAppearedStopsStationPlayback() async {
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock { $0 = ["e1": recordedAction()] }
    let stationPlayer = StationPlayerMock.mockPlayingPlayer()
    let model = withDependencies {
      $0.stationPlayer = stationPlayer
      $0.audioPlayer.loadFile = { _ in }
      $0.audioPlayer.duration = { 5 }
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    await model.viewAppeared()
    // The station must be muted as soon as the congrats sheet appears, for both recording and review.
    expectNoDifference(stationPlayer.stopCalledCount, 1)
  }

  @Test func skipWhileRecordingStopsTheRecorder() async {
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock {
      $0 = [
        "e1": CongratsAction(
          eventId: "e1", stationId: "s1", winnerName: nil, prizeName: nil, congratsExpiresAt: nil,
          state: .pending, startedAt: Date())
      ]
    }
    let stopped = LockIsolated(false)
    let model = withDependencies {
      $0.audioRecorder.requestPermission = { true }
      $0.audioRecorder.startRecording = {}
      $0.audioRecorder.currentTime = { 0 }
      $0.audioRecorder.getAudioLevel = { 0 }
      $0.audioRecorder.stopRecording = {
        stopped.setValue(true)
        return URL(fileURLWithPath: "/tmp/x.m4a")
      }
      $0.audioPlayer.stop = {}
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    await model.onRecordTapped()
    #expect(model.recordingPhase == .recording)
    // Skipping mid-recording must stop the mic, not leave the update loop running.
    await model.skipButtonTapped()
    #expect(stopped.value)
    expectNoDifference(actions["e1"]?.state, CongratsActionState.skipped)
  }
}
