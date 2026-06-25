import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
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
          state: .uploaded(audioBlockId: "ab1"), startedAt: Date())
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

  @Test func skipMarksSkippedAndCloses() {
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock { $0 = ["e1": recordedAction()] }
    var closed = false
    let model = GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: { closed = true })
    model.skipButtonTapped()
    expectNoDifference(actions["e1"]?.state, CongratsActionState.skipped)
    #expect(closed)
  }
}
