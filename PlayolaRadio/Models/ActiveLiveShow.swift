import Foundation

/// The active AMA live show, persisted on Start Show success so the monitor can be resumed
/// after relaunch (bounded recovery, spec D-D). Cleared on confirmed end.
struct ActiveLiveShow: Codable, Equatable, Sendable {
  let liveShowId: String
  let stationId: String
}
