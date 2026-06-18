import Foundation

struct GiveawayTapResponse: Decodable, Sendable, Equatable {
  let tapNumber: Int
  let isWinner: Bool
  let status: GiveawayStatus

  static var mock: GiveawayTapResponse {
    GiveawayTapResponse(tapNumber: 5, isWinner: false, status: .open)
  }
}
