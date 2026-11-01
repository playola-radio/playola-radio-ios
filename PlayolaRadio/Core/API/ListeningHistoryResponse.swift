import Foundation
import PlayolaPlayer

struct ListeningHistoryResponse: Decodable, Sendable {
  let spins: [ListeningHistorySpin]
  let pagination: Pagination

  var displaySpins: [ListeningHistorySpin] {
    spins.filter { $0.audioBlock != nil && $0.station != nil }
  }

  struct Pagination: Decodable, Sendable {
    let limit: Int
    let offset: Int
    let total: Int
    let hasMore: Bool
  }
}

struct ListeningHistorySpin: Decodable, Sendable, Identifiable {
  let id: String
  let airtime: Date
  let audioBlock: AudioBlock?
  let station: ListeningHistoryStation?
}

struct ListeningHistoryStation: Decodable, Sendable {
  let id: String
  let name: String
}
