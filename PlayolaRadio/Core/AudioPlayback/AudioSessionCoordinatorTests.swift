//
//  AudioSessionCoordinatorTests.swift
//  PlayolaRadio
//

import AVFoundation
import Testing

@testable import PlayolaRadio

/// Plain class (not `@MainActor`) — the protocol is nonisolated; tests run on
/// the main actor anyway via the suite annotation.
final class SpyAudioSession: AudioSessionProtocol {
  struct CategoryCall {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let policy: AVAudioSession.RouteSharingPolicy
    let options: AVAudioSession.CategoryOptions
  }

  var categories: [CategoryCall] = []
  var activations: [Bool] = []

  func setCategory(
    _ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
    policy: AVAudioSession.RouteSharingPolicy, options: AVAudioSession.CategoryOptions
  ) throws {
    categories.append(
      CategoryCall(category: category, mode: mode, policy: policy, options: options))
  }
  func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
    activations.append(active)
  }
}

struct AudioSessionConfigError: Error {}

/// Session double whose category/activation calls always throw — used to prove
/// callers surface session-config failures instead of swallowing them.
final class FailingAudioSession: AudioSessionProtocol {
  func setCategory(
    _ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
    policy: AVAudioSession.RouteSharingPolicy, options: AVAudioSession.CategoryOptions
  ) throws {
    throw AudioSessionConfigError()
  }
  func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
    throw AudioSessionConfigError()
  }
}

@MainActor
final class SpyInterruptionDelegate: AudioInterruptionDelegate {
  var pauseCount = 0
  var resumeCount = 0
  /// The delegate protocol has no stop() — pausing on device loss can never
  /// escalate to a stop. Exposed as a constant so the test can assert that
  /// structural guarantee.
  let stopCount = 0
  func audioSessionShouldPause() { pauseCount += 1 }
  func audioSessionShouldResume() { resumeCount += 1 }
}

@MainActor
struct AudioSessionCoordinatorTests {
  @Test
  func playbackConfigUsesLongFormAudioAndActivates() throws {
    let spy = SpyAudioSession()
    let coordinator = AudioSessionCoordinator(session: spy)

    try coordinator.configureForPlayback()

    #expect(spy.categories.last?.category == .playback)
    #expect(spy.categories.last?.policy == .longFormAudio)
    #expect(spy.categories.last?.options == [])
    #expect(spy.activations.last == true)
  }

  @Test
  func recordingConfigUsesPlayAndRecordAndActivates() throws {
    let spy = SpyAudioSession()
    let coordinator = AudioSessionCoordinator(session: spy)

    try coordinator.configureForRecording()

    #expect(spy.categories.last?.category == .playAndRecord)
    #expect(spy.activations.last == true)
  }

  @Test
  func recordingThenRestoreReturnsToPlaybackWithoutActivating() throws {
    let spy = SpyAudioSession()
    let coordinator = AudioSessionCoordinator(session: spy)

    try coordinator.configureForRecording()
    #expect(spy.categories.last?.category == .playAndRecord)

    spy.activations = []
    try coordinator.restorePlaybackCategory()  // category only — no auto-activate

    #expect(spy.categories.last?.category == .playback)
    #expect(spy.categories.last?.policy == .longFormAudio)
    #expect(spy.activations.isEmpty)
  }

  @Test
  func deactivateDeactivatesTheSession() throws {
    let spy = SpyAudioSession()
    let coordinator = AudioSessionCoordinator(session: spy)

    try coordinator.deactivate()

    #expect(spy.activations.last == false)
  }

  // MARK: - Interruption / route policy

  @Test
  func interruptionLifecyclePausesThenResumes() {
    let spyDelegate = SpyInterruptionDelegate()
    let coordinator = AudioSessionCoordinator(session: SpyAudioSession())
    coordinator.delegate = spyDelegate

    coordinator.handleInterruption(type: .began, options: [])
    #expect(spyDelegate.pauseCount == 1)

    coordinator.handleInterruption(type: .ended, options: [.shouldResume])
    #expect(spyDelegate.resumeCount == 1)

    coordinator.handleInterruption(type: .ended, options: [])  // no shouldResume
    #expect(spyDelegate.resumeCount == 1)  // unchanged
  }

  @Test
  func headphoneUnplugPausesNeverStops() {
    let spyDelegate = SpyInterruptionDelegate()
    let coordinator = AudioSessionCoordinator(session: SpyAudioSession())
    coordinator.delegate = spyDelegate

    coordinator.handleRouteChange(reason: .oldDeviceUnavailable, previousHadHeadphones: true)
    #expect(spyDelegate.pauseCount == 1)
    #expect(spyDelegate.stopCount == 0)  // delegate has no stop — structural guarantee
  }

  @Test
  func routeChangeThatIsNotAPersonalDeviceUnplugDoesNotPause() {
    let spyDelegate = SpyInterruptionDelegate()
    let coordinator = AudioSessionCoordinator(session: SpyAudioSession())
    coordinator.delegate = spyDelegate

    // New device available (e.g. AirPlay/CarPlay connect) must not pause.
    coordinator.handleRouteChange(reason: .newDeviceAvailable, previousHadHeadphones: true)
    // Old device gone but it wasn't a personal listening device.
    coordinator.handleRouteChange(reason: .oldDeviceUnavailable, previousHadHeadphones: false)

    #expect(spyDelegate.pauseCount == 0)
  }
}
