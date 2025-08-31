//
//  MainContainerNavigationCoordinator.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/31/25.
//

import SwiftNavigation
import SwiftUI

/// This class coordinates any ViewControllers that need to be pushed onto the
/// top stack, meaning they will be presented over the MainContainer, covering the
/// tabs.
@Observable
final class MainContainerNavigationCoordinator: Sendable {
  var path: [Path] = []
  var presentedSheet: PlayolaSheet?

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
  func navigateToLikedSongs() {
    // Dismiss any presented sheet first
    presentedSheet = nil

    // Navigate to liked songs page
    let likedSongsModel = LikedSongsPageModel()
    push(.likedSongsPage(likedSongsModel))
  }
}
