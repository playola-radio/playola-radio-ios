//
//  FlipToRecordModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Observation
import SwiftUI

/// Asks the user to flip the phone so they talk into the bottom mic, then rotates the window and
/// counts down before calling the page's own `start`. While recording flipped, holding the phone
/// upright calls the page's own `stop`. The page keeps its idle → recording → review states and
/// calls `recordingStopped()` from every stop path and when it disappears.
@MainActor
@Observable
final class FlipToRecordModel {
  enum Phase: Equatable {
    case idle
    case checkingPose
    case prompting
    case countdown(Int)
    case recordingFlipped
  }

  static let flipHold: Duration = .milliseconds(250)
  static let uprightHold: Duration = .seconds(1)
  static let countdownStart = 3

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder
  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Dependency(\.devicePose) var devicePose
  @ObservationIgnored @Dependency(\.recordingOrientation) var recordingOrientation
  @ObservationIgnored @Dependency(\.uuid) var uuid

  // MARK: - Configuration

  /// Starts the page's recording. Returns whether recording actually began.
  @ObservationIgnored var start: @MainActor () async -> Bool = { false }
  /// Runs the page's guarded stop action.
  @ObservationIgnored var stop: @MainActor () async -> Void = {}

  // MARK: - Initialization

  init() {}

  // MARK: - Properties

  private(set) var phase: Phase = .idle

  @ObservationIgnored private var take = 0
  @ObservationIgnored private var uprightStopTake: Int?
  @ObservationIgnored private var orientationOwner: UUID?
  @ObservationIgnored private var poseTask: Task<Void, Never>?
  @ObservationIgnored private var flipTimer: Task<Void, Never>?
  @ObservationIgnored private var countdownTask: Task<Void, Never>?
  @ObservationIgnored private var uprightTimer: Task<Void, Never>?

  // MARK: - User Actions

  func recordTapped() async {
    guard phase == .idle else { return }
    take += 1
    let current = take
    phase = .checkingPose

    let hasPermission = await audioRecorder.requestPermission()
    guard current == take else { return }
    guard hasPermission else {
      await startUpright(take: current)
      return
    }

    let usesExternalMicrophone = await audioRecorder.usesExternalMicrophone()
    guard current == take else { return }
    guard !usesExternalMicrophone else {
      await startUpright(take: current)
      return
    }

    watchPose()
  }

  func recordWithoutFlippingTapped() async {
    guard phase == .prompting else { return }
    await recordingStopped()
    phase = .checkingPose
    await startUpright(take: take)
  }

  func cancelTapped() async {
    await recordingStopped()
  }

  /// A recording already underway keeps going in the background; anything before it is dropped.
  func scenePhaseChanged(newPhase: ScenePhase) async {
    guard newPhase == .background, phase != .recordingFlipped else { return }
    await recordingStopped()
  }

  /// Called by the page at the top of every stop path and when the page disappears.
  func recordingStopped() async {
    take += 1
    for task in [poseTask, flipTimer, countdownTask, uprightTimer] {
      task?.cancel()
    }
    poseTask = nil
    flipTimer = nil
    countdownTask = nil
    uprightTimer = nil
    phase = .idle
    guard let owner = orientationOwner else { return }
    orientationOwner = nil
    Task { [recordingOrientation] in
      await recordingOrientation.release(owner)
    }
  }

  // MARK: - View Helpers

  var promptTitle: String { "Flip your phone over" }
  var promptBody: String {
    "Talk into the bottom, like a microphone. Recording starts after a 3‑second countdown."
  }
  var waitingLabel: String { "Waiting for you to flip…" }
  var recordWithoutFlippingTitle: String { "Record without flipping" }
  var cancelTitle: String { "Cancel" }
  var countdownLabel: String { "Recording in" }
  var countdownCancelHint: String { "Turn your phone back over to cancel." }
  var uprightHint: String { "Turn your phone upright to stop" }

  var countdownNumber: String {
    guard case .countdown(let remaining) = phase else { return "" }
    return "\(remaining)"
  }

