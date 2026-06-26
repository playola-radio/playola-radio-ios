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
  /// `shouldAutoResume` is true for an interruption begin (the system may later
  /// tell us to resume via `.shouldResume`) and false for a route loss
  /// (headphone/Bluetooth unplug), where recovery is manual only — we must not
  /// blast audio out of the speaker on the next unrelated `.shouldResume`.
  func audioSessionShouldPause(shouldAutoResume: Bool)
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
    registerObservers()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
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

  // MARK: - Interruption / route policy

  private func registerObservers() {
    NotificationCenter.default.addObserver(
      self, selector: #selector(interruptionNotification(_:)),
      name: AVAudioSession.interruptionNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(routeChangeNotification(_:)),
      name: AVAudioSession.routeChangeNotification, object: nil)
  }

  /// `@objc` entry point. Notifications are delivered on an arbitrary thread, so
  /// this is `nonisolated`. For `.began` we hop to the main actor SYNCHRONOUSLY
  /// so playback is silenced before the app is suspended; `.ended` can hop
  /// asynchronously. (Per Codex review: `assumeIsolated` alone is unsafe here
  /// because the posting thread is not guaranteed to be main.)
  @objc nonisolated private func interruptionNotification(_ note: Notification) {
    guard let info = note.userInfo,
      let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: rawType)
    else { return }
    let options: AVAudioSession.InterruptionOptions
    if let rawOptions = info[AVAudioSessionInterruptionOptionKey] as? UInt {
      options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
    } else {
      options = []
    }

    switch type {
    case .began:
      // AVAudioSession interruption notifications are delivered on the main
      // thread in practice, so the common path pauses synchronously (no engine
      // left running as the app suspends). If a future OS ever posts off-main we
      // hop asynchronously rather than blocking with DispatchQueue.main.sync,
      // which could deadlock if main is waiting on the posting thread.
      if Thread.isMainThread {
        MainActor.assumeIsolated { self.handleInterruption(type: type, options: options) }
      } else {
        Task { @MainActor in self.handleInterruption(type: type, options: options) }
      }
    default:
      Task { @MainActor in self.handleInterruption(type: type, options: options) }
    }
  }

  @objc nonisolated private func routeChangeNotification(_ note: Notification) {
    guard let info = note.userInfo,
      let rawReason = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
      let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason)
    else { return }
    let previousHadHeadphones: Bool
    if let previousRoute = info[AVAudioSessionRouteChangePreviousRouteKey]
      as? AVAudioSessionRouteDescription
    {
      previousHadHeadphones = previousRoute.outputs.contains {
        Self.isPersonalListeningOutput($0.portType)
      }
    } else {
      previousHadHeadphones = false
    }
    Task { @MainActor in
      self.handleRouteChange(reason: reason, previousHadHeadphones: previousHadHeadphones)
    }
  }

  /// Personal listening devices whose disappearance should pause playback.
  /// Excludes CarPlay / AirPlay / built-in speaker — those are not an
  /// "unplugged headphones" event.
  nonisolated private static func isPersonalListeningOutput(_ port: AVAudioSession.Port) -> Bool {
    port == .headphones || port == .bluetoothA2DP || port == .bluetoothHFP
      || port == .bluetoothLE || port == .usbAudio
  }

  /// Testable core for interruptions. The `@objc` wrapper parses the Notification
  /// and calls this on the main actor.
  func handleInterruption(
    type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions
  ) {
    switch type {
    case .began:
      delegate?.audioSessionShouldPause(shouldAutoResume: true)
    case .ended where options.contains(.shouldResume):
      delegate?.audioSessionShouldResume()
    case .ended:
      break  // user resumes manually via the lock screen / app
    @unknown default:
      break
    }
  }

  /// Pause-not-stop on output device loss; the lock-screen play button (remote
  /// command) is the recovery path. Only fires for an unplugged personal
  /// listening device, never for CarPlay/AirPlay/speaker route changes.
  func handleRouteChange(
    reason: AVAudioSession.RouteChangeReason, previousHadHeadphones: Bool
  ) {
    guard reason == .oldDeviceUnavailable, previousHadHeadphones else { return }
    // Route loss: pause but do NOT arm auto-resume (manual recovery only).
    delegate?.audioSessionShouldPause(shouldAutoResume: false)
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
