//
//  MainContainerNavigationCoordinatorTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/31/25.
//

import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct MainContainerNavigationCoordinatorTests {

  // MARK: - navigateToLikedSongs Tests

  @Test
  func testNavigateToLikedSongsWithSheetAndDifferentTab() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .home

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = .player(PlayerPageModel())
      $activeTab.withLock { $0 = .home }

      await coordinator.navigateToLikedSongs()

      // Should have completed both transitions and pushed liked songs page
      #expect(coordinator.presentedSheet == nil)
      #expect(activeTab == .profile)
      #expect(coordinator.path.count == 1)
      if case .likedSongsPage = coordinator.path.first {
        // Success
      } else {
        Issue.record("Expected likedSongsPage to be pushed")
      }
    }
  }

  @Test
  func testNavigateToLikedSongsWithSheetButCorrectTab() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = .player(PlayerPageModel())
      $activeTab.withLock { $0 = .profile }

      await coordinator.navigateToLikedSongs()

      // Should have dismissed sheet, kept same tab, and pushed liked songs page
      #expect(coordinator.presentedSheet == nil)
      #expect(activeTab == .profile)
      #expect(coordinator.path.count == 1)
      if case .likedSongsPage = coordinator.path.first {
        // Success
      } else {
        Issue.record("Expected likedSongsPage to be pushed")
      }
    }
  }

  @Test
  func testNavigateToLikedSongsWithDifferentTabButNoSheet() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .home

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = nil
      $activeTab.withLock { $0 = .home }

      await coordinator.navigateToLikedSongs()

      // Should have changed tab and pushed liked songs page
      #expect(activeTab == .profile)
      #expect(coordinator.path.count == 1)
      if case .likedSongsPage = coordinator.path.first {
        // Success
      } else {
        Issue.record("Expected likedSongsPage to be pushed")
      }
    }
  }

  @Test
  func testNavigateToLikedSongsNoSheetAndCorrectTab() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = nil
      $activeTab.withLock { $0 = .profile }

      await coordinator.navigateToLikedSongs()

      // Should have pushed liked songs page
      #expect(coordinator.path.count == 1)
      #expect(activeTab == .profile)
      #expect(coordinator.presentedSheet == nil)

      if case .likedSongsPage = coordinator.path.first {
        // Success
      } else {
        Issue.record("Expected likedSongsPage to be pushed")
      }
    }
  }

  @Test
  func testNavigateToLikedSongsCreatesLikedSongsPageModel() async {
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
      #expect(coordinator.path.count == 1)
      if case .likedSongsPage = coordinator.path.first {
        // Success
      } else {
        Issue.record("Expected likedSongsPage with model to be pushed")
      }
    }
  }

  // MARK: - navigateToSupport Tests

  @Test
  func testNavigateToSupportWithSheetAndDifferentTab() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .home

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = .player(PlayerPageModel())
      $activeTab.withLock { $0 = .home }

      let supportModel = SupportPageModel()
      await coordinator.navigateToSupport(supportModel)

      #expect(coordinator.presentedSheet == nil)
      #expect(activeTab == .profile)
      #expect(coordinator.path.count == 1)
      if case .supportPage = coordinator.path.first {
        // Success
      } else {
        Issue.record("Expected supportPage to be pushed")
      }
    }
  }

  @Test
  func testNavigateToSupportWithSheetButCorrectTab() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = .player(PlayerPageModel())
      $activeTab.withLock { $0 = .profile }

      let supportModel = SupportPageModel()
      await coordinator.navigateToSupport(supportModel)

      #expect(coordinator.presentedSheet == nil)
      #expect(activeTab == .profile)
      #expect(coordinator.path.count == 1)
      if case .supportPage = coordinator.path.first {
        // Success
      } else {
        Issue.record("Expected supportPage to be pushed")
      }
    }
  }

  @Test
  func testNavigateToSupportWithDifferentTabButNoSheet() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .home

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = nil
      $activeTab.withLock { $0 = .home }

      let supportModel = SupportPageModel()
      await coordinator.navigateToSupport(supportModel)

      #expect(activeTab == .profile)
      #expect(coordinator.path.count == 1)
      if case .supportPage = coordinator.path.first {
        // Success
      } else {
        Issue.record("Expected supportPage to be pushed")
      }
    }
  }

  @Test
  func testNavigateToSupportNoSheetAndCorrectTab() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = nil
      $activeTab.withLock { $0 = .profile }

      let supportModel = SupportPageModel()
      await coordinator.navigateToSupport(supportModel)

      #expect(coordinator.path.count == 1)
      #expect(activeTab == .profile)
      #expect(coordinator.presentedSheet == nil)

      if case .supportPage = coordinator.path.first {
        // Success
      } else {
        Issue.record("Expected supportPage to be pushed")
      }
    }
  }

  @Test
  func testNavigateToSupportUsesProvidedModel() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = nil
      $activeTab.withLock { $0 = .profile }

      let supportModel = SupportPageModel()
      await coordinator.navigateToSupport(supportModel)

      #expect(coordinator.path.count == 1)
      if case .supportPage(let model) = coordinator.path.first {
        #expect(model === supportModel)
      } else {
        Issue.record("Expected supportPage with the provided model to be pushed")
      }
    }
  }

  // MARK: - switchToBroadcastMode Tests

  @Test
  func testSwitchToBroadcastModeSetsAppModeAndClearsPath() {
    let coordinator = MainContainerNavigationCoordinator()
    coordinator.path = [.editProfilePage(EditProfilePageModel())]

    coordinator.switchToBroadcastMode(stationId: "station-123")

    #expect(coordinator.appMode == .broadcasting(stationId: "station-123"))
    #expect(coordinator.path.isEmpty)
  }

  @Test
  func testSwitchToBroadcastModeFromListeningMode() {
    let coordinator = MainContainerNavigationCoordinator()
    #expect(coordinator.appMode == .listening)

    coordinator.switchToBroadcastMode(stationId: "my-station")

    #expect(coordinator.appMode == .broadcasting(stationId: "my-station"))
  }

  // MARK: - switchToListeningMode Tests

  @Test
  func testSwitchToListeningModeSetsAppModeAndClearsPath() {
    let coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")
    coordinator.path = [.editProfilePage(EditProfilePageModel())]

    coordinator.switchToListeningMode()

    #expect(coordinator.appMode == .listening)
    #expect(coordinator.path.isEmpty)
  }

  @Test
  func testSwitchToListeningModeFromBroadcastMode() {
    let coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")

    coordinator.switchToListeningMode()

    #expect(coordinator.appMode == .listening)
  }

  // MARK: - navigateToLikedSongs from Broadcast Mode Tests

  @Test
  func testNavigateToLikedSongsSwitchesToListeningModeFirst() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.appMode = .broadcasting(stationId: "station-123")
      $activeTab.withLock { $0 = .profile }

      await coordinator.navigateToLikedSongs()

      #expect(coordinator.appMode == .listening)
      #expect(coordinator.path.count == 1)
      if case .likedSongsPage = coordinator.path.first {
        // Success
      } else {
        Issue.record("Expected likedSongsPage to be pushed")
      }
    }
  }

  // MARK: - navigateToSupport from Broadcast Mode Tests

  @Test
  func testNavigateToSupportSwitchesToListeningModeFirst() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.appMode = .broadcasting(stationId: "station-123")
      $activeTab.withLock { $0 = .profile }

      let supportModel = SupportPageModel()
      await coordinator.navigateToSupport(supportModel)

      #expect(coordinator.appMode == .listening)
      #expect(coordinator.path.count == 1)
      if case .supportPage = coordinator.path.first {
        // Success
      } else {
        Issue.record("Expected supportPage to be pushed")
      }
    }
  }
}
