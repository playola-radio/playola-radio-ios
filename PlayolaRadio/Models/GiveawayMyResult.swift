import Foundation

struct GiveawayMyResult: Decodable, Sendable, Equatable {
  let tapNumber: Int?
  let isWinner: Bool
  let status: GiveawayStatus
  let winningNumber: Int

  init(tapNumber: Int?, isWinner: Bool, status: GiveawayStatus, winningNumber: Int) {
    self.tapNumber = tapNumber
    self.isWinner = isWinner
    self.status = status
    self.winningNumber = winningNumber
  }

  var isResolved: Bool { status == .closed || status == .canceled }

  static var mock: GiveawayMyResult {
    GiveawayMyResult(tapNumber: 9, isWinner: true, status: .closed, winningNumber: 9)
  }
}
