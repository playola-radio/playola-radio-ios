import Foundation

enum GiveawayParticipationStatus: Codable, Equatable, Sendable {
  case tappedStandby
  case resolvedWon(submissionCompleted: Bool)
  case resolvedLost(toastShown: Bool)
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
    case .resolvedWon(let submissionCompleted): return submissionCompleted
    case .resolvedLost(let toastShown): return toastShown
    case .canceled: return true
    }
  }

  /// True when the user won without hitting the winning number — the last-tapper promotion at close.
  /// A regular Nth-tapper winner always has `tapNumber == winningNumber`, so this isolates the
  /// "surprise upgrade" path that the winner sheet headline acknowledges.
  var wasPromotedWin: Bool {
    guard case .resolvedWon = status else { return false }
    return tapNumber != winningNumber
  }

  static var mock: GiveawayParticipation {
    GiveawayParticipation(
      id: "giveaway-1", stationId: "station-1",
      prizeName: "Two tickets to Reckless Kelly at the Heights",
      winningNumber: 9, tapNumber: 7, status: .tappedStandby,
      tappedAt: Date(timeIntervalSince1970: 1_781_722_800))
  }
}
