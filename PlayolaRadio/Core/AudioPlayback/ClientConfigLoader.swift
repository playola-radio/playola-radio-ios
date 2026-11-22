import Dependencies
import Sharing

/// Refreshes the server-driven renderer flags. Runs on every process launch (not
/// only when the main UI appears) so a background relaunch from the car still
/// picks up a server rollback.
@MainActor
struct ClientConfigLoader {
  @Dependency(\.api) var api
  @Shared(.auth) var auth
  @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled
  @Shared(.sampleBufferRendererAllowed) var sampleBufferRendererAllowed: Bool = true

  func refresh() async {
    guard let jwt = auth.jwt else { return }
    do {
      let config = try await api.getClientConfig(jwt)
      // A response for a stale token must not leak one account's flags into the
      // next session: if the user signed out (or switched accounts) while the
      // request was in flight, drop it — the new session refetches on launch.
      guard auth.jwt == jwt else { return }
      $sampleBufferRendererEnabled.withLock {
        $0 = config.sampleBufferRendererEnabled ?? true
      }
      $sampleBufferRendererAllowed.withLock {
        $0 = config.sampleBufferRendererAllowed ?? true
      }
    } catch {
      // Deliberately quiet: the defaults (sample-buffer renderer, plus any
      // persisted kill-gate) are the correct behavior when the fetch fails —
      // analytics noise would drown real errors.
    }
  }
}
