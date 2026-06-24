import Dependencies
import Foundation
import Observation
import Sharing

@MainActor
@Observable
class GiveawayWinnerSheetModel: ViewModel {

  // MARK: - Dependencies
  @ObservationIgnored @Dependency(\.api) var api

  // MARK: - Shared State
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.giveawayParticipations) var participations

  // MARK: - Initialization
  private let participation: GiveawayParticipation
  private let fromPush: Bool
  private let onClose: () -> Void

  init(
    participation: GiveawayParticipation, fromPush: Bool = false, onClose: @escaping () -> Void
  ) {
    self.participation = participation
    self.fromPush = fromPush
    self.onClose = onClose
    super.init()
  }

  // MARK: - Properties
  var fullName = ""
  var addressLine1 = ""
  var addressLine2 = ""
  var city = ""
  var state = ""
  var postalCode = ""
  var comment = ""
  var isSubmitting = false
  var submitErrorMessage: String?
  var showsClaimedConfirmation = false

  // MARK: - View Helpers
  var headline: String {
    participation.wasPromotedWin
      ? "Good news — you got bumped up to the winner!"
      : "You won! You're Listener #\(participation.tapNumber)"
  }

  var prizeName: String { participation.prizeName }
  var prizeDescription: String? { participation.prizeDescription }
  var prizeImageUrl: URL? { participation.prizeImageUrl }

  var claimButtonTitle: String { isSubmitting ? "Submitting…" : "Claim Prize" }
  var claimedTitle: String { "You're all set" }
  var claimedSubtitle: String { "We'll be in touch." }

  var canSubmit: Bool {
    !isSubmitting
      && !fullName.trimmed.isEmpty
      && !addressLine1.trimmed.isEmpty
      && !city.trimmed.isEmpty
      && !state.trimmed.isEmpty
      && !postalCode.trimmed.isEmpty
  }

  // MARK: - User Actions

  /// For a sheet opened from a push / unknown provenance, confirm the prize is still claimable before
  /// showing the form — otherwise we'd prompt to claim a prize already claimed on another device.
  func task() async {
    guard fromPush, let jwt = auth.jwt else { return }
    guard let event = try? await api.giveawayEvent(jwt, participation.id) else { return }
    if event.viewer?.canSubmitMailingInfo == false {
      markSubmissionCompleted()
      showsClaimedConfirmation = true
    }
  }

  func claimButtonTapped() async {
    guard canSubmit, let jwt = auth.jwt else { return }
    isSubmitting = true
    submitErrorMessage = nil
    defer { isSubmitting = false }
    let request = GiveawayWinnerSubmissionRequest(
      fullName: fullName.trimmed, addressLine1: addressLine1.trimmed, city: city.trimmed,
      state: state.trimmed, postalCode: postalCode.trimmed,
      addressLine2: addressLine2.trimmed.isEmpty ? nil : addressLine2.trimmed,
      comment: comment.trimmed.isEmpty ? nil : comment.trimmed)
    do {
      try await api.submitGiveawayWinnerDetails(jwt, participation.id, request)
      markSubmissionCompleted()
      onClose()
    } catch {
      submitErrorMessage = "Something went wrong submitting your info. Please try again."
    }
  }

  func closeButtonTapped() {
    onClose()
  }

  // MARK: - Private Helpers
  private func markSubmissionCompleted() {
    $participations.withLock {
      if $0[participation.id] != nil {
        $0[participation.id]?.status = .resolvedWon(submissionCompleted: true)
      }
    }
  }
}

extension String {
  fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
