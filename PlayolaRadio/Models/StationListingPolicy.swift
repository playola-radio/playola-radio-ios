import Foundation

extension APIStationItem {
  /// Spec "iOS listing policy": the one place listing/playability is decided.
  func isListed(unlocked: Bool) -> Bool {
    guard anyStationIfPresent != nil else { return false }
    switch visibility {
    case .visible, .comingSoon: return true
    case .hidden: return unlocked
    case .unknown: return false
    }
  }

  func isPlayable(unlocked: Bool) -> Bool {
    guard isListed(unlocked: unlocked), let station = anyStationIfPresent, station.active
    else { return false }
    return visibility == .visible || unlocked
  }
}

extension StationList {
  // Sorts here because StationList's own `sortedItems` is private.
  func listedItems(unlocked: Bool) -> [APIStationItem] {
    (items ?? []).sorted { $0.sortOrder < $1.sortOrder }.filter { $0.isListed(unlocked: unlocked) }
  }
}

extension Collection where Element == StationList {
  /// Surfaces that resolve a station by id (Siri, push, resume) must go through this:
  /// an id absent from every fetched list is not playable.
  func playableItem(stationId: String, unlocked: Bool) -> APIStationItem? {
    lazy.flatMap { $0.listedItems(unlocked: unlocked) }
      .first { $0.anyStationIfPresent?.id == stationId && $0.isPlayable(unlocked: unlocked) }
  }
}
