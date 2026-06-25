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
    } operation: {
      GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
    }
    await model.viewAppeared()
    #expect(loaded.value?.path == "/tmp/r.m4a")
    #expect(model.recordingDuration == 7)
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
