import AVFoundation
import IssueReporting

/// Ensures the audio session is active before playback begins from a Siri
/// cold-launch, where the normal app-launch path may not have run yet.
@MainActor
struct PlaybackBootstrap {
  func prepareForPlayback() {
    let session = AVAudioSession.sharedInstance()
    // Best-effort, independent steps: a failed category set must not skip
    // activation, and each failure is reported on its own so a cold-launch
    // silence has a signal instead of being swallowed.
    do {
      try session.setCategory(.playback, mode: .default)
    } catch {
      reportIssue("PlaybackBootstrap failed to set the audio session category: \(error)")
    }
    do {
      try session.setActive(true)
    } catch {
      reportIssue("PlaybackBootstrap failed to activate the audio session: \(error)")
    }
  }
}
