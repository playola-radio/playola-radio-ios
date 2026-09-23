import PlayolaPlayer
import SwiftUI

extension AskMeAnythingLivePageModel {

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
