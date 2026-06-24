import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct GiveawayWinnerSheetModelTests {
  private func wonParticipation(tapNumber: Int = 9, winningNumber: Int = 9)
    -> GiveawayParticipation
  {
    GiveawayParticipation(
      id: "e", stationId: "s", prizeName: "Two tickets", winningNumber: winningNumber,
      tapNumber: tapNumber, status: .resolvedWon(submissionCompleted: false), tappedAt: Date())
  }

  private func fill(_ model: GiveawayWinnerSheetModel) {
    model.email = "winner@example.com"
  }

  @Test func headlineForNthTapperWin() {
    let model = GiveawayWinnerSheetModel(participation: wonParticipation(tapNumber: 9), onClose: {})
    #expect(model.headline == "You won! You're Listener #9")
  }

  @Test func headlineForPromotedWin() {
    let model = GiveawayWinnerSheetModel(
      participation: wonParticipation(tapNumber: 5, winningNumber: 9), onClose: {})
    #expect(model.headline == "Good news — you got bumped up to the winner!")
  }

  @Test func canSubmitRequiresValidEmail() {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: nil)
    let model = GiveawayWinnerSheetModel(participation: wonParticipation(), onClose: {})
    #expect(model.canSubmit == false)  // empty email
    model.email = "not-an-email"
    #expect(model.canSubmit == false)  // no @
    model.email = "winner@example.com"
    #expect(model.canSubmit == true)
  }

  @Test func prefillsEmailFromAccount() {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(id: "u1", firstName: "Me", email: "me@playola.fm"), jwt: nil)
    let model = GiveawayWinnerSheetModel(participation: wonParticipation(), onClose: {})
    #expect(model.email == "me@playola.fm")
  }

  @Test func claimSuccessMarksSubmissionCompletedAndCloses() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
      "e": wonParticipation()
    ]
    var closed = false
    await withDependencies {
      $0.api.submitGiveawayWinnerDetails = { _, _, _ in }
    } operation: {
      let model = GiveawayWinnerSheetModel(
        participation: participations["e"]!, onClose: { closed = true })
      fill(model)
      await model.claimButtonTapped()
    }
    #expect(
      participations["e"]?.status
        == GiveawayParticipationStatus.resolvedWon(submissionCompleted: true))
    #expect(closed == true)
  }

  @Test func claimFailureKeepsSheetOpenWithError() async {
    struct Boom: Error {}
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
      "e": wonParticipation()
    ]
    var closed = false
    let presentedAlert: PlayolaAlert? = await withDependencies {
      $0.api.submitGiveawayWinnerDetails = { _, _, _ in throw Boom() }
    } operation: {
      let model = GiveawayWinnerSheetModel(
        participation: participations["e"]!, onClose: { closed = true })
      fill(model)
      await model.claimButtonTapped()
      return model.presentedAlert
    }
    #expect(closed == false)
    #expect(presentedAlert != nil)
    #expect(
      participations["e"]?.status
        == GiveawayParticipationStatus.resolvedWon(submissionCompleted: false))
  }

  @Test func pushProvenanceAlreadyClaimedShowsConfirmation() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
      "e": wonParticipation(tapNumber: 5, winningNumber: 9)
    ]
    let showsConfirmation: Bool = await withDependencies {
      $0.api.giveawayEvent = { _, _ in
        GiveawayEvent(
          id: "e", stationId: "s", prizeName: "Two tickets", winningNumber: 9, status: .closed,
          viewer: GiveawayEventViewer(hasTapped: true, isWinner: true, canSubmitMailingInfo: false))
      }
    } operation: {
      let model = GiveawayWinnerSheetModel(
        participation: participations["e"]!, onClose: {})
      await model.task()
      return model.showsClaimedConfirmation
    }
    #expect(showsConfirmation == true)
    #expect(
      participations["e"]?.status
        == GiveawayParticipationStatus.resolvedWon(submissionCompleted: true))
  }
}
