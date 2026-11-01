//
//  RecordingOrientationClient.swift
//  PlayolaRadio
//

import Dependencies
import DependenciesMacros
import Foundation

/// Rotates the window for a flipped recording. One recording at a time owns the rotation, so a
/// late release from a page that has moved on can't rotate the window back under a newer recording.
@DependencyClient
struct RecordingOrientationClient: Sendable {
  /// Rotates the window upside down. Returns `false` if the rotation was released or reset before
  /// it finished.
  var acquire: @MainActor @Sendable (_ owner: UUID) async -> Bool = { _ in false }
  var release: @MainActor @Sendable (_ owner: UUID) async -> Void
  var isOwner: @MainActor @Sendable (_ owner: UUID) -> Bool = { _ in false }
  /// Returns the window upright whoever owns it (backgrounding, sign-out).
  var forceReset: @MainActor @Sendable () async -> Void
}

extension RecordingOrientationClient: TestDependencyKey {
  static let testValue = RecordingOrientationClient()
}

extension DependencyValues {
  var recordingOrientation: RecordingOrientationClient {
    get { self[RecordingOrientationClient.self] }
    set { self[RecordingOrientationClient.self] = newValue }
  }
}

extension RecordingOrientationClient: DependencyKey {
  static var liveValue: Self {
    let controller = RecordingOrientationController()
    return Self(
      acquire: { await controller.acquire($0) },
      release: { await controller.release($0) },
      isOwner: { controller.isOwner($0) },
      forceReset: { await controller.forceReset() }
    )
  }
}

@MainActor
final class RecordingOrientationController {
  @Dependency(\.windowOrientation) private var windowOrientation
  @Dependency(\.upsideDownKeyboard) private var upsideDownKeyboard
  @Dependency(\.upsideDownNotificationBanner) private var upsideDownNotificationBanner

  private var owner: UUID?
  private var transition = 0

  nonisolated init() {}

  func acquire(_ owner: UUID) async -> Bool {
    self.owner = owner
    transition += 1
    let current = transition
    guard await windowOrientation.setUpsideDown(true) else {
      self.owner = nil
      return false
    }
    guard current == transition else { return false }
    upsideDownKeyboard.setUpsideDownModeEnabled(true)
    upsideDownNotificationBanner.setUpsideDownModeEnabled(true)
    return true
  }

  func release(_ owner: UUID) async {
    guard self.owner == owner else { return }
    await forceReset()
  }

  func isOwner(_ owner: UUID) -> Bool {
    self.owner == owner
  }

  func forceReset() async {
    owner = nil
    transition += 1
    upsideDownKeyboard.setUpsideDownModeEnabled(false)
    upsideDownNotificationBanner.setUpsideDownModeEnabled(false)
    _ = await windowOrientation.setUpsideDown(false)
  }
}
