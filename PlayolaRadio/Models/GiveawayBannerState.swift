import Foundation

struct GiveawayBannerState: Codable, Equatable, Sendable, Identifiable {
  let giveawayId: String
  let stationId: String

  var id: String { giveawayId }
}
