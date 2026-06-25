import Dependencies
import Foundation
import Sharing

@MainActor
@Observable
class GiveawayOverlayModel: ViewModel {

  // MARK: - Shared State
  @ObservationIgnored @Shared(.nowPlaying) var nowPlaying
  @ObservationIgnored @Shared(.activeGiveaway) var activeGiveaway
  @ObservationIgnored @Shared(.giveawayParticipations) var participations

  // MARK: - Callbacks
  var onTap: (@MainActor (GiveawayEvent) async throws -> Void)?
  var onError: (@MainActor (any Error) async -> Void)?

  // MARK: - Initialization
  override init() {
    super.init()
  }

  // MARK: - User Actions
  func tapButtonTapped() async {
    guard let giveaway = visibleGiveaway else { return }
    do {
      try await onTap?(giveaway)
    } catch {
      await onError?(error)
    }
  }

  // MARK: - View Helpers

  /// The open giveaway is on screen at all only while there is prompt or loser-reveal content to
  /// show. A winner's overlay collapses (the app-wide winner sheet takes over).
  var isVisible: Bool { showsPrompt || showsLoserReveal }

  var overlayOpacity: Double { isVisible ? 1 : 0 }

  /// The user's participation for the on-screen event (keyed by the per-airing event id, NOT
  /// giveawayId — each airing is its own contest).
  private var participation: GiveawayParticipation? {
    guard let giveaway = visibleGiveaway else { return nil }
    return participations[giveaway.id]
  }

  /// Show the tap prompt until the user has tapped this event.
  var showsPrompt: Bool { visibleGiveaway != nil && participation == nil }

  /// Show the consolation reveal once the tap resolved as a (provisional) loss. The win path is an
  /// app-wide sheet, so the overlay shows nothing for a winner.
  var showsLoserReveal: Bool {
    guard visibleGiveaway != nil, case .resolvedLost = participation?.status else { return false }
    return true
  }

  var promptOpacity: Double { showsPrompt ? 1 : 0 }
  var loserRevealOpacity: Double { showsLoserReveal ? 1 : 0 }
  var promptInteractive: Bool { showsPrompt }
  var loserRevealInteractive: Bool { showsLoserReveal }

  var headline: String { "WIN A PRIZE!" }

  var promptPrefix: String { "Be the " }

  var promptOrdinal: String {
    guard let giveaway = visibleGiveaway else { return "" }
    return giveaway.winningNumber.ordinalString
  }

  var promptSuffix: String { " Listener to Tap the Button Below to win:" }

  var prizeText: String {
    guard let giveaway = visibleGiveaway else { return "" }
    return "\(giveaway.prizeName)."
  }

  var buttonTitle: String { "TAP HERE" }

  var loserRevealHeadline: String {
    guard let participation else { return "" }
    return "You were listener #\(participation.tapNumber) — good luck next time!"
  }

  /// Human-readable explanation of the visibility gate, for the debug diagnostics readout.
  /// Mirrors `visibleGiveaway` so the HUD never contradicts what's on screen.
  var gateDiagnostics: String {
    guard let giveaway = activeGiveaway else { return "hidden: no activeGiveaway" }
    if giveaway.status != .open { return "hidden: status is \(giveaway.status.rawValue), not open" }
    if giveaway.stationId != currentStationId {
      return "hidden: giveaway station \(giveaway.stationId) ≠ playing \(currentStationId ?? "nil")"
    }
    return "visible: open giveaway on the current station"
  }

  // MARK: - Private Helpers
  private var currentStationId: String? {
    guard let anyStation = nowPlaying?.currentStation,
      case .playola(let station) = anyStation
    else { return nil }
    return station.id
  }

  private var visibleGiveaway: GiveawayEvent? {
    guard let giveaway = activeGiveaway, giveaway.status == .open,
      giveaway.stationId == currentStationId
    else { return nil }
    return giveaway
  }
}

extension Int {
  fileprivate var ordinalString: String {
    let ones = self % 10
    let tens = self % 100
    if tens >= 11 && tens <= 13 { return "\(self)th" }
    switch ones {
    case 1: return "\(self)st"
    case 2: return "\(self)nd"
    case 3: return "\(self)rd"
    default: return "\(self)th"
    }
  }
}
