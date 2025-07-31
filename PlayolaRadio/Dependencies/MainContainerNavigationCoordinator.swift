//
//  MainContainerNavigationCoordinator.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/31/25.
//

import SwiftUI

/// This class coordinates any ViewControllers that need to be pushed onto the
/// top stack, meaning they will be presented over the MainContainer, covering the
/// tabs.
@Observable
final class MainContainerNavigationCoordinator: Sendable {
  static let shared = MainContainerNavigationCoordinator()

  var path: [Path] = []

  enum Path: Hashable {
    case editProfilePage(EditProfilePageModel)
  }

  private init() {}

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
}
