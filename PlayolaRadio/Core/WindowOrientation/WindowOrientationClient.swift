//
//  WindowOrientationClient.swift
//  PlayolaRadio
//

import Dependencies
import DependenciesMacros
import UIKit

/// Rotates the whole key window, so everything presented inside it (pushed pages, sheets,
/// full-screen covers, alerts, toasts) flips together. The keyboard and status bar live in
/// system windows and are not affected. While rotated, the camera cutout sits at the logical
/// bottom, so the bottom safe area grows to match the top. Returns once the rotation has finished.
@DependencyClient
struct WindowOrientationClient: Sendable {
  var setUpsideDown: @MainActor @Sendable (_ isUpsideDown: Bool) async -> Bool = { _ in false }
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
        guard let window = UIApplication.shared.keyWindow else { return false }
        let transform: CGAffineTransform =
          isUpsideDown ? CGAffineTransform(rotationAngle: .pi) : .identity
        guard window.transform != transform else { return true }
        return await withCheckedContinuation { continuation in
          UIView.animate(withDuration: 0.5) {
            window.transform = transform
            rotatedSafeArea.update(window: window, isUpsideDown: isUpsideDown)
          } completion: { _ in
            continuation.resume(returning: true)
          }
        }
      }
    )
  }
}

private let rotatedSafeArea = RotatedSafeArea()

@MainActor
private final class RotatedSafeArea {
  private var adjustments: [(controller: WeakController, amount: CGFloat)] = []

  nonisolated init() {}

  func update(window: UIWindow, isUpsideDown: Bool) {
    for adjustment in adjustments {
      adjustment.controller.value?.additionalSafeAreaInsets.bottom -= adjustment.amount
    }
    adjustments = []
    guard isUpsideDown else { return }

    let amount = max(0, window.safeAreaInsets.top - window.safeAreaInsets.bottom)
    guard amount > 0 else { return }
    var controller = window.rootViewController
    while let current = controller {
      current.additionalSafeAreaInsets.bottom += amount
      adjustments.append((WeakController(value: current), amount))
      controller = current.presentedViewController
    }
  }
}

private struct WeakController {
  weak var value: UIViewController?
}
