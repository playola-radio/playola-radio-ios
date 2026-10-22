//
//  UpsideDownNotificationBannerClient.swift
//  PlayolaRadio
//

import Dependencies
import DependenciesMacros

/// Shows Playola notifications in-app, flipped with the app, while the app is upside down.
@DependencyClient
struct UpsideDownNotificationBannerClient: Sendable {
  var setUpsideDownModeEnabled: @MainActor @Sendable (_ isEnabled: Bool) -> Void
  /// Returns whether the copy was shown; when `false` the caller should keep the system banner.
  var showBanner:
    @MainActor @Sendable (
      _ title: String, _ body: String, _ onTap: @escaping @MainActor () -> Void
    ) -> Bool = { _, _, _ in false }
}

extension UpsideDownNotificationBannerClient: TestDependencyKey {
  static let testValue = UpsideDownNotificationBannerClient()
}

extension DependencyValues {
  var upsideDownNotificationBanner: UpsideDownNotificationBannerClient {
    get { self[UpsideDownNotificationBannerClient.self] }
    set { self[UpsideDownNotificationBannerClient.self] = newValue }
  }
}

@MainActor private let liveController = UpsideDownNotificationBannerController()

extension UpsideDownNotificationBannerClient: DependencyKey {
  static var liveValue: Self {
    Self(
      setUpsideDownModeEnabled: { liveController.setUpsideDownModeEnabled($0) },
      showBanner: { liveController.showBanner(title: $0, body: $1, onTap: $2) }
    )
  }
}
