import Dependencies
import Foundation
import Observation
import Sharing
import SwiftUI

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
  private let verifyEligibility: Bool
  private let onClose: () -> Void

  init(
    participation: GiveawayParticipation, verifyEligibility: Bool = true,
    onClose: @escaping () -> Void
  ) {
    self.participation = participation
    self.verifyEligibility = verifyEligibility
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
  var showsClaimedConfirmation = false
  var presentedAlert: PlayolaAlert?

  // MARK: - User Actions

  /// Confirm the prize is still claimable before showing the form — otherwise we'd prompt to claim a
  /// prize already claimed on another device (push / reinstall). Disabled only where the caller has
  /// already proven local provenance. Fails open: if the check can't complete, show the form (a
  /// re-submit upserts server-side, so it's harmless).
  func task() async {
    guard verifyEligibility, let jwt = auth.jwt else { return }
    do {
      let event = try await api.giveawayEvent(jwt, participation.id)
      if event.viewer?.canSubmitMailingInfo == false {
        markSubmissionCompleted()
        showsClaimedConfirmation = true
      }
    } catch {
      // Fail open — leave the form available.
    }
  }

  func claimButtonTapped() async {
    guard canSubmit, let jwt = auth.jwt else { return }
    isSubmitting = true
    presentedAlert = nil
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
      // Keep the sheet open with the form intact so the user can retry (the server upserts).
      presentedAlert = .giveawaySubmissionFailed
    }
  }

  func closeButtonTapped() {
    onClose()
  }

  // MARK: - View Helpers
  var headline: String {
    participation.wasPromotedWin
      ? "Good news — you got bumped up to the winner!"
      : "You won! You're Listener #\(participation.tapNumber)"
  }

  var prizeName: String { participation.prizeName }
  var prizeDescription: String? { participation.prizeDescription }
  var prizeDescriptionText: String { participation.prizeDescription ?? "" }
  var prizeImageUrl: URL? { participation.prizeImageUrl }

  var formInteractive: Bool { !showsClaimedConfirmation }
  var claimedInteractive: Bool { showsClaimedConfirmation }

  var claimButtonTitle: String { isSubmitting ? "Submitting…" : "Claim Prize" }
  var claimedEmoji: String { "🎉" }
  var claimedTitle: String { "You're all set" }
  var claimedSubtitle: String { "We'll be in touch." }
  var closeButtonTitle: String { "Done" }

  // Opacity-driven view swaps (the view stays control-flow-free).
  var formOpacity: Double { showsClaimedConfirmation ? 0 : 1 }
  var claimedOpacity: Double { showsClaimedConfirmation ? 1 : 0 }
  var claimButtonDisabled: Bool { !canSubmit }
  var claimButtonOpacity: Double { canSubmit ? 1 : 0.5 }

  // Field labels / placeholders (all copy lives on the model).
  var fullNameLabel: String { "Full name" }
  var addressLine1Label: String { "Street address" }
  var addressLine1Placeholder: String { "123 Main St" }
  var addressLine2Label: String { "Apt / suite (optional)" }
  var cityLabel: String { "City" }
  var cityPlaceholder: String { "Austin" }
  var stateLabel: String { "State" }
  var statePlaceholder: String { "TX" }
  var postalCodeLabel: String { "ZIP" }
  var postalCodePlaceholder: String { "78701" }

  var canSubmit: Bool {
    !isSubmitting
      && !fullName.trimmed.isEmpty
      && !addressLine1.trimmed.isEmpty
      && !city.trimmed.isEmpty
      && !state.trimmed.isEmpty
      && !postalCode.trimmed.isEmpty
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

extension PlayolaAlert {
  static var giveawaySubmissionFailed: PlayolaAlert {
    PlayolaAlert(
      title: "Submission Failed",
      message:
        "Something went wrong submitting your info. Please check your connection and try again.",
      dismissButton: .cancel(Text("OK")))
  }
}

extension String {
  fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
