//
//  ClaimSheetModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import IssueReporting
import Observation
import Sharing

struct RewardClaim: Equatable, Sendable {
  let prizeId: String
  let prizeSlug: String?
  let prizeTitle: String?
  let prizeImageUrl: URL?
  let requiredHours: Int

  var isKoozie: Bool { prizeSlug == "koozie" }
}

enum ClaimSheetEntry: Equatable {
  case request(FulfillmentRequest)
  case reward(RewardClaim)
}

enum SendFailure: Equatable {
  case connection
  case invalidAnswers
}

enum ClaimSheetPhase: Equatable {
  case notYetClaimed
  case claiming
  case form
  case sending
  case sendFailed(SendFailure)
  case noLongerOpen
  case nothingToFillIn
  case sent
}

@MainActor
@Observable
class ClaimSheetModel: ViewModel {

  // MARK: - Dependencies
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics

  // MARK: - Shared State
  @ObservationIgnored @Shared(.auth) var auth

  // MARK: - Initialization
  private let rewardClaim: RewardClaim?
  private let source: String
  private let onClaimed: () -> Void
  private let onClose: () -> Void

  init(
    entry: ClaimSheetEntry,
    onClaimed: @escaping () -> Void = {},
    onClose: @escaping () -> Void
  ) {
    self.onClaimed = onClaimed
    self.onClose = onClose
    switch entry {
    case .request(let request):
      rewardClaim = nil
      source = request.source == .giveaway ? "giveaway" : "reward"
      super.init()
      adopt(request)
    case .reward(let claim):
      rewardClaim = claim
      source = claim.isKoozie ? "koozie" : "reward"
      super.init()
    }
  }

  // MARK: - Properties
  var phase: ClaimSheetPhase = .notYetClaimed
  var fields: [ClaimFieldModel] = []
  private(set) var request: FulfillmentRequest?
  @ObservationIgnored private var hasClosed = false

  // MARK: - User Actions
  func viewAppeared() {
    track(.claimSheetShown(source: source))
  }

  func claimItTapped() async {
    guard let rewardClaim, request == nil, canStartClaim else { return }
    guard let jwt = auth.jwt else {
      phase = .sendFailed(.connection)
      return
    }
    phase = .claiming
    do {
      let created = try await api.createRewardRedemption(jwt, rewardClaim.prizeId)
      adopt(created)
      onClaimed()
      await refreshRequests()
    } catch {
      await handleClaimFailure(error)
    }
  }

  func sendTapped() async {
    guard isSendEnabled, let request, let jwt = auth.jwt else { return }
    phase = .sending
    let body = SubmitFulfillmentAnswersRequest(infoAnswers: answeredFields)
    do {
      try await api.submitFulfillmentAnswers(jwt, request.id, body)
      phase = .sent
      await analytics.track(.claimSheetSubmitted(source: source))
    } catch ClaimAPIError.invalidAnswers {
      reportIssue(ClaimAPIError.invalidAnswers)
      phase = .sendFailed(.invalidAnswers)
      await analytics.track(.claimSheetSubmitFailed(source: source, reason: "invalid_answers"))
    } catch ClaimAPIError.notOpen, ClaimAPIError.conflict {
      phase = .noLongerOpen
    } catch {
      phase = .sendFailed(.connection)
      await analytics.track(.claimSheetSubmitFailed(source: source, reason: "connection"))
    }
    await refreshRequests()
  }

  func primaryButtonTapped() async {
    switch phase {
    case .notYetClaimed: await claimItTapped()
    case .form: await sendTapped()
    case .sendFailed: await tryAgainTapped()
    case .noLongerOpen, .nothingToFillIn, .sent: doneTapped()
    case .claiming, .sending: break
    }
  }

  func tryAgainTapped() async {
    if request == nil {
      await claimItTapped()
    } else {
      await sendTapped()
    }
  }

  func laterTapped() {
    guard !hasClosed else { return }
    if isLaterAvailable { track(.claimSheetLater(source: source)) }
    close()
  }

  func doneTapped() {
    close()
  }

  // MARK: - View Helpers
  var headerPill: String {
    isGiveaway ? "YOU WON" : "YOU EARNED"
  }

  var headerPillSymbol: String {
    isGiveaway ? "trophy" : "headphones"
  }

  var prizeTitle: String {
    request?.prizeTitle ?? rewardClaim?.prizeTitle ?? "Your prize"
  }

  var prizeImageUrl: URL? {
    request?.prizeImageUrl ?? rewardClaim?.prizeImageUrl
  }

  var subtitle: String {
    switch phase {
    case .form, .sending, .sendFailed, .claiming:
      return "Tell us a few things so we can get it to you."
    case .notYetClaimed:
      return notYetClaimedSubtitle
    case .noLongerOpen:
      return "This prize has already been shipped or closed, so there's nothing left to fill in."
    case .nothingToFillIn:
      return "Nothing else needed from you — we'll take it from here."
    case .sent:
      return ""
    }
  }

