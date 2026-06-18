import Foundation

enum GiveawayParticipationStatus: Codable, Equatable, Sendable {
  case tappedStandby(tapNumber: Int)
  case resolvedWon(tapNumber: Int, submissionCompleted: Bool)
  case resolvedLost(tapNumber: Int, toastShown: Bool)
  case canceled
}

struct GiveawayParticipation: Codable, Equatable, Sendable, Identifiable {
  let id: String
  let stationId: String
  let prizeName: String
  var prizeDescription: String?
  var prizeImageUrl: URL?
  let winningNumber: Int
  var tapNumber: Int
  var status: GiveawayParticipationStatus
  var tappedAt: Date
  var winnerSheetPresentedAt: Date?

  var isStandby: Bool {
    if case .tappedStandby = status { return true }
    return false
  }

  var isFullyHandled: Bool {
    switch status {
    case .tappedStandby: return false
    case .resolvedWon(_, let submissionCompleted): return submissionCompleted
    case .resolvedLost(_, let toastShown): return toastShown
    case .canceled: return true
    }
  }
}
