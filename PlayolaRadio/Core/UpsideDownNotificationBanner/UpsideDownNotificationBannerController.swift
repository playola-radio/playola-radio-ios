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
/// rotated and visible in an active scene.
@MainActor
final class UpsideDownNotificationBannerController {
  let bannerModel = UpsideDownNotificationBannerModel()

  private let appWindow: @MainActor () -> UIWindow?
  private let isSceneActive: @MainActor (UIWindowScene) -> Bool
  private var isModeEnabled = false
  private var overlayWindow: BannerOverlayWindow?
  private var bannerTopConstraint: NSLayoutConstraint?

  var isShowingBanner: Bool { overlayWindow?.isHidden == false }

  init(
    appWindow: @escaping @MainActor () -> UIWindow? = { UIApplication.shared.keyWindow },
    isSceneActive: @escaping @MainActor (UIWindowScene) -> Bool = {
      $0.activationState == .foregroundActive
    }
  ) {
    self.appWindow = appWindow
    self.isSceneActive = isSceneActive
    bannerModel.onQueueDrained = { [weak self] in
      self?.overlayWindow?.isHidden = true
    }
  }

  func setUpsideDownModeEnabled(_ isEnabled: Bool) {
    isModeEnabled = isEnabled
    guard bannerModel.banner != nil, let window = appWindow() else { return }
    if isEnabled, window.transform.a < 0, !window.isHidden, let scene = window.windowScene,
      isSceneActive(scene)
    {
      showOverlay(over: window, in: scene)
    } else if !isEnabled {
      overlayWindow?.transform = .identity
      bannerTopConstraint?.constant = window.safeAreaInsets.top + 8
      overlayWindow?.isHidden = false
    }
  }

  /// Returns `false` without showing anything when the app isn't visibly upside down, so the
  /// caller keeps the system banner.
  func showBanner(title: String, body: String, onTap: @escaping @MainActor () -> Void) -> Bool {
    guard isModeEnabled, let window = appWindow(), window.transform.a < 0, !window.isHidden,
      let scene = window.windowScene, isSceneActive(scene)
    else { return false }
    showOverlay(over: window, in: scene)
    bannerModel.show(title: title, body: body, onTap: onTap)
    return true
  }

  // MARK: - Private Helpers

  private func showOverlay(over window: UIWindow, in scene: UIWindowScene) {
    let overlayWindow = currentOverlayWindow(in: scene)
    // Above the app and the upside-down keyboard's overlay window.
    overlayWindow.windowLevel = window.windowLevel + 2
    overlayWindow.transform = window.transform
    // Flipped, the window's bottom safe area (home indicator) is at the app's top edge.
    bannerTopConstraint?.constant = window.safeAreaInsets.bottom + 8
    overlayWindow.isHidden = false
  }

  private func currentOverlayWindow(in scene: UIWindowScene) -> BannerOverlayWindow {
    if let overlayWindow, overlayWindow.windowScene === scene { return overlayWindow }
    overlayWindow?.isHidden = true
    let newOverlayWindow = makeOverlayWindow(in: scene)
    overlayWindow = newOverlayWindow
    return newOverlayWindow
  }

  private func makeOverlayWindow(in scene: UIWindowScene) -> BannerOverlayWindow {
    let overlayWindow = BannerOverlayWindow(windowScene: scene)
    overlayWindow.backgroundColor = .clear
    overlayWindow.bannerModel = bannerModel
    let root = UIViewController()
    root.view.backgroundColor = .clear
    let host = WidthConstrainedHostingController(
      rootView: UpsideDownNotificationBannerView(model: bannerModel))
    host.safeAreaRegions = []
    host.view.backgroundColor = .clear
    host.view.translatesAutoresizingMaskIntoConstraints = false
    root.addChild(host)
    root.view.addSubview(host.view)
    let top = host.view.topAnchor.constraint(equalTo: root.view.topAnchor)
    let height = host.view.heightAnchor.constraint(equalToConstant: 0)
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: root.view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: root.view.trailingAnchor),
      top,
      height,
    ])
    host.heightConstraint = height
    host.didMove(toParent: root)
    overlayWindow.rootViewController = root
    overlayWindow.bannerView = host.view
    bannerTopConstraint = top
    return overlayWindow
  }
}

private final class WidthConstrainedHostingController<Content: View>: UIHostingController<Content> {
  var heightConstraint: NSLayoutConstraint?

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard view.bounds.width > 0 else { return }
    let height = sizeThatFits(
      in: CGSize(width: view.bounds.width, height: .greatestFiniteMagnitude)
    ).height
    if heightConstraint?.constant != height { heightConstraint?.constant = height }
  }
}

/// Never takes key status from the app, and only intercepts touches on a showing banner.
final class BannerOverlayWindow: UIWindow {
  weak var bannerView: UIView?
  weak var bannerModel: UpsideDownNotificationBannerModel?

  override var canBecomeKey: Bool { false }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard bannerModel?.banner != nil, let hit = super.hitTest(point, with: event), let bannerView
    else { return nil }
    let localPoint = bannerView.convert(point, from: self)
    let cardFrame = bannerView.bounds.insetBy(dx: 8, dy: 0)
    guard UIBezierPath(roundedRect: cardFrame, cornerRadius: 18).contains(localPoint),
      hit.isDescendant(of: bannerView)
    else { return nil }
    return hit
  }
}
