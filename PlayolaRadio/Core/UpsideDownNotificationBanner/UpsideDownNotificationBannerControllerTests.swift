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
  func testDisablingModeHidesShowingBanner() throws {
    let window = try makeWindow()
    window.transform = upsideDown
    let controller = makeController(appWindow: window)
    controller.setUpsideDownModeEnabled(true)
    _ = controller.showBanner(title: "New message", body: "Hi", onTap: {})

    controller.setUpsideDownModeEnabled(false)

    #expect(controller.isShowingBanner == false)
    #expect(controller.bannerModel.banner == nil)
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
