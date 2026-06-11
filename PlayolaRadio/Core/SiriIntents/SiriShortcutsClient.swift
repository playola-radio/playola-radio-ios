import AppIntents
import Dependencies
import DependenciesMacros

/// Refreshes the system's App Shortcuts parameter index so Siri/Spotlight
/// per-station suggestions reflect the current station list.
@DependencyClient
struct SiriShortcutsClient: Sendable {
  var refreshSuggestions: @Sendable () -> Void
}

extension SiriShortcutsClient: DependencyKey {
  static let liveValue = Self(
    refreshSuggestions: {
      PlayolaShortcuts.updateAppShortcutParameters()
    }
  )
}

extension SiriShortcutsClient: TestDependencyKey {
  // No-op in tests so the many existing MainContainerModel tests that hit the
  // station-list load path don't trip an unimplemented dependency. Tests that
  // assert the refresh override it with a spy.
  static let testValue = Self(refreshSuggestions: {})
}

extension DependencyValues {
  var siriShortcuts: SiriShortcutsClient {
    get { self[SiriShortcutsClient.self] }
    set { self[SiriShortcutsClient.self] = newValue }
  }
}
