//
//  MainContainerNavigationCoordinator.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/31/25.
//

import Dependencies
import Sharing
import SwiftNavigation
import SwiftUI

/// This class coordinates any ViewControllers that need to be pushed onto the
/// top stack, meaning they will be presented over the MainContainer, covering the
/// tabs.
@Observable
final class MainContainerNavigationCoordinator: Sendable {
  var path: [Path] = []
  var presentedSheet: PlayolaSheet?

  @ObservationIgnored @Shared(.activeTab) var activeTab
  @ObservationIgnored @Dependency(\.continuousClock) var clock

  @CasePathable
  enum Path: Hashable, Equatable {
    case editProfilePage(EditProfilePageModel)
    case likedSongsPage(LikedSongsPageModel)
  }

  func push(_ path: Path) {
    self.path.append(path)
  }

  func pop() {
    _ = self.path.popLast()
  }

  func popToRoot() {
    self.path.removeAll()
  }

  func replace(with path: Path) {
    self.path = [path]
  }

  @MainActor
  func navigateToLikedSongs() async {
    // Dismiss any presented sheet if needed
    if presentedSheet != nil {
      withAnimation(.easeInOut(duration: 0.3)) {
        presentedSheet = nil
      }

      // Wait for sheet dismissal animation
      try? await clock.sleep(for: .milliseconds(300))
    }

    // Set active tab to profile if needed
    if activeTab != .profile {
      withAnimation(.easeInOut(duration: 0.3)) {
        $activeTab.withLock { $0 = .profile }
      }

      // Wait for tab transition animation
      try? await clock.sleep(for: .milliseconds(300))
    }

    // Navigate to liked songs page
    let likedSongsModel = LikedSongsPageModel()
    push(.likedSongsPage(likedSongsModel))
  }
}
