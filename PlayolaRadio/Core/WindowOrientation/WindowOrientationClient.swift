//
//  WindowOrientationClient.swift
//  PlayolaRadio
//

import Dependencies
import DependenciesMacros
import UIKit

/// Rotates the whole key window, so everything presented inside it (pushed pages, sheets,
/// full-screen covers, alerts, toasts) flips together. The keyboard and status bar live in
/// system windows and are not affected.
@DependencyClient
struct WindowOrientationClient: Sendable {
  var setUpsideDown: @MainActor @Sendable (_ isUpsideDown: Bool) -> Void
}

extension WindowOrientationClient: TestDependencyKey {
  static let testValue = WindowOrientationClient()
}

extension DependencyValues {
  var windowOrientation: WindowOrientationClient {
    get { self[WindowOrientationClient.self] }
    set { self[WindowOrientationClient.self] = newValue }
  }
}

extension WindowOrientationClient: DependencyKey {
  static var liveValue: Self {
    Self(
      setUpsideDown: { isUpsideDown in
        guard let window = UIApplication.shared.keyWindow else { return }
        let transform: CGAffineTransform =
          isUpsideDown ? CGAffineTransform(rotationAngle: .pi) : .identity
        guard window.transform != transform else { return }
        UIView.animate(withDuration: 0.5) {
          window.transform = transform
        }
      }
    )
  }
}
