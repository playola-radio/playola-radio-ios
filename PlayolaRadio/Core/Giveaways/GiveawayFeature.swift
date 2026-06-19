import Foundation

/// Gates the live giveaway data path (the `/active` poll that populates the player overlay).
///
/// Enabled everywhere except production, so the feature is QA-able on staging while production
/// stays dark — keeping `develop` deployable until the full listener + artist flow ships. Flip
/// this to always-on (or add a server/remote flag) once the feature is complete.
enum GiveawayFeature {
  static var isLiveDataEnabled: Bool {
    Config.shared.environment != .production
  }
}
