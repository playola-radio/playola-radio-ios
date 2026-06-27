import Foundation

/// Gates the live giveaway data path (feed discovery + reveal timer). Enabled everywhere except
/// production, so it's QA-able on staging while production stays dark — keeping `develop`
/// deployable until the full listener + artist flow ships. Flip to always-on when complete.
enum GiveawayFeature {
  static var isLiveDataEnabled: Bool {
    Config.shared.environment != .production
  }
}