  var sentTitle: String { "You're all set" }

  var sentSubtitle: String { "We'll get your \(prizeTitle) out to you." }

  var primaryButtonTitle: String {
    switch phase {
    case .notYetClaimed: return isKoozie ? "Claim my koozie" : "Claim it"
    case .claiming, .form: return "Send it to me"
    case .sending: return "Sending…"
    case .sendFailed: return "Try again"
    case .noLongerOpen, .nothingToFillIn, .sent: return "Done"
    }
  }

  var isPrimaryButtonEnabled: Bool {
    switch phase {
    case .notYetClaimed, .noLongerOpen, .nothingToFillIn, .sent: return true
    case .form, .sendFailed: return isSendEnabled
    case .claiming, .sending: return false
    }
  }

  var loadingText: String { "Getting your prize ready…" }

  var isPrimaryButtonBusy: Bool {
    phase == .claiming || phase == .sending
  }

  var isPrimaryButtonMuted: Bool {
    switch phase {
    case .form, .sendFailed: return !isSendEnabled
    default: return false
    }
  }

  var prizeImageOpacity: Double {
    phase == .noLongerOpen ? 0.5 : 1
  }

  var laterButtonTitle: String { "I'll finish this later" }

  var isLaterShown: Bool {
    switch phase {
    case .notYetClaimed, .claiming, .form, .sending, .sendFailed: return true
    case .noLongerOpen, .nothingToFillIn, .sent: return false
    }
  }

  var isLaterAvailable: Bool {
    switch phase {
    case .notYetClaimed, .form, .sendFailed: return true
    case .claiming, .sending, .noLongerOpen, .nothingToFillIn, .sent: return false
    }
  }

  var errorText: String {
    switch phase {
    case .sendFailed(.connection):
      return "We couldn't send your answers. Check your connection and try again."
    case .sendFailed(.invalidAnswers):
      return "Some of your answers didn't go through. Check them and try again."
    default:
      return ""
    }
  }

  var incompleteHintText: String? {
    let missing = fields.flatMap(\.missingParts)
    guard missing.isEmpty else { return "Add your \(Self.joined(missing)) to send." }
    return fields.contains(where: \.hasMalformedZip) ? "Enter a 5-digit ZIP code." : nil
  }

  var isSendEnabled: Bool {
    switch phase {
    case .form, .sendFailed: return incompleteHintText == nil
    default: return false
    }
  }

  var isInteractiveDismissDisabled: Bool {
    phase == .claiming || phase == .sending
  }

  var fieldsOpacity: Double {
    phase == .sending ? 0.5 : 1
  }

  var areFieldsEnabled: Bool {
    phase != .sending
  }

  // MARK: - Private Helpers
  private var isGiveaway: Bool {
    request?.source == .giveaway
  }

  private var isKoozie: Bool {
    rewardClaim?.isKoozie ?? false
  }

  private var canStartClaim: Bool {
    switch phase {
    case .notYetClaimed, .sendFailed: return true
    default: return false
    }
  }

  private var notYetClaimedSubtitle: String {
    let hours = rewardClaim?.requiredHours ?? 0
    let listened = "You've listened \(hours) hours on Playola."
    return isKoozie
      ? "\(listened) Claim your free koozie and we'll mail it to you."
      : "\(listened) Claim it and tell us where to send it."
  }

  private var answeredFields: [String: InfoAnswer] {
    fields.reduce(into: [:]) { result, field in
      result[field.field.key] = field.answer
    }
  }

  private func adopt(_ newRequest: FulfillmentRequest) {
    request = newRequest
    fields = newRequest.infoFields.map {
      ClaimFieldModel(field: $0, prefill: newRequest.infoAnswers[$0.key])
    }
    let needsInfo =
      newRequest.status == .awaitingInfo && newRequest.infoFields.contains(where: \.required)
    phase = needsInfo ? .form : .nothingToFillIn
  }

  private func handleClaimFailure(_ error: Error) async {
    switch error as? ClaimAPIError {
    case .conflict:
      onClaimed()
      await refreshRequests()
      close()
    case .notOpen:
      reportIssue(error)
      phase = .noLongerOpen
    case .invalidAnswers:
      reportIssue(error)
      phase = .sendFailed(.connection)
    case .failed, .none:
      phase = .sendFailed(.connection)
    }
  }

  private func close() {
    guard !hasClosed else { return }
    hasClosed = true
    onClose()
  }

  private func refreshRequests() async {
    await withDependencies(from: self) {
      _ in
    } operation: {
      await refreshFulfillmentRequests()
    }
  }

  private func track(_ event: AnalyticsEvent) {
    Task { [analytics] in await analytics.track(event) }
  }

  private static func joined(_ parts: [String]) -> String {
    switch parts.count {
    case 0, 1: return parts.joined()
    case 2: return parts.joined(separator: " and ")
    default:
      return parts.dropLast().joined(separator: ", ") + ", and " + (parts.last ?? "")
    }
  }
}
