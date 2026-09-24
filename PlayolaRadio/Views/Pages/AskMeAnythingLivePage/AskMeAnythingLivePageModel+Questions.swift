import PlayolaPlayer
import SwiftUI

/// Distinguishes the recoverable reasons a Q&A can't be added right now from a genuine
/// `CancellationError`, so the answer sub-flow can tell the host what actually happened.
enum AMAAddToShowError: Error, LocalizedError, Equatable {
  /// The show is mid-transition (starting or reconciling its schedule). Retryable.
  case showUpdating
  /// The show the picker was opened against is no longer the one we'd add to (a show
  /// started/ended, or the account changed) — the answer is saved but wasn't added here.
  case destinationChanged

  var errorDescription: String? {
    switch self {
    case .showUpdating:
      return "Couldn\u{2019}t add — your show is updating. Try again in a moment."
    case .destinationChanged:
      return "Your answer was saved, but couldn\u{2019}t be added to this show."
    }
  }
}

extension AskMeAnythingLivePageModel {

  /// Parent-owned seam the answer sub-flow calls once a Q&A is fully resolved. Branches on the
  /// destination captured when the picker opened: a live show airs the grouped spin; a pre-show
  /// setup stages the Q&A into the opening playlist. Distinct `AMAAddToShowError`s let the child
  /// surface the right message instead of a bare cancellation.
  func addQuestionAnswerToShow(
    _ questionAnswer: AMAQuestionAnswer, capturedShowId: String?
  ) async throws {
    if let capturedShowId {
      guard broadcast.liveShowId == capturedShowId else {
        throw AMAAddToShowError.destinationChanged
      }
      try await airQuestion(questionAnswer.questionId)
    } else {
      guard !isStartingShow, !isCheckingSchedule else { throw AMAAddToShowError.showUpdating }
      guard broadcast.liveShowId == nil else { throw AMAAddToShowError.destinationChanged }
      guard auth.currentUser?.id == openingDraftUserId else {
        throw AMAAddToShowError.destinationChanged
      }
      upsertQuestionAnswerOpeningItem(questionAnswer)
    }
  }

  /// Adds the Q&A to the opening playlist, updating the existing row in place when the same
  /// question is re-added (keeping its UUID and position) so a re-open never duplicates it.
  /// Runs with no intervening `await` after the eligibility checks in `addQuestionAnswerToShow`,
  /// so main-actor serialization guarantees a concurrent Start Show can't drop it.
  private func upsertQuestionAnswerOpeningItem(_ questionAnswer: AMAQuestionAnswer) {
    if let existing = openingItems.first(where: {
      $0.content.questionAnswer?.questionId == questionAnswer.questionId
    }) {
      openingItems[id: existing.id]?.content = .questionAnswer(questionAnswer)
    } else {
      openingItems.append(AMAOpeningItem(id: uuid(), content: .questionAnswer(questionAnswer)))
    }
  }

  /// Airs an answered listener question into the live show. Exposed to the question picker/answer
  /// sub-flow as an awaited operation: a missing or replaced show throws `CancellationError` so a
  /// child never believes it aired when it didn't. Serialized against queued-song scheduling via
  /// `isAddingToShow` (which `canAddQuestion` also excludes), so a double-tap or a concurrent song
  /// insert can't air twice.
  func airQuestion(_ questionId: String) async throws {
    guard let showId = broadcast.liveShowId, canAddQuestion else { throw CancellationError() }
    guard let placeAfterSpinId = broadcast.placeAfterSpinIdForShowEnd() else {
      throw CancellationError()
    }

    isAddingToShow = true
    defer { isAddingToShow = false }

    try await broadcast.airListenerQuestion(
      questionId: questionId, placeAfterSpinId: placeAfterSpinId)
    guard broadcast.liveShowId == showId else { throw CancellationError() }

    await refreshListenerQuestionsAfterAiring()
    updateLivePresentation()
  }

  /// Best-effort refresh so `liveRows` can group the freshly aired Q&A pair under the listener's
  /// name. The Q&A has already aired; a failure here only degrades row labeling and must never
  /// re-air.
  private func refreshListenerQuestionsAfterAiring() async {
    guard let jwt = auth.jwt else { return }
    if let refreshed = try? await api.getListenerQuestions(jwt, stationId) {
      listenerQuestions = refreshed
    }
  }
}
