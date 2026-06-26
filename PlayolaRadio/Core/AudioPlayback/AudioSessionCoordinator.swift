//
//  AudioSessionCoordinator.swift
//  PlayolaRadio
//
//  The single owner of the process-global AVAudioSession for the whole app.
//

import AVFoundation
import Dependencies
import Foundation

/// Thin seam over `AVAudioSession` so the coordinator is unit-testable.
/// NOT `@MainActor`: `AVAudioSession`'s members are nonisolated; isolation lives
/// on the coordinator, which is the only caller.
protocol AudioSessionProtocol {
  func setCategory(
    _ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
    policy: AVAudioSession.RouteSharingPolicy, options: AVAudioSession.CategoryOptions
  ) throws
  func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

/// Explicit adapter (instead of a retroactive `extension AVAudioSession:
/// AudioSessionProtocol`) so the protocol's signature is the only contract — no
/// surprise if a platform overload differs. One forwarding call each.
struct LiveAudioSession: AudioSessionProtocol {
  func setCategory(
    _ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
    policy: AVAudioSession.RouteSharingPolicy, options: AVAudioSession.CategoryOptions
  ) throws {
    try AVAudioSession.sharedInstance()
      .setCategory(category, mode: mode, policy: policy, options: options)
  }
  func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
    try AVAudioSession.sharedInstance().setActive(active, options: options)
  }
}

/// Inert session for the DI test default (never asserts; the spy lives in test code).
struct NoOpAudioSession: AudioSessionProtocol {
  func setCategory(
    _ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
    policy: AVAudioSession.RouteSharingPolicy, options: AVAudioSession.CategoryOptions
  ) throws {}
  func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {}
}

/// What the coordinator tells its delegate to do when the system interrupts or
/// reroutes audio. `@MainActor` so calls into the SDK's `@MainActor` transport
/// are isolation-correct by construction.
@MainActor
protocol AudioInterruptionDelegate: AnyObject {
  func audioSessionShouldPause()
  func audioSessionShouldResume()
}

/// THE single owner of the process-global `AVAudioSession` for the whole app.
/// The Playola SDK (host-owned, 0.20.0+), the vendored FRadioPlayer, and the
/// recorder all defer to this. Also the single owner of interruption/route
/// policy (see the observer wiring below).
@MainActor
final class AudioSessionCoordinator {
  private let session: AudioSessionProtocol
  weak var delegate: AudioInterruptionDelegate?

  init(session: AudioSessionProtocol = LiveAudioSession()) {
    self.session = session
  }

  // MARK: - Session configuration

  /// Long-form playback (radio). `.longFormAudio` is the AirPlay-2 policy;
  /// `.allowAirPlay` alone is not enough. `options` is empty: `.playback`
  /// already routes Bluetooth A2DP, and adding `.allowBluetooth` /
  /// `.allowBluetoothA2DP` to a `.longFormAudio` category can throw OSStatus
  /// `-50`. Activates the session.
  func configureForPlayback() throws {
    try session.setCategory(
      .playback, mode: .default, policy: .longFormAudio, options: [])
    try session.setActive(true, options: [])
  }

  /// Voicetrack recording. Activates the session.
  func configureForRecording() throws {
    try session.setCategory(
      .playAndRecord, mode: .default, policy: .default,
      options: [.defaultToSpeaker, .allowBluetooth])
    try session.setActive(true, options: [])
  }

  /// Restores the playback category after recording WITHOUT activating —
  /// resuming playback (and therefore activation) is an explicit user/app
  /// decision, not a side effect of stopping a recording.
  func restorePlaybackCategory() throws {
    try session.setCategory(
      .playback, mode: .default, policy: .longFormAudio, options: [])
  }

  func deactivate() throws {
    try session.setActive(false, options: [.notifyOthersOnDeactivation])
  }
}

// `@preconcurrency DependencyKey` on a `@MainActor` class is the app's
// established pattern (StationPlayer, NowPlayingUpdater, URLStreamPlayer, etc.).
extension AudioSessionCoordinator: @preconcurrency DependencyKey {
  static let liveValue = AudioSessionCoordinator()
  static var testValue: AudioSessionCoordinator {
    AudioSessionCoordinator(session: NoOpAudioSession())
  }
}

extension DependencyValues {
  var audioSessionCoordinator: AudioSessionCoordinator {
    get { self[AudioSessionCoordinator.self] }
    set { self[AudioSessionCoordinator.self] = newValue }
  }
}
