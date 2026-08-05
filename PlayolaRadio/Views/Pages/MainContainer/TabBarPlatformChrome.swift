//
//  TabBarPlatformChrome.swift
//  PlayolaRadio
//
//  Compatibility boundary for the tab bar + mini player.
//
//  iOS 26.1+ renders a native Liquid Glass tab bar and hosts the mini player as
//  a `tabViewBottomAccessory`. Everything below that floor (iOS 18 through
//  iOS 26.0) keeps the opaque-black UIKit tab bar and embeds the mini player
//  beneath each tab's content.
//
//  All three modifiers MUST use the same availability floor so a device never
//  gets a mismatched combination (e.g. glass tab bar with no mini player). The
//  floor is iOS 26.1 because `tabViewBottomAccessory(isEnabled:)` is unavailable
//  before 26.1; iOS 26.0 therefore falls to the fully-consistent legacy path.
//
//  Every OS fork for this feature lives in THIS file. When the legacy OSes are
//  dropped, delete the `else` branches below (and the two `playolaLegacy*` call
//  sites in MainContainer) and the app is left on the pure Liquid Glass path.
//

import SwiftUI
import UIKit

extension View {
  /// Tab bar chrome appropriate to the OS.
  /// - iOS 26.1+: no-op, so the system renders its native Liquid Glass tab bar.
  /// - Legacy: installs the opaque-black `UITabBarAppearance`.
  @ViewBuilder
  func playolaTabBarChrome() -> some View {
    if #available(iOS 26.1, *) {
      self
    } else {
      self.onAppear {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .black

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().unselectedItemTintColor = UIColor(white: 0.7, alpha: 1.0)
      }
    }
  }

  /// Attaches the mini player as the tab view's floating bottom accessory.
  /// - iOS 26.1+: hosts `content` via `tabViewBottomAccessory`, shown/hidden by `isEnabled`.
  /// - Legacy: no-op (the mini player is embedded per-tab via `playolaLegacySmallPlayer`).
  @ViewBuilder
  func playolaBottomAccessory<Accessory: View>(
    isEnabled: Bool,
    @ViewBuilder content: () -> Accessory
  ) -> some View {
    if #available(iOS 26.1, *) {
      self.tabViewBottomAccessory(isEnabled: isEnabled, content: content)
    } else {
      self
    }
  }

  /// Embeds the mini player beneath a tab's content.
  /// - iOS 26.1+: no-op (the mini player is the tab view bottom accessory instead).
  /// - Legacy: stacks `content` under the tab content when `isEnabled`.
  @ViewBuilder
  func playolaLegacySmallPlayer<Accessory: View>(
    isEnabled: Bool,
    @ViewBuilder content: () -> Accessory
  ) -> some View {
    if #available(iOS 26.1, *) {
      self
    } else {
      VStack(spacing: 0) {
        self

        if isEnabled {
          content()
            .transition(.move(edge: .bottom))
            .zIndex(1)
        }
      }
    }
  }

  /// Minimizes the tab bar on scroll-down (Apple Music style).
  /// - iOS 26.1+: `.tabBarMinimizeBehavior(.onScrollDown)`.
  /// - Legacy: no-op (no glass tab bar to minimize).
  @ViewBuilder
  func playolaTabBarMinimize() -> some View {
    if #available(iOS 26.1, *) {
      self.tabBarMinimizeBehavior(.onScrollDown)
    } else {
      self
    }
  }
}

/// Hands `content` a plain `isInline` bool so `SmallPlayer` (deployment target
/// 18.1, also used in the legacy embed) never references an iOS 26 symbol.
/// - iOS 26.1+: `isInline == true` when the bottom accessory has squeezed inline
///   with a minimized tab bar.
/// - Legacy: always `false`.
struct PlayolaAccessoryPlacementReader<Content: View>: View {
  @ViewBuilder let content: (_ isInline: Bool) -> Content

  var body: some View {
    if #available(iOS 26.1, *) {
      PlacementEnvReader(content: content)
    } else {
      content(false)
    }
  }
}

@available(iOS 26.1, *)
private struct PlacementEnvReader<Content: View>: View {
  @Environment(\.tabViewBottomAccessoryPlacement) private var placement
  @ViewBuilder let content: (_ isInline: Bool) -> Content

  var body: some View {
    content(placement == .inline)
  }
}
