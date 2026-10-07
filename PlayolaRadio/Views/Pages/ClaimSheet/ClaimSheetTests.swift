//
//  ClaimSheetTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ClaimSheetTests {
  private struct UnreadableResponse: Error {}

  private let fullAddress: InfoAnswer = .address(
    ShippingAddress(
      fullName: "Jane", addressLine1: "1 Main", addressLine2: nil, city: "Austin", state: "TX",
      postalCode: "78701"))
  private let koozie = RewardClaim(
    prizeId: "prize-1", prizeSlug: "koozie", prizeTitle: "Playola Koozie", prizeImageUrl: nil,
    requiredHours: 50)

  private func makeSendableModel(
    submit:
      @escaping @Sendable (String, String, SubmitFulfillmentAnswersRequest) async throws ->
      Void
  ) -> ClaimSheetModel {
    withDependencies {
      $0.api.submitFulfillmentAnswers = submit
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      ClaimSheetModel(
        entry: .request(.mock(infoAnswers: ["shippingAddress": fullAddress])), onClose: {})
    }
  }

  @Test func testRequestWithRequiredFieldsOpensForm() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    #expect(model.phase == .form)
  }

  @Test func testRequestWithNoRequiredFieldsShowsNothingToFillIn() {
    let model = ClaimSheetModel(entry: .request(.mock(infoFields: [])), onClose: {})
    #expect(model.phase == .nothingToFillIn)
  }

  @Test func testSendPutsOnlyAnsweredFields() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let sent = LockIsolated<SubmitFulfillmentAnswersRequest?>(nil)
    let request = FulfillmentRequest.mock(
      infoFields: [
        InfoField(
          key: "addr", label: "Shipping address", type: .address, options: [], required: true),
        InfoField(
          key: "note", label: "Name to sign it to", type: .shortText, options: [], required: false),
      ], infoAnswers: ["addr": fullAddress])
    let model = withDependencies {
      $0.api.submitFulfillmentAnswers = { _, _, body in sent.setValue(body) }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      ClaimSheetModel(entry: .request(request), onClose: {})
    }
    await model.sendTapped()
    expectNoDifference(
      sent.value, SubmitFulfillmentAnswersRequest(infoAnswers: ["addr": fullAddress]))
    #expect(model.phase == .sent)
  }

  @Test func testSendRefetchesList() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.fulfillmentRequests) var requests = [FulfillmentRequest.mock()]
    let model = makeSendableModel { _, _, _ in }
    await model.sendTapped()
    expectNoDifference(requests, [])
  }

  @Test(arguments: [
    (ClaimAPIError.failed, ClaimSheetPhase.sendFailed(.connection)),
    (.notOpen, .noLongerOpen),
    (.conflict, .noLongerOpen),
  ])
  func testSendFailureMapsToPhase(error: ClaimAPIError, expected: ClaimSheetPhase) async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let model = makeSendableModel { _, _, _ in throw error }
    await model.sendTapped()
    #expect(model.phase == expected)
  }

  @Test func testSendInvalidAnswersShowsInvalidAnswersAndReportsIssue() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let model = makeSendableModel { _, _, _ in throw ClaimAPIError.invalidAnswers }
    await withKnownIssue { await model.sendTapped() }
    #expect(model.phase == .sendFailed(.invalidAnswers))
  }

  @Test func testSendUnexpectedErrorShowsConnectionFailure() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let model = makeSendableModel { _, _, _ in throw UnreadableResponse() }
    await model.sendTapped()
    #expect(model.phase == .sendFailed(.connection))
  }

  @Test func testSendFailedKeepsAnswers() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let model = makeSendableModel { _, _, _ in throw ClaimAPIError.failed }
    await model.sendTapped()
    #expect(model.fields.first?.answer == fullAddress)
  }

  @Test func testSendDisabledWhileIncomplete() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    #expect(!model.isSendEnabled)
    #expect(
      model.incompleteHintText == "Add your name, street address, city, state, and ZIP to send.")
  }

  @Test func testIncompleteHintNamesMissingParts() {
    let noZip = ShippingAddress(
      fullName: "Jane", addressLine1: "1 Main", addressLine2: nil, city: "Austin", state: "TX",
      postalCode: "")
    let model = ClaimSheetModel(
      entry: .request(
        .mock(
          infoFields: [
            InfoField(
              key: "addr", label: "Shipping address", type: .address, options: [], required: true),
            InfoField(
              key: "size", label: "Shirt size", type: .singleChoice, options: ["S", "M"],
              required: true),
          ], infoAnswers: ["addr": .address(noZip)])),
      onClose: {})
    #expect(model.incompleteHintText == "Add your ZIP and shirt size to send.")
  }

  @Test func testIncompleteHintForMalformedZip() {
    let badZip = InfoAnswer.address(
      ShippingAddress(
        fullName: "Jane", addressLine1: "1 Main", addressLine2: nil, city: "Austin", state: "TX",
        postalCode: "7870"))
    let model = ClaimSheetModel(
      entry: .request(.mock(infoAnswers: ["shippingAddress": badZip])), onClose: {})
    #expect(model.incompleteHintText == "Enter a 5-digit ZIP code.")
    #expect(!model.isSendEnabled)
  }

  @Test func testCompleteFormHasNoHint() {
    let model = ClaimSheetModel(
      entry: .request(.mock(infoAnswers: ["shippingAddress": fullAddress])), onClose: {})
    #expect(model.incompleteHintText == nil)
    #expect(model.isSendEnabled)
  }

  @Test func testRewardEntryStartsNotYetClaimed() {
    let model = ClaimSheetModel(entry: .reward(koozie), onClose: {})
    #expect(model.phase == .notYetClaimed)
    #expect(model.primaryButtonTitle == "Claim my koozie")
  }

  @Test func testNonKoozieSlugGetsGenericClaimCopy() {
    let claim = RewardClaim(
      prizeId: "prize-2", prizeSlug: "tote-bag", prizeTitle: "Koozie-ish tote", prizeImageUrl: nil,
      requiredHours: 100)
    let model = ClaimSheetModel(entry: .reward(claim), onClose: {})
    #expect(model.primaryButtonTitle == "Claim it")
    #expect(
      model.subtitle
        == "You've listened 100 hours on Playola. Claim it and tell us where to send it.")
  }

  @Test func testClaimItMovesToReturnedFormAndReportsClaim() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let claimed = LockIsolated(false)
    let model = withDependencies {
      $0.api.createRewardRedemption = { _, _ in .mock(source: .reward, giveawayEventId: nil) }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      ClaimSheetModel(entry: .reward(koozie), onClaimed: { claimed.setValue(true) }, onClose: {})
    }
    await model.claimItTapped()
    #expect(model.phase == .form)
    #expect(claimed.value)
  }

  @Test func testClaimItReadyToShipShowsNothingToFillIn() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let model = withDependencies {
      $0.api.createRewardRedemption = { _, _ in
        .mock(status: .readyToShip, source: .reward, giveawayEventId: nil, infoFields: [])
      }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      ClaimSheetModel(entry: .reward(koozie), onClose: {})
    }
    await model.claimItTapped()
    #expect(model.phase == .nothingToFillIn)
  }

  @Test func testRewardConflictCountsAsClaimed() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.fulfillmentRequests) var requests = []
    let claimed = LockIsolated(false)
    let closed = LockIsolated(false)
    let model = withDependencies {
      $0.api.createRewardRedemption = { _, _ in throw ClaimAPIError.conflict }
      $0.api.getMyFulfillmentRequests = { _ in [.mock(source: .reward, giveawayEventId: nil)] }
    } operation: {
      ClaimSheetModel(
        entry: .reward(koozie), onClaimed: { claimed.setValue(true) },
        onClose: { closed.setValue(true) })
    }
    await model.claimItTapped()
    #expect(claimed.value)
    #expect(closed.value)
    #expect(requests.count == 1)
  }

  @Test func testRewardNotOpenShowsNoLongerOpenAndReportsIssue() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let model = withDependencies {
      $0.api.createRewardRedemption = { _, _ in throw ClaimAPIError.notOpen }
    } operation: {
      ClaimSheetModel(entry: .reward(koozie), onClose: {})
    }
    await withKnownIssue { await model.claimItTapped() }
    #expect(model.phase == .noLongerOpen)
  }

  @Test func testRewardUnexpectedErrorShowsConnectionFailure() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let model = withDependencies {
      $0.api.createRewardRedemption = { _, _ in throw UnreadableResponse() }
    } operation: {
      ClaimSheetModel(entry: .reward(koozie), onClose: {})
    }
    await model.claimItTapped()
    #expect(model.phase == .sendFailed(.connection))
  }

  @Test func testRewardFailureShowsSendFailedAndRetries() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let attempts = LockIsolated(0)
    let model = withDependencies {
      $0.api.createRewardRedemption = { _, _ in
        attempts.withValue { $0 += 1 }
        throw ClaimAPIError.failed
      }
    } operation: {
      ClaimSheetModel(entry: .reward(koozie), onClose: {})
    }
    await model.claimItTapped()
    #expect(model.phase == .sendFailed(.connection))
    await model.tryAgainTapped()
    #expect(attempts.value == 2)
  }

  @Test func testSwipeDismissDisabledOnlyWhileInFlight() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    #expect(!model.isInteractiveDismissDisabled)
    model.phase = .sending
    #expect(model.isInteractiveDismissDisabled)
    model.phase = .claiming
    #expect(model.isInteractiveDismissDisabled)
  }

  @Test func testNilTitleFallsBack() {
    let model = ClaimSheetModel(entry: .request(.mock(prizeTitle: nil)), onClose: {})
    #expect(model.prizeTitle == "Your prize")
  }

  @Test func testSuccessfulSendTracksSubmitted() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let events = LockIsolated<[AnalyticsEvent]>([])
    let model = withDependencies {
      $0.analytics.track = { event in events.withValue { $0.append(event) } }
      $0.api.submitFulfillmentAnswers = { _, _, _ in }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      ClaimSheetModel(
        entry: .request(.mock(infoAnswers: ["shippingAddress": fullAddress])), onClose: {})
    }
    await model.sendTapped()
    expectNoDifference(events.value, [.claimSheetSubmitted(source: "giveaway")])
  }

  @Test func testConnectionFailureTracksSubmitFailed() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let events = LockIsolated<[AnalyticsEvent]>([])
    let model = withDependencies {
      $0.analytics.track = { event in events.withValue { $0.append(event) } }
      $0.api.submitFulfillmentAnswers = { _, _, _ in throw ClaimAPIError.failed }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      ClaimSheetModel(
        entry: .request(.mock(infoAnswers: ["shippingAddress": fullAddress])), onClose: {})
    }
    await model.sendTapped()
    expectNoDifference(
      events.value, [.claimSheetSubmitFailed(source: "giveaway", reason: "connection")])
  }

  @Test func testLaterTappedTwiceClosesOnce() {
    let closes = LockIsolated(0)
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: { closes.withValue { $0 += 1 } })
    model.laterTapped()
    model.laterTapped()
    #expect(closes.value == 1)
  }

  @Test func testDoneThenLaterClosesOnce() {
    let closes = LockIsolated(0)
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: { closes.withValue { $0 += 1 } })
    model.doneTapped()
    model.laterTapped()
    #expect(closes.value == 1)
  }

  @Test func testLaterTappedAfterSentStillCloses() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let closes = LockIsolated(0)
    let model = withDependencies {
      $0.api.submitFulfillmentAnswers = { _, _, _ in }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      ClaimSheetModel(
        entry: .request(.mock(infoAnswers: ["shippingAddress": fullAddress])),
        onClose: { closes.withValue { $0 += 1 } })
    }
    await model.sendTapped()
    #expect(!model.isLaterAvailable)
    model.laterTapped()
    #expect(closes.value == 1)
  }

  @Test func testConcurrentSendsCallApiOnce() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let calls = LockIsolated(0)
    let model = makeSendableModel { _, _, _ in calls.withValue { $0 += 1 } }
    async let first: Void = model.sendTapped()
    async let second: Void = model.sendTapped()
    _ = await (first, second)
    #expect(calls.value == 1)
  }

  @Test func testSendWhileSendingMakesNoApiCall() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let calls = LockIsolated(0)
    let model = makeSendableModel { _, _, _ in calls.withValue { $0 += 1 } }
    model.phase = .sending
    await model.sendTapped()
    #expect(calls.value == 0)
  }

  @Test func testPrimaryButtonTappedOnDoneStatesCloses() async {
    let closes = LockIsolated(0)
    let model = ClaimSheetModel(
      entry: .request(.mock(infoFields: [])), onClose: { closes.withValue { $0 += 1 } })
    #expect(model.phase == .nothingToFillIn)
    await model.primaryButtonTapped()
    #expect(closes.value == 1)
  }

  @Test func testPrimaryButtonTappedOnFormSends() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let model = makeSendableModel { _, _, _ in }
    await model.primaryButtonTapped()
    #expect(model.phase == .sent)
  }

  @Test func testPrimaryButtonTappedOnSendFailedRetriesSend() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let attempts = LockIsolated(0)
    let model = makeSendableModel { _, _, _ in
      attempts.withValue { $0 += 1 }
      if attempts.value == 1 { throw ClaimAPIError.failed }
    }
    await model.primaryButtonTapped()
    #expect(model.phase == .sendFailed(.connection))
    await model.primaryButtonTapped()
    #expect(model.phase == .sent)
  }

  @Test func testPrimaryButtonDisabledWhileInFlightOrIncomplete() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    #expect(!model.isPrimaryButtonEnabled)
    model.phase = .sending
    #expect(!model.isPrimaryButtonEnabled)
    model.phase = .claiming
    #expect(!model.isPrimaryButtonEnabled)
    model.phase = .noLongerOpen
    #expect(model.isPrimaryButtonEnabled)
  }

  @Test func testHeaderPillSymbolMatchesSource() {
    let giveaway = ClaimSheetModel(entry: .request(.mock(source: .giveaway)), onClose: {})
    let reward = ClaimSheetModel(entry: .reward(koozie), onClose: {})
    #expect(giveaway.headerPillSymbol == "trophy")
    #expect(reward.headerPillSymbol == "headphones")
  }

  @Test func testButtonStatesPerPhase() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    #expect(model.isPrimaryButtonMuted)
    #expect(!model.isPrimaryButtonBusy)
    model.phase = .sending
    #expect(model.isPrimaryButtonBusy)
    #expect(!model.isPrimaryButtonMuted)
    model.phase = .claiming
    #expect(!model.isPrimaryButtonBusy)
    model.phase = .sent
    #expect(!model.isLaterShown)
    model.phase = .sending
    #expect(model.isLaterShown)
    #expect(!model.isLaterAvailable)
  }

  @Test func testClaimingPhaseHidesPrimaryButtonAndSubtitle() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    #expect(model.isPrimaryButtonShown)
    #expect(model.isSubtitleShown)
    model.phase = .claiming
    #expect(!model.isPrimaryButtonShown)
    #expect(!model.isSubtitleShown)
    #expect(model.loadingText == "Getting your prize ready…")
  }

  @Test func testLaterIsDimmedOnlyWhileSending() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    model.phase = .claiming
    #expect(model.isLaterShown)
    #expect(!model.isLaterAvailable)
    #expect(model.laterButtonOpacity == 1)
    model.phase = .sending
    #expect(model.laterButtonOpacity == 0.35)
    model.phase = .form
    #expect(model.laterButtonOpacity == 1)
  }

  @Test func testFieldsDimWhileSending() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    #expect(model.fieldsOpacity == 1)
    model.phase = .sending
    #expect(model.fieldsOpacity == 0.45)
  }

  @Test func testHeaderPillHiddenWhenNoLongerOpen() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    #expect(model.isHeaderPillShown)
    model.phase = .noLongerOpen
    #expect(!model.isHeaderPillShown)
  }

  @Test func testPrizeImageDimsWhenNoLongerOpen() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    #expect(model.prizeImageOpacity == 1)
    model.phase = .noLongerOpen
    #expect(model.prizeImageOpacity == 0.5)
  }
}
