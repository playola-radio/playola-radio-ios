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

@Suite(.freshSharedState)
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

      // Should dismiss the sheet and switch to the Your Library tab
      #expect(coordinator.presentedSheet == nil)
      #expect(activeTab == .yourLibrary)
      #expect(coordinator.path.isEmpty)
    }
  }

  @Test
  func testNavigateToLikedSongsWithSheetButCorrectTab() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .yourLibrary

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = .player(PlayerPageModel())
      $activeTab.withLock { $0 = .yourLibrary }

      await coordinator.navigateToLikedSongs()

      // Should dismiss the sheet and stay on the Your Library tab
      #expect(coordinator.presentedSheet == nil)
      #expect(activeTab == .yourLibrary)
      #expect(coordinator.path.isEmpty)
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

      // Should switch to the Your Library tab
      #expect(activeTab == .yourLibrary)
      #expect(coordinator.path.isEmpty)
    }
  }

  @Test
  func testNavigateToLikedSongsNoSheetAndCorrectTab() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .yourLibrary

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = nil
      $activeTab.withLock { $0 = .yourLibrary }

      await coordinator.navigateToLikedSongs()

      // Should stay on the Your Library tab with no pushed pages
      #expect(coordinator.path.isEmpty)
      #expect(activeTab == .yourLibrary)
      #expect(coordinator.presentedSheet == nil)
    }
  }

  @Test
  func testNavigateToLikedSongsClearsYourLibraryStack() async {
    await withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .yourLibrary

      let coordinator = MainContainerNavigationCoordinator()
      coordinator.presentedSheet = nil
      $activeTab.withLock { $0 = .yourLibrary }
      coordinator.yourLibraryPath = [.editProfilePage(EditProfilePageModel())]

      await coordinator.navigateToLikedSongs()

      // Any pushed pages on the Your Library stack are cleared
      #expect(coordinator.path.isEmpty)
      #expect(activeTab == .yourLibrary)
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
  func testSwitchToBroadcastModeSelectsArtistDashboardTab() {
    @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile
    let coordinator = MainContainerNavigationCoordinator()

    coordinator.switchToBroadcastMode(stationId: "station-123")

    #expect(activeTab == .artistDashboard)
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

  @Test
  func testSwitchToListeningModeSelectsHomeTab() {
    @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .artistDashboard
    let coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")

    coordinator.switchToListeningMode()

    #expect(activeTab == .home)
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
      #expect(activeTab == .yourLibrary)
      #expect(coordinator.path.isEmpty)
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

  // MARK: - Koozie route guard

  private func koozieTracker(koozieOnly: Bool) -> ListeningTracker {
    ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: 0, totalMSAvailableForRewards: 0, accurateAsOfTime: Date(),
        rewardsExperience: koozieOnly ? "koozie_only" : nil))
  }

  @Test func pushRewardsNoOpsForKoozieUser() {
    @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile
    @Shared(.listeningTracker) var lt = koozieTracker(koozieOnly: true)
    let coordinator = MainContainerNavigationCoordinator()
    coordinator.pushRewards(RewardsPageModel())
    #expect(coordinator.profilePath.isEmpty)
  }

  @Test func pushRewardsPushesForFullTiersUser() {
    @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .profile
    @Shared(.listeningTracker) var lt = koozieTracker(koozieOnly: false)
    let coordinator = MainContainerNavigationCoordinator()
    coordinator.pushRewards(RewardsPageModel())
    #expect(coordinator.profilePath.count == 1)
  }

  @Test func sanitizeStripsRewardsFromProfilePathForKoozie() {
    @Shared(.listeningTracker) var lt = koozieTracker(koozieOnly: true)
    let coordinator = MainContainerNavigationCoordinator()
    coordinator.profilePath = [
      .rewardsPage(RewardsPageModel()),
      .notificationsSettingsPage(NotificationsSettingsPageModel()),
    ]
    coordinator.sanitizeRewardsRouteForKoozie()
    #expect(coordinator.profilePath.count == 1)
    if case .rewardsPage = coordinator.profilePath.first {
      Issue.record("rewardsPage should have been stripped for koozie user")
    }
  }

  @Test func sanitizeLeavesRewardsForFullTiersUser() {
    @Shared(.listeningTracker) var lt = koozieTracker(koozieOnly: false)
    let coordinator = MainContainerNavigationCoordinator()
    coordinator.profilePath = [.rewardsPage(RewardsPageModel())]
    coordinator.sanitizeRewardsRouteForKoozie()
    #expect(coordinator.profilePath.count == 1)
  }
}
