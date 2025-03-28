//
//  SideMenuTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 2/27/25.
//

import XCTest
@testable import PlayolaRadio
import Sharing
import Testing

enum SideMenuViewModelTests {


  @MainActor @Suite("Menu Items Display")
    struct MenuItemsDisplay {
      @Test("Shows all menu items including My Station when user has a station")
      func testMenuItemsWithStation() async {
        let navigationCoordinator = NavigationCoordinatorMock()
        let viewModel = SideMenuViewModel(navigationCoordinator: navigationCoordinator)

        let userWithStation: User = .mockWithStation
        viewModel.user = userWithStation

        let menuItems = viewModel.menuItems
        #expect(menuItems.contains(.broadcast))
      }

      @Test("Hides My Station menu item when user has no station")
      func testMenuItemsWithoutStation() async {
        let navigationCoordinator = NavigationCoordinatorMock()
        let viewModel = SideMenuViewModel(navigationCoordinator: navigationCoordinator)

        let userWithoutStation: User = .mockWithoutStation
        viewModel.user = userWithoutStation

        let menuItems = viewModel.menuItems
        #expect(!menuItems.contains(.broadcast))
      }
    }


  // MARK: - Initial State

  @MainActor @Suite("Initial State")
  struct InitialState {
    @Test("Returns correct selectedSideMenuTab when activePath is .about")
    func testSelectedTabWhenActivePathIsAbout() async {
      let navigationCoordinator = NavigationCoordinatorMock()
      navigationCoordinator.activePath = .about
      let viewModel = SideMenuViewModel(navigationCoordinator: navigationCoordinator)
      #expect(viewModel.selectedSideMenuTab == .about)
    }

    @Test("Returns correct selectedSideMenuTab when activePath is .listen")
    func testSelectedTabWhenActivePathIsListen() async {
      let navigationCoordinator = NavigationCoordinatorMock()
      navigationCoordinator.activePath = .listen
      let viewModel = SideMenuViewModel(navigationCoordinator: navigationCoordinator)
      #expect(viewModel.selectedSideMenuTab == .listen)
    }
  }

  // MARK: - Row Tapping

  @MainActor @Suite("Row Tapping")
  struct RowTapping {
    @Test("Tapping a row updates selectedSideMenuTab and hides the side menu")
    func testRowTappedUpdatesTabAndHidesMenu() async {
      let navigationCoordinator = NavigationCoordinatorMock()
      navigationCoordinator.activePath = .listen  // initial state
      navigationCoordinator.slideOutMenuIsShowing = true

      let viewModel = SideMenuViewModel(navigationCoordinator: navigationCoordinator)
      viewModel.rowTapped(row: .about)

      #expect(viewModel.selectedSideMenuTab == .about)
      #expect(navigationCoordinator.slideOutMenuIsShowing == false)
    }
  }

  // MARK: - Sign Out Behavior

  @MainActor @Suite("Sign Out")
  struct SignOut {
    @Test("Sign out resets navigation, stops playback, and hides the menu")
    func testSignOutTapped() async {
      let navigationCoordinator = NavigationCoordinatorMock()
      navigationCoordinator.activePath = .listen  // starting state
      navigationCoordinator.slideOutMenuIsShowing = true

      let stationPlayerMock = StationPlayerMock() // Expected to set a flag when stop() is called.
      let authServiceMock = AuthServiceMock()     // Expected to set a flag when signOut() is called.

      let viewModel = SideMenuViewModel(navigationCoordinator: navigationCoordinator,
                                        stationPlayer: stationPlayerMock,
                                        authService: authServiceMock)
      viewModel.signOutTapped()

      #expect(navigationCoordinator.activePath == .signIn)
      #expect(navigationCoordinator.slideOutMenuIsShowing == false)
      #expect(stationPlayerMock.stopCalledCount == 1)
      #expect(authServiceMock.signOutCallCount == 1)
    }
  }
}
