//
//  UpsideDownNotificationBannerControllerTests.swift
//  PlayolaRadio
//

import CustomDump
import Dependencies
import Testing
import UIKit

@testable import PlayolaRadio

@Suite(.serialized, .freshSharedState)
@MainActor
struct UpsideDownBannerControllerTests {
  struct Visibility: Equatable {
    let isModeEnabled: Bool
    let isWindowUpsideDown: Bool
  }

  @Test
  func testBannerShowsOnlyWhenModeEnabledAndWindowFlipped() throws {
    var shownStates: [Visibility] = []
    var acceptedStates: [Visibility] = []

    for isModeEnabled in [false, true] {
      for isWindowUpsideDown in [false, true] {
        let window = try makeWindow()
        window.transform = isWindowUpsideDown ? upsideDown : .identity
        let controller = makeController(appWindow: window)
        controller.setUpsideDownModeEnabled(isModeEnabled)

        let accepted = controller.showBanner(title: "New message", body: "Hi", onTap: {})

        let visibility = Visibility(
          isModeEnabled: isModeEnabled, isWindowUpsideDown: isWindowUpsideDown)
        if accepted { acceptedStates.append(visibility) }
        if controller.isShowingBanner { shownStates.append(visibility) }
        controller.setUpsideDownModeEnabled(false)
      }
    }

    let onlyVisibleState = [Visibility(isModeEnabled: true, isWindowUpsideDown: true)]
    expectNoDifference(acceptedStates, onlyVisibleState)
    expectNoDifference(shownStates, onlyVisibleState)
  }

  @Test
  func testDisablingModeKeepsSuppressedBannersUntilTheyDrain() throws {
    let window = try makeWindow()
    window.transform = upsideDown
    let controller = makeController(appWindow: window)
    controller.setUpsideDownModeEnabled(true)
    _ = controller.showBanner(title: "First", body: "", onTap: {})
    _ = controller.showBanner(title: "Second", body: "", onTap: {})

    window.transform = .identity
    controller.setUpsideDownModeEnabled(false)

    expectNoDifference(controller.bannerModel.banner?.title, "First")
    #expect(controller.isShowingBanner)
    #expect(controller.showBanner(title: "Third", body: "", onTap: {}) == false)

    controller.bannerModel.bannerDragEnded(verticalTranslation: -40)
    expectNoDifference(controller.bannerModel.banner?.title, "Second")
    #expect(controller.isShowingBanner)

    controller.bannerModel.bannerDragEnded(verticalTranslation: -40)
    #expect(controller.isShowingBanner == false)
    #expect(controller.bannerModel.banner == nil)
  }

  @Test
  func testReenablingModeWhileBannerRemainsAcceptsUpsideDownNotifications() throws {
    let window = try makeWindow()
    window.transform = upsideDown
    let controller = makeController(appWindow: window)
    controller.setUpsideDownModeEnabled(true)
    _ = controller.showBanner(title: "First", body: "", onTap: {})

    window.transform = .identity
    controller.setUpsideDownModeEnabled(false)
    window.transform = upsideDown
    controller.setUpsideDownModeEnabled(true)

    #expect(controller.showBanner(title: "Second", body: "", onTap: {}))
    expectNoDifference(controller.bannerModel.banner?.title, "First")
  }

  @Test
  func testNoAppWindowKeepsSystemBanner() {
    let controller = makeController(appWindow: nil)
    controller.setUpsideDownModeEnabled(true)

    #expect(controller.showBanner(title: "New message", body: "Hi", onTap: {}) == false)
  }

  @Test
  func testHiddenAppWindowKeepsSystemBanner() throws {
    let window = try makeWindow()
    window.transform = upsideDown
    window.isHidden = true
    let controller = makeController(appWindow: window)
    controller.setUpsideDownModeEnabled(true)

    #expect(controller.showBanner(title: "New message", body: "Hi", onTap: {}) == false)
  }

  @Test
  func testInactiveSceneKeepsSystemBanner() throws {
    let window = try makeWindow()
    window.transform = upsideDown
    let controller = makeController(appWindow: window, isSceneActive: false)
    controller.setUpsideDownModeEnabled(true)

    #expect(controller.showBanner(title: "New message", body: "Hi", onTap: {}) == false)
  }

  @Test
  func testOverlayOnlyInterceptsTouchesInsideBannerCard() throws {
    let model = makeController(appWindow: nil).bannerModel
    model.show(title: "New message", body: "Hi", onTap: {})
    let overlay = BannerOverlayWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    overlay.bannerModel = model
    let bannerView = UIView(frame: overlay.bounds)
    overlay.addSubview(bannerView)
    overlay.bannerView = bannerView
    overlay.isHidden = false

    #expect(overlay.hitTest(CGPoint(x: 4, y: 50), with: nil) == nil)
    #expect(overlay.hitTest(CGPoint(x: 20, y: 50), with: nil) != nil)
  }

  // MARK: - Helpers

  private let upsideDown = CGAffineTransform(rotationAngle: .pi)

  private func makeController(
    appWindow: UIWindow?,
    isSceneActive: Bool = true
  ) -> UpsideDownNotificationBannerController {
    withDependencies {
      $0.continuousClock = TestClock()
      $0.uuid = .incrementing
    } operation: {
      UpsideDownNotificationBannerController(
        appWindow: { appWindow }, isSceneActive: { _ in isSceneActive })
    }
  }

  private func makeWindow() throws -> UIWindow {
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIViewController()
    window.isHidden = false
    return window
  }
}
