import AVFoundation

/// Ensures the audio session is active before playback begins from a Siri
/// cold-launch, where the normal app-launch path may not have run yet.
@MainActor
struct PlaybackBootstrap {
  func prepareForPlayback() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
  }
}
