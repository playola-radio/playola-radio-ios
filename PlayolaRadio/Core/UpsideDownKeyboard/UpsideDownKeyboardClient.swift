//
//  UpsideDownKeyboardClient.swift
//  PlayolaRadio
//

import Dependencies
import DependenciesMacros

/// Swaps the system keyboard for an in-app one while the app is flipped upside down.
@DependencyClient
struct UpsideDownKeyboardClient: Sendable {
  var start: @MainActor @Sendable () -> Void = {}
  var setUpsideDownModeEnabled: @MainActor @Sendable (_ isEnabled: Bool) -> Void
}

extension UpsideDownKeyboardClient: TestDependencyKey {
  static let testValue = UpsideDownKeyboardClient()
}

extension DependencyValues {
  var upsideDownKeyboard: UpsideDownKeyboardClient {
    get { self[UpsideDownKeyboardClient.self] }
    set { self[UpsideDownKeyboardClient.self] = newValue }
  }
}

@MainActor private let liveController = UpsideDownKeyboardController()

extension UpsideDownKeyboardClient: DependencyKey {
  static var liveValue: Self {
    Self(
      start: { liveController.start() },
      setUpsideDownModeEnabled: { liveController.setUpsideDownModeEnabled($0) }
    )
  }
}
