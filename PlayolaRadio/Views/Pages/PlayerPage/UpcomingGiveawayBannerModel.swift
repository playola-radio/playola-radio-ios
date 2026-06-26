import Dependencies
import Foundation
import PlayolaPlayer
import Sharing

@MainActor
@Observable
class UpcomingGiveawayBannerModel: ViewModel {

  // MARK: - Shared State
  @ObservationIgnored @Shared(.nowPlaying) var nowPlaying
  @ObservationIgnored @Shared(.activeGiveaway) var activeGiveaway
  @ObservationIgnored @Shared(.upcomingGiveaways) var upcomingGiveaways

  // MARK: - Initialization
  override init() {
    super.init()
  }

  // MARK: - View Helpers

  /// Visible only while the now-playing station has an upcoming giveaway and its contest has not yet
  /// opened. Reading `activeGiveaway` is what lets the banner self-hide the instant the tap overlay
  /// takes over.
  var isVisible: Bool { upcomingGiveaway != nil }

  var bannerOpacity: Double { isVisible ? 1 : 0 }

  /// Deliberately omits any open time — the indicator builds anticipation without revealing when the
  /// contest opens.
  var bannerText: String {
    guard let event = upcomingGiveaway?.event, let stationName = currentStationName else {
      return ""
    }
    return "Win a \(event.prizeName) — coming up on \(stationName)"
  }

  // MARK: - Private Helpers
  private var currentStation: Station? {
    guard let anyStation = nowPlaying?.currentStation,
      case .playola(let station) = anyStation
    else { return nil }
    return station
  }

  private var currentStationName: String? { currentStation?.name }

  private var upcomingGiveaway: UpcomingGiveawayInfo? {
    guard let stationId = currentStation?.id,
      let info = upcomingGiveaways[id: stationId]
    else { return nil }
    if let active = activeGiveaway, active.status == .open, active.stationId == stationId {
      return nil
    }
    return info
  }
}
