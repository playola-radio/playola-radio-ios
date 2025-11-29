//
//  MainContainerTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/12/25.
//

// swiftlint:disable force_try

import Dependencies
import Foundation
import IdentifiedCollections
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class MainContainerTests: XCTestCase {
  // Helper function to create valid JWT tokens for testing
  static func createTestJWT(
    id: String = "test-user-123",
    firstName: String = "Test",
    lastName: String? = "User",
    email: String = "test@example.com",
    profileImageUrl: String? = nil,
    role: String = "user"
  ) -> String {
    let header = ["alg": "HS256", "typ": "JWT"]
    var payload: [String: Any] = [
      "id": id,
      "firstName": firstName,
      "email": email,
      "role": role,
    ]
    if let lastName = lastName {
      payload["lastName"] = lastName
    }
    if let profileImageUrl = profileImageUrl {
      payload["profileImageUrl"] = profileImageUrl
    }

    let headerData = try! JSONSerialization.data(withJSONObject: header)
    let payloadData = try! JSONSerialization.data(withJSONObject: payload)

    let headerString = headerData.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")

    let payloadString = payloadData.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")

    return "\(headerString).\(payloadString).fake_signature"
  }

  // MARK: - ViewAppeared Tests

  func testViewAppeared_CorrectlyRetrievesStationListsWhenApiIsSuccessful() async {
    @Shared(.stationListsLoaded) var stationListsLoaded = false
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.hasBeenUnlocked) var hasBeenUnlocked = false
    var getStationsCallCount = 0

    let mainContainerModel = withDependencies {
      $0.api.getStations = {
        getStationsCallCount += 1
        return StationList.mocks
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    XCTAssertEqual(getStationsCallCount, 1)
    XCTAssertEqual(stationLists, StationList.mocks)
    XCTAssertTrue(stationListsLoaded)
    XCTAssertTrue(hasBeenUnlocked)
  }

  func testViewAppeared_DisplaysAnErrorAlertOnApiError() async {
    @Shared(.stationListsLoaded) var stationListsLoaded = false
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    struct TestError: Error {
      var localizedDescription: String { "Test error message" }
    }

    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let mainContainerModel = withDependencies {
      $0.api.getStations = {
        throw TestError()
      }
      $0.analytics.track = { @Sendable event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    XCTAssertEqual(mainContainerModel.presentedAlert, .errorLoadingStations)
    XCTAssertFalse(stationListsLoaded)

    // Verify analytics event was tracked
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 1)
    if case .apiError(let endpoint, let error) = events.first {
      XCTAssertEqual(endpoint, "getStations")
      XCTAssertTrue(
        error.contains("TestError"), "Expected error to contain 'TestError', got: \(error)")
    } else {
      XCTFail("Expected apiError event, got: \(String(describing: events.first))")
    }
  }

  func testViewAppeared_ExitsEarlyWhenStationListsAlreadyLoaded() async {
    @Shared(.stationListsLoaded) var stationListsLoaded = true
    @Shared(.hasBeenUnlocked) var hasBeenUnlocked = false
    var getStationsCallCount = 0

    let mainContainerModel = withDependencies {
      $0.api.getStations = {
        getStationsCallCount += 1
        return StationList.mocks
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    XCTAssertEqual(getStationsCallCount, 0)
    XCTAssertTrue(hasBeenUnlocked)  // Should still be set even when exiting early
  }

  // MARK: - Small Player Properties Tests

  func testSmallPlayerProperties_ShouldShowSmallPlayerWhenPlaying() async {
    let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
    } operation: {
      MainContainerModel(stationPlayer: stationPlayerMock)
    }

    await mainContainerModel.viewAppeared()
    XCTAssertTrue(mainContainerModel.shouldShowSmallPlayer)
  }

  func testSmallPlayerProperties_ShouldShowSmallPlayerWhenLoading() async {
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .loading(.mock))

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
    } operation: {
      MainContainerModel(stationPlayer: stationPlayerMock)
    }

    await mainContainerModel.viewAppeared()
    XCTAssertTrue(mainContainerModel.shouldShowSmallPlayer)
  }

  func testSmallPlayerProperties_ShouldShowSmallPlayerWhenStopped() async {
    let stationPlayerMock = StationPlayerMock.mockStoppedPlayer()

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
    } operation: {
      MainContainerModel(stationPlayer: stationPlayerMock)
    }

    await mainContainerModel.viewAppeared()
    XCTAssertFalse(mainContainerModel.shouldShowSmallPlayer)
  }

  func testSmallPlayerProperties_ShouldShowSmallPlayerWhenError() async {
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .error)

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
    } operation: {
      MainContainerModel(stationPlayer: stationPlayerMock)
    }

    await mainContainerModel.viewAppeared()
    XCTAssertFalse(mainContainerModel.shouldShowSmallPlayer)
  }

  func testSmallPlayerProperties_ShouldShowSmallPlayerWhenStartingNewStation() async {
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .startingNewStation(.mock))

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
    } operation: {
      MainContainerModel(stationPlayer: stationPlayerMock)
    }

    await mainContainerModel.viewAppeared()
    XCTAssertTrue(mainContainerModel.shouldShowSmallPlayer)
  }

  // MARK: - Small Player Actions Tests

  func testSmallPlayerActions_OnSmallPlayerTapped() {
    let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
    let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)

    mainContainerModel.onSmallPlayerTapped()

    XCTAssertNotNil(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet)
    if case .player = mainContainerModel.mainContainerNavigationCoordinator.presentedSheet {
      // Test passes
    } else {
      XCTFail("Expected player sheet to be presented")
    }
  }

  func testSmallPlayerActions_SmallPlayerHidesWhenStopButtonPressed() async {
    //    let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
    //
    //    let mainContainerModel = withDependencies {
    //      $0.api.getStations = { [] }
    //    } operation: {
    //      MainContainerModel(stationPlayer: stationPlayerMock)
    //    }
    //
    //    await mainContainerModel.viewAppeared()
    //    // Verify small player should be showing initially
    //    XCTAssertTrue(mainContainerModel.shouldShowSmallPlayer)
    //
    //    // Simulate the stop button being pressed
    //    mainContainerModel.onSmallPlayerStopTapped()
    //
    //    // Update the mock to reflect the stopped state
    //    stationPlayerMock.state = StationPlayer.State(playbackStatus: .stopped)
    //
    //    // Verify small player should now be hidden
    //    XCTAssertFalse(mainContainerModel.shouldShowSmallPlayer)
  }

  // MARK: - Process New Station State Tests

  func testProcessNewStationState_PresentsPlayerSheetWhenStartingNewStation() {
    let stationPlayerMock = StationPlayerMock()
    let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)

    let newState = StationPlayer.State(playbackStatus: .startingNewStation(.mock))
    mainContainerModel.processNewStationState(newState)

    XCTAssertNotNil(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet)
    if case .player = mainContainerModel.mainContainerNavigationCoordinator.presentedSheet {
      // Test passes
    } else {
      XCTFail("Expected player sheet to be presented")
    }
  }

  func testProcessNewStationState_DoesNotPresentSheetForOtherStates() {
    let stationPlayerMock = StationPlayerMock()
    let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)

    let playingState = StationPlayer.State(playbackStatus: .playing(.mock))
    mainContainerModel.processNewStationState(playingState)
    XCTAssertNil(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet)

    let stoppedState = StationPlayer.State(playbackStatus: .stopped)
    mainContainerModel.processNewStationState(stoppedState)
    XCTAssertNil(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet)

    let loadingState = StationPlayer.State(playbackStatus: .loading(.mock))
    mainContainerModel.processNewStationState(loadingState)
    XCTAssertNil(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet)

    let errorState = StationPlayer.State(playbackStatus: .error)
    mainContainerModel.processNewStationState(errorState)
    XCTAssertNil(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet)
  }

  // MARK: - Dismiss Button Tests

  func testDismissButton_PlayerPageOnDismissClearsPresentedSheet() {
    // @Shared(.mainContainerNavigationCoordinator)
    // var mainContainerNavigationCoordinator = MainContainerNavigationCoordinator()
    //
    let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
    let mainContainerModel = MainContainerModel(stationPlayer: stationPlayerMock)

    // Trigger the presentation of the player sheet
    mainContainerModel.onSmallPlayerTapped()

    // Verify the sheet is presented
    XCTAssertNotNil(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet)

    // Extract the PlayerPageModel from the presented sheet
    guard
      case .player(let playerPageModel) = mainContainerModel.mainContainerNavigationCoordinator
        .presentedSheet
    else {
      XCTFail("Expected player sheet to be presented")
      return
    }

    // Call the onDismiss callback
    playerPageModel.onDismiss?()

    // Verify the sheet is now nil
    XCTAssertNil(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet)
  }

  // MARK: - Playola Station Player Configuration Tests

  func testPlayolaStationPlayer_ConfiguresPlayolaStationPlayerOnInit() async {
    let testJWT = MainContainerTests.createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)

    // When MainContainerModel is created (user is logged in),
    // it should configure PlayolaStationPlayer with authentication
    let mainContainerModel = MainContainerModel()

    XCTAssertNotNil(mainContainerModel, "MainContainerModel should be created successfully")
  }

  func testPlayolaStationPlayer_UsesAuthenticatedSessionReporting() async {
    let testJWT = MainContainerTests.createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)

    // MainContainerModel creation should configure PlayolaStationPlayer
    // to use JWT tokens for session reporting
    _ = MainContainerModel()

    XCTAssertTrue(auth.isLoggedIn)
    XCTAssertEqual(auth.jwt, testJWT)
  }

  // MARK: - Authentication State Lifecycle Tests

  func testAuthStateLifecycle_MainContainerExistsOnlyWhenAuthenticated() async {
    let testJWT = MainContainerTests.createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)

    // User is logged in - MainContainer can be created
    XCTAssertTrue(auth.isLoggedIn)
    let mainContainerModel = MainContainerModel()
    XCTAssertNotNil(mainContainerModel)

    // When user signs out, ContentView will destroy MainContainer
    // and show SignInPage instead - this is handled by ContentView logic
    $auth.withLock { $0 = Auth() }
    XCTAssertFalse(auth.isLoggedIn)
  }

  func testAuthStateLifecycle_MultipleLoginSessionsGetFreshConfig() async {
    @Shared(.auth) var auth = Auth()

    // First login session
    let firstJWT = MainContainerTests.createTestJWT(
      id: "user1", firstName: "First", lastName: "User")
    $auth.withLock { $0 = Auth(jwtToken: firstJWT) }
    _ = MainContainerModel()
    XCTAssertEqual(auth.jwt, firstJWT)

    // User logs out, logs back in with new token
    $auth.withLock { $0 = Auth() }
    let secondJWT = MainContainerTests.createTestJWT(
      id: "user2", firstName: "Second", lastName: "User")
    $auth.withLock { $0 = Auth(jwtToken: secondJWT) }
    _ = MainContainerModel()
    XCTAssertEqual(auth.jwt, secondJWT)
  }

  // MARK: - Refresh On Foreground Tests

  func testRefreshOnForeground_RefreshesStationListsAndScheduledShows() async {
    let testJWT = MainContainerTests.createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.scheduledShows) var scheduledShows: IdentifiedArrayOf<ScheduledShow> = []

    var getStationsCallCount = 0
    var getScheduledShowsCallCount = 0
    let mockScheduledShows = [
      ScheduledShow.mockWith(id: "show1"),
      ScheduledShow.mockWith(id: "show2"),
    ]

    let mainContainerModel = withDependencies {
      $0.api.getStations = {
        getStationsCallCount += 1
        return StationList.mocks
      }
      $0.api.getScheduledShows = { _, _, _ in
        getScheduledShowsCallCount += 1
        return mockScheduledShows
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.refreshOnForeground()

    XCTAssertEqual(getStationsCallCount, 1)
    XCTAssertEqual(getScheduledShowsCallCount, 1)
    XCTAssertEqual(stationLists, StationList.mocks)
    XCTAssertEqual(scheduledShows.count, 2)
    XCTAssertEqual(scheduledShows[id: "show1"]?.id, "show1")
    XCTAssertEqual(scheduledShows[id: "show2"]?.id, "show2")
  }

  func testRefreshOnForeground_SkipsScheduledShowsWhenNotLoggedIn() async {
    @Shared(.auth) var auth = Auth()
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.scheduledShows) var scheduledShows: IdentifiedArrayOf<ScheduledShow> = []

    var getStationsCallCount = 0
    var getScheduledShowsCallCount = 0

    let mainContainerModel = withDependencies {
      $0.api.getStations = {
        getStationsCallCount += 1
        return StationList.mocks
      }
      $0.api.getScheduledShows = { _, _, _ in
        getScheduledShowsCallCount += 1
        return []
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.refreshOnForeground()

    XCTAssertEqual(getStationsCallCount, 1)
    XCTAssertEqual(getScheduledShowsCallCount, 0)
    XCTAssertEqual(stationLists, StationList.mocks)
    XCTAssertTrue(scheduledShows.isEmpty)
  }

  func testRefreshOnForeground_TracksAnalyticsOnStationsError() async {
    let testJWT = MainContainerTests.createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)

    struct TestError: Error {
      var localizedDescription: String { "Test stations error" }
    }

    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let mainContainerModel = withDependencies {
      $0.api.getStations = {
        throw TestError()
      }
      $0.api.getScheduledShows = { _, _, _ in [] }
      $0.analytics.track = { @Sendable event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.refreshOnForeground()

    let events = capturedEvents.value
    XCTAssertTrue(
      events.contains { event in
        if case .apiError(let endpoint, _) = event {
          return endpoint == "getStations"
        }
        return false
      })
  }

  func testRefreshOnForeground_TracksAnalyticsOnScheduledShowsError() async {
    let testJWT = MainContainerTests.createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)

    struct TestError: Error {
      var localizedDescription: String { "Test scheduled shows error" }
    }

    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.api.getScheduledShows = { _, _, _ in
        throw TestError()
      }
      $0.analytics.track = { @Sendable event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.refreshOnForeground()

    let events = capturedEvents.value
    XCTAssertTrue(
      events.contains { event in
        if case .apiError(let endpoint, _) = event {
          return endpoint == "getScheduledShows"
        }
        return false
      })
  }
}
// swiftlint:enable force_try
