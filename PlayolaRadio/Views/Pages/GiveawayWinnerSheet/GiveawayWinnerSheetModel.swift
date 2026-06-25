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
    self.email = auth.currentUser?.verifiedEmail ?? auth.currentUser?.email ?? ""
  }

  // MARK: - Properties
  var email = ""
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
    let request = GiveawayWinnerSubmissionRequest(preferredEmail: email.trimmed)
    do {
      try await api.submitGiveawayWinnerDetails(jwt, participation.id, request)
      markSubmissionCompleted()
      // Show the confirmation screen (with a Done button) rather than dismissing instantly, so the
      // winner gets a clear "we'll email you" acknowledgement.
      showsClaimedConfirmation = true
    } catch {
      // Keep the sheet open with the field intact so the user can retry (the server upserts).
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

  var deliveryExplanation: String {
    "Confirm your email and we'll be in touch to arrange your prize."
  }

  var emailLabel: String { "Email" }
  var emailPlaceholder: String { "you@example.com" }

  var formInteractive: Bool { !showsClaimedConfirmation }
  var claimedInteractive: Bool { showsClaimedConfirmation }

  var claimButtonTitle: String { isSubmitting ? "Submitting…" : "Claim Prize" }
  var claimedEmoji: String { "🎉" }
  var claimedTitle: String { "Congrats!" }
  var claimedSubtitle: String {
    "We'll send you an email in the next few minutes to arrange your prize. Thanks!"
  }
  var closeButtonTitle: String { "Done" }

  // Opacity-driven view swaps (the view stays control-flow-free).
  var formOpacity: Double { showsClaimedConfirmation ? 0 : 1 }
  var claimedOpacity: Double { showsClaimedConfirmation ? 1 : 0 }
  var claimButtonDisabled: Bool { !canSubmit }
  var claimButtonOpacity: Double { canSubmit ? 1 : 0.5 }

  var canSubmit: Bool {
    guard !isSubmitting else { return false }
    let trimmed = email.trimmed
    return trimmed.contains("@") && !trimmed.hasPrefix("@") && !trimmed.hasSuffix("@")
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
        "Something went wrong confirming your email. Please check your connection and try again.",
      dismissButton: .cancel(Text("OK")))
  }
}

extension String {
  fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
