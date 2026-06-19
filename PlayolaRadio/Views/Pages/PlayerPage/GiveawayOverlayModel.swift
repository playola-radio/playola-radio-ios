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
  var onTap: (@MainActor (GiveawayEvent) async -> Void)?

  // MARK: - Debug
  #if DEBUG
    /// When true, the station-match / status gate is bypassed so the overlay renders for the
    /// injected `activeGiveaway` even without live playback. Debug builds only.
    var debugForceVisible = false
  #endif

  // MARK: - Initialization
  override init() {
    super.init()
  }

  // MARK: - User Actions
  func tapButtonTapped() async {
    guard let giveaway = visibleGiveaway else { return }
    await onTap?(giveaway)
  }

  // MARK: - View Helpers
  var isVisible: Bool { visibleGiveaway != nil }

  var overlayOpacity: Double { isVisible ? 1 : 0 }

  var hasTapped: Bool {
    guard let giveaway = visibleGiveaway else { return false }
    return participations[giveaway.id]?.isStandby ?? false
  }

  var promptOpacity: Double { hasTapped ? 0 : 1 }
  var standbyOpacity: Double { hasTapped ? 1 : 0 }
  var promptInteractive: Bool { isVisible && !hasTapped }
  var standbyInteractive: Bool { isVisible && hasTapped }

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

  var standbyText: String { "STAND BY…" }

  var standbySubtitle: String { "Hang tight — we'll reveal the winner when the song ends." }

  /// Human-readable explanation of the visibility gate, for the debug diagnostics readout.
  /// Mirrors `visibleGiveaway` so the HUD never contradicts what's on screen.
  var gateDiagnostics: String {
    guard let giveaway = activeGiveaway else { return "hidden: no activeGiveaway" }
    if giveaway.status != .open { return "hidden: status is \(giveaway.status.rawValue), not open" }
    #if DEBUG
      if debugForceVisible { return "visible: debug force-visible (station check bypassed)" }
    #endif
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
    guard let giveaway = activeGiveaway, giveaway.status == .open else { return nil }
    #if DEBUG
      if debugForceVisible { return giveaway }
    #endif
    guard giveaway.stationId == currentStationId else { return nil }
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
