import Foundation

enum CongratsActionState: Codable, Equatable, Sendable {
  case pending
  case recorded(localRecordingPath: String)
  case uploaded(audioBlockId: String)
  case submitted
  case alreadyClosed
  case skipped
}

struct CongratsAction: Codable, Equatable, Sendable, Identifiable {
  let eventId: String
  let stationId: String
  var winnerName: String?
  var prizeName: String?
  var congratsExpiresAt: Date?
  var state: CongratsActionState
  var startedAt: Date

  var id: String { eventId }

  var audioBlockId: String? {
    if case .uploaded(let audioBlockId) = state { return audioBlockId }
    return nil
  }

  var localRecordingPath: String? {
    if case .recorded(let path) = state { return path }
    return nil
  }

  var isTerminal: Bool {
    switch state {
    case .submitted, .alreadyClosed, .skipped: return true
    case .pending, .recorded, .uploaded: return false
    }
  }

  static var mock: CongratsAction {
    CongratsAction(
      eventId: "event-1", stationId: "station-1", winnerName: "Jo", prizeName: "Two tickets",
      congratsExpiresAt: nil, state: .pending,
      startedAt: Date(timeIntervalSince1970: 1_781_722_800))
  }
}