  var isPromptVisible: Bool { phase == .prompting }

  var isCountdownVisible: Bool {
    guard case .countdown = phase else { return false }
    return true
  }

  var isUprightHintVisible: Bool { phase == .recordingFlipped }

  var blocksUnderlyingAccessibility: Bool { isPromptVisible || isCountdownVisible }

  var promptOpacity: Double { isPromptVisible ? 1 : 0 }
  var countdownOpacity: Double { isCountdownVisible ? 1 : 0 }
  var uprightHintOpacity: Double { isUprightHintVisible ? 1 : 0 }

  // MARK: - Private Helpers

  private func startUpright(take current: Int) async {
    _ = await start()
    guard current == take else { return }
    phase = .idle
  }

  private func watchPose() {
    let updates = devicePose.updates()
    poseTask = Task { [weak self] in
      for await pose in updates {
        self?.poseChanged(pose)
      }
      guard !Task.isCancelled else { return }
      self?.poseStreamEnded()
    }
  }

  private func poseStreamEnded() {
    guard phase == .checkingPose else { return }
    phase = .prompting
  }

  private func poseChanged(_ pose: DevicePose) {
    switch phase {
    case .idle:
      return
    case .checkingPose, .prompting:
      waitingForFlipPoseChanged(pose)
    case .countdown:
      guard pose == .upright else { return }
      cancelCountdown()
    case .recordingFlipped:
      recordingFlippedPoseChanged(pose)
    }
  }

  private func waitingForFlipPoseChanged(_ pose: DevicePose) {
    guard pose == .upsideDown else {
      flipTimer?.cancel()
      flipTimer = nil
      phase = .prompting
      return
    }
    guard flipTimer == nil else { return }
    let current = take
    flipTimer = Task { [weak self, clock] in
      guard (try? await clock.sleep(for: Self.flipHold)) != nil else { return }
      self?.flipHeld(take: current)
    }
  }

  private func recordingFlippedPoseChanged(_ pose: DevicePose) {
    switch pose {
    case .upright:
      guard uprightTimer == nil else { return }
      uprightTimer = Task { [weak self, clock] in
        guard (try? await clock.sleep(for: Self.uprightHold)) != nil else { return }
        await self?.uprightHeld()
      }
    case .upsideDown:
      uprightTimer?.cancel()
      uprightTimer = nil
    case .indeterminate:
      return
    }
  }

  private func flipHeld(take current: Int) {
    guard current == take, phase == .checkingPose || phase == .prompting else { return }
    flipTimer = nil
    let owner = uuid()
    orientationOwner = owner
    phase = .countdown(Self.countdownStart)
    countdownTask = Task { [weak self] in
      await self?.runCountdown(owner: owner)
    }
  }

  private func runCountdown(owner: UUID) async {
    guard !Task.isCancelled else { return }
    let acquired = await recordingOrientation.acquire(owner)
    guard !Task.isCancelled else {
      await recordingOrientation.release(owner)
      return
    }
    guard acquired else {
      await recordingStopped()
      return
    }
    for remaining in stride(from: Self.countdownStart, through: 1, by: -1) {
      phase = .countdown(remaining)
      guard (try? await clock.sleep(for: .seconds(1))) != nil, !Task.isCancelled else { return }
      guard recordingOrientation.isOwner(owner) else {
        await recordingStopped()
        return
      }
    }

    countdownTask = nil
    phase = .recordingFlipped
    let current = take
    let started = await start()
    if started, current != take, uprightStopTake == current {
      await stop()
    } else if current == take, !started {
      await recordingStopped()
    }
  }

  private func cancelCountdown() {
    countdownTask?.cancel()
    countdownTask = nil
    phase = .prompting
    guard let owner = orientationOwner else { return }
    orientationOwner = nil
    Task { await recordingOrientation.release(owner) }
  }

  private func uprightHeld() async {
    uprightTimer = nil
    guard phase == .recordingFlipped else { return }
    uprightStopTake = take
    await stop()
  }
}
