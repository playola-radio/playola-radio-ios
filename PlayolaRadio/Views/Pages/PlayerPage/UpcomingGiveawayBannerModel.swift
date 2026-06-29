import Dependencies
import Foundation
import PlayolaPlayer
import Sharing

@MainActor
@Observable
class UpcomingGiveawayBannerModel: ViewModel {

  // MARK: - Dependencies
  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Dependency(\.date.now) var currentDate

  // MARK: - Shared State
  @ObservationIgnored @Shared(.nowPlaying) var nowPlaying
  @ObservationIgnored @Shared(.activeGiveaway) var activeGiveaway
  @ObservationIgnored @Shared(.upcomingGiveaways) var upcomingGiveaways

  // MARK: - Initialization
  override init() {
    super.init()
  }

  // MARK: - Properties

  /// Current time, refreshed once a minute by `task()`. `nil` until the view starts the refresh, at
  /// which point the window phrase falls back to `currentDate` so the countdown shows on first paint.
  var now: Date?

  // MARK: - User Actions

  /// Ticks `now` once a minute so the window phrase steps down (~40 → ~35 …) without a
  /// per-second countdown.
  func task() async {
    now = currentDate
    while !Task.isCancelled {
      do { try await clock.sleep(for: .seconds(60)) } catch { break }
      now = currentDate
    }
  }

  // MARK: - View Helpers

  /// Visible only while the now-playing station has an upcoming giveaway and its contest has not yet
  /// opened. Reading `activeGiveaway` is what lets the banner self-hide the instant the tap overlay
  /// takes over.
  var isVisible: Bool { upcomingGiveaway != nil }

  var bannerOpacity: Double { isVisible ? 1 : 0 }

  /// Leads with the prize-show window ("Stay tuned… in the next ~40 minutes") whenever the show
  /// holding the prize is the one currently on air. Otherwise falls back to the timeless invite, which
  /// never reveals when the contest itself opens.
  var bannerText: String {
    guard let event = upcomingGiveaway?.event else { return "" }
    if let windowPhrase {
      return "Stay tuned... we're giving away \(event.prizeName) in the next \(windowPhrase)"
    }
    guard let stationName = currentStationName else { return "" }
    return "\(event.prizeName) — coming up on \(stationName)"
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

  /// End of the show (airing) that holds the prize — but only when that show is the one currently on
  /// air, since that's the only case where the now-playing spin carries its `endTime`.
  private var prizeShowEndTime: Date? {
    guard let airingId = upcomingGiveaway?.event.airingId,
      let airing = nowPlaying?.playolaSpinPlaying?.airing,
      airing.id == airingId
    else { return nil }
    return airing.endTime
  }

  /// The window remaining until the prize show ends, rounded to the nearest 5 minutes. `nil` when the
  /// show end is unknown or already past.
  private var windowPhrase: String? {
    guard let endTime = prizeShowEndTime else { return nil }
    let remaining = endTime.timeIntervalSince(now ?? currentDate)
    guard remaining > 0 else { return nil }
    let roundedMinutes = Int((remaining / 60 / 5).rounded()) * 5
    return roundedMinutes <= 0 ? "few minutes" : "~\(roundedMinutes) minutes"
  }
}
