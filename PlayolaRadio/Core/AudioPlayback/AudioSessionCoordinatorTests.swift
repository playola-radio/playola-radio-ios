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
}
