import Dependencies
import IssueReporting

/// Ensures the audio session is active before playback begins from a Siri
/// cold-launch, where the normal app-launch path may not have run yet. Defers to
/// the single session owner so the policy (`.longFormAudio`) matches the rest of
/// the app and the single-owner invariant holds.
@MainActor
struct PlaybackBootstrap {
  @Dependency(\.audioSessionCoordinator) var audioSessionCoordinator

  func prepareForPlayback() {
    do {
      try audioSessionCoordinator.configureForPlayback()
    } catch {
      reportIssue("PlaybackBootstrap failed to configure the audio session: \(error)")
    }
  }
}
