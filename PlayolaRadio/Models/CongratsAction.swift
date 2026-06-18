import Foundation

enum CongratsActionState: Codable, Equatable, Sendable {
  case pending
  case uploaded(audioBlockId: String)
  case submitted
  case alreadyClosed
}

struct CongratsAction: Codable, Equatable, Sendable, Identifiable {
  let giveawayId: String
  let stationId: String
  var state: CongratsActionState
  var startedAt: Date

  var id: String { giveawayId }

  var audioBlockId: String? {
    if case .uploaded(let audioBlockId) = state { return audioBlockId }
    return nil
  }

  var isTerminal: Bool {
    switch state {
    case .submitted, .alreadyClosed: return true
    case .pending, .uploaded: return false
    }
  }

  static var mock: CongratsAction {
    CongratsAction(
      giveawayId: "giveaway-1", stationId: "station-1", state: .pending,
      startedAt: Date(timeIntervalSince1970: 1_781_722_800))
  }
}
