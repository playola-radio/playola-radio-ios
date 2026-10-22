//
//  UpsideDownNotificationBannerController.swift
//  PlayolaRadio
//

import SwiftUI
import UIKit

/// While the app window is flipped upside down, system notification banners still appear
/// right-side up because they live in a system window. This draws a copy of the notification in
/// an overlay window with the same rotation as the app, so the caller can suppress the original.
///
/// A copy is only ever shown when upside-down mode is enabled and the app window is actually
/// rotated.
@MainActor
final class UpsideDownNotificationBannerController {
  let bannerModel = UpsideDownNotificationBannerModel()

  private let appWindow: @MainActor () -> UIWindow?
  private var isModeEnabled = false
  private var overlayWindow: BannerOverlayWindow?
  private var bannerTopConstraint: NSLayoutConstraint?

  var isShowingBanner: Bool { overlayWindow?.isHidden == false && bannerModel.banner != nil }

  init(appWindow: @escaping @MainActor () -> UIWindow? = { UIApplication.shared.keyWindow }) {
    self.appWindow = appWindow
  }

  func setUpsideDownModeEnabled(_ isEnabled: Bool) {
    isModeEnabled = isEnabled
    guard !isEnabled else { return }
    bannerModel.hide()
    overlayWindow?.isHidden = true
  }

  /// Returns `false` without showing anything when the app isn't upside down, so the caller
  /// keeps the system banner.
  func showBanner(title: String, body: String, onTap: @escaping @MainActor () -> Void) -> Bool {
    guard isModeEnabled, let window = appWindow(), window.transform.a < 0 else { return false }
    showOverlay(over: window)
    bannerModel.show(title: title, body: body, onTap: onTap)
    return true
  }

  // MARK: - Private Helpers

  private func showOverlay(over window: UIWindow) {
    guard let scene = window.windowScene else { return }
    if overlayWindow?.windowScene !== scene {
      overlayWindow?.isHidden = true
      overlayWindow = makeOverlayWindow(in: scene)
    }
    guard let overlayWindow else { return }
    // Above the app and the upside-down keyboard's overlay window.
    overlayWindow.windowLevel = window.windowLevel + 2
    overlayWindow.transform = window.transform
    // Flipped, the window's bottom safe area (home indicator) is at the app's top edge.
    bannerTopConstraint?.constant = window.safeAreaInsets.bottom + 8
    overlayWindow.isHidden = false
  }

  private func makeOverlayWindow(in scene: UIWindowScene) -> BannerOverlayWindow {
    let overlayWindow = BannerOverlayWindow(windowScene: scene)
    overlayWindow.backgroundColor = .clear
    overlayWindow.bannerModel = bannerModel
    let root = UIViewController()
    root.view.backgroundColor = .clear
    let host = UIHostingController(rootView: UpsideDownNotificationBannerView(model: bannerModel))
    host.safeAreaRegions = []
    host.sizingOptions = .intrinsicContentSize
    host.view.backgroundColor = .clear
    host.view.translatesAutoresizingMaskIntoConstraints = false
    root.addChild(host)
    root.view.addSubview(host.view)
    let top = host.view.topAnchor.constraint(equalTo: root.view.topAnchor)
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: root.view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: root.view.trailingAnchor),
      top,
    ])
    host.didMove(toParent: root)
    overlayWindow.rootViewController = root
    overlayWindow.bannerView = host.view
    bannerTopConstraint = top
    return overlayWindow
  }
}

/// Never takes key status from the app, and only intercepts touches on a showing banner.
private final class BannerOverlayWindow: UIWindow {
  weak var bannerView: UIView?
  weak var bannerModel: UpsideDownNotificationBannerModel?

  override var canBecomeKey: Bool { false }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard bannerModel?.banner != nil, let hit = super.hitTest(point, with: event), let bannerView,
      hit.isDescendant(of: bannerView)
    else { return nil }
    return hit
  }
}
