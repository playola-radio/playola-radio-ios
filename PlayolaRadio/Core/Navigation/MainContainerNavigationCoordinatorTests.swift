//
//  MainContainerNavigationCoordinatorTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/31/25.
//

import Dependencies
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class MainContainerNavigationCoordinatorTests: XCTestCase {
  // MARK: - Setup

  override func setUp() async throws {
    try await super.setUp()
    // Clear any shared state
    @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .home
    $activeTab.withLock { $0 = .home }
  }

  // MARK: - navigateToLikedSongs Tests

  func testNavigateToLikedSongs_WithSheetAndDifferentTab() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .home

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = .player(PlayerPageModel())
      $activeTab.withLock { $0 = .home }

      await coordinator.navigateToLikedSongs()

      // Should have completed both transitions and pushed liked songs page
      XCTAssertNil(coordinator.presentedSheet)
      XCTAssertEqual(activeTab, .profile)
      XCTAssertEqual(coordinator.path.count, 1)
      if case .likedSongsPage = coordinator.path.first {
        // Success
      } else {
        XCTFail("Expected likedSongsPage to be pushed")
      }
    }
  }

  func testNavigateToLikedSongs_WithSheetButCorrectTab() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = .player(PlayerPageModel())
      $activeTab.withLock { $0 = .profile }

      await coordinator.navigateToLikedSongs()

      // Should have dismissed sheet, kept same tab, and pushed liked songs page
      XCTAssertNil(coordinator.presentedSheet)
      XCTAssertEqual(activeTab, .profile)
      XCTAssertEqual(coordinator.path.count, 1)
      if case .likedSongsPage = coordinator.path.first {
        // Success
      } else {
        XCTFail("Expected likedSongsPage to be pushed")
      }
    }
  }

  func testNavigateToLikedSongs_WithDifferentTabButNoSheet() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .home

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = nil
      $activeTab.withLock { $0 = .home }

      await coordinator.navigateToLikedSongs()

      // Should have changed tab and pushed liked songs page
      XCTAssertEqual(activeTab, .profile)
      XCTAssertEqual(coordinator.path.count, 1)
      if case .likedSongsPage = coordinator.path.first {
        // Success
      } else {
        XCTFail("Expected likedSongsPage to be pushed")
      }
    }
  }

  func testNavigateToLikedSongs_NoSheetAndCorrectTab() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = nil
      $activeTab.withLock { $0 = .profile }

      await coordinator.navigateToLikedSongs()

      // Should have pushed liked songs page
      XCTAssertEqual(coordinator.path.count, 1)
      XCTAssertEqual(activeTab, .profile)
      XCTAssertNil(coordinator.presentedSheet)

      if case .likedSongsPage = coordinator.path.first {
        // Success
      } else {
        XCTFail("Expected likedSongsPage to be pushed")
      }
    }
  }

  func testNavigateToLikedSongs_CreatesLikedSongsPageModel() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile

      let coordinator = MainContainerNavigationCoordinator()

      // Ensure we start in the desired state
      coordinator.presentedSheet = nil
      $activeTab.withLock { $0 = .profile }

      await coordinator.navigateToLikedSongs()

      // Verify that a LikedSongsPageModel was created
      XCTAssertEqual(coordinator.path.count, 1)
      if case .likedSongsPage(let model) = coordinator.path.first {
        XCTAssertNotNil(model)
      } else {
        XCTFail("Expected likedSongsPage with model to be pushed")
      }
    }
  }
}
