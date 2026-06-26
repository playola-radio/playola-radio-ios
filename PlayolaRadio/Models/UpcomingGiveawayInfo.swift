import Foundation

/// A per-station projection of the soonest upcoming (`.scheduled`) giveaway, used to drive the
/// "coming up" badge (station list / Home) and the player banner. Keyed by `stationId` — NOT the
/// per-airing event id — so consumers can look it up the same way they look up `LiveStationInfo`.
struct UpcomingGiveawayInfo: Equatable, Identifiable, Sendable {
  let stationId: String
  let event: GiveawayEvent

  var id: String { stationId }
}
