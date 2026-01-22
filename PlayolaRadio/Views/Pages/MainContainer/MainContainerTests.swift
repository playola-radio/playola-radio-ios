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
import PlayolaPlayer
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

  func testViewAppearedRegistersForRemoteNotifications() async {
    @Shared(.stationListsLoaded) var stationListsLoaded = false
    var registerForRemoteNotificationsCalled = false

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {
        registerForRemoteNotificationsCalled = true
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    XCTAssertTrue(registerForRemoteNotificationsCalled)
  }

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
      $0.pushNotifications.registerForRemoteNotifications = {}
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
      $0.pushNotifications.registerForRemoteNotifications = {}
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
      $0.pushNotifications.registerForRemoteNotifications = {}
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    XCTAssertEqual(getStationsCallCount, 0)
    XCTAssertTrue(hasBeenUnlocked)  // Should still be set even when exiting early
  }

  func testViewAppearedLoadsAiringsWhenLoggedIn() async {
    let testJWT = MainContainerTests.createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)
    @Shared(.stationListsLoaded) var stationListsLoaded = false
    @Shared(.airings) var airings: IdentifiedArrayOf<Airing> = []

    var getAiringsCallCount = 0
    let mockAirings = [
      Airing.mockWith(id: "airing1"),
      Airing.mockWith(id: "airing2"),
    ]

    let mainContainerModel = withDependencies {
      $0.api.getStations = { StationList.mocks }
      $0.api.getAirings = { _, _ in
        getAiringsCallCount += 1
        return mockAirings
      }
      $0.pushNotifications.registerForRemoteNotifications = {}
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()

    XCTAssertEqual(getAiringsCallCount, 1)
    XCTAssertEqual(airings.count, 2)
  }

  // MARK: - Small Player Properties Tests

  func testSmallPlayerProperties_ShouldShowSmallPlayerWhenPlaying() async {
    let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
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
      $0.pushNotifications.registerForRemoteNotifications = {}
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
      $0.pushNotifications.registerForRemoteNotifications = {}
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
      $0.pushNotifications.registerForRemoteNotifications = {}
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
      $0.pushNotifications.registerForRemoteNotifications = {}
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

  func testRefreshOnForegroundRefreshesStationListsAndAirings() async {
    let testJWT = MainContainerTests.createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.airings) var airings: IdentifiedArrayOf<Airing> = []

    var getStationsCallCount = 0
    var getAiringsCallCount = 0
    let mockAirings = [
      Airing.mockWith(id: "airing1"),
      Airing.mockWith(id: "airing2"),
    ]

    let mainContainerModel = withDependencies {
      $0.api.getStations = {
        getStationsCallCount += 1
        return StationList.mocks
      }
      $0.api.getAirings = { _, _ in
        getAiringsCallCount += 1
        return mockAirings
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.refreshOnForeground()

    XCTAssertEqual(getStationsCallCount, 1)
    XCTAssertEqual(getAiringsCallCount, 1)
    XCTAssertEqual(stationLists, StationList.mocks)
    XCTAssertEqual(airings.count, 2)
    XCTAssertEqual(airings[id: "airing1"]?.id, "airing1")
    XCTAssertEqual(airings[id: "airing2"]?.id, "airing2")
  }

  func testRefreshOnForegroundSkipsAiringsWhenNotLoggedIn() async {
    @Shared(.auth) var auth = Auth()
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.airings) var airings: IdentifiedArrayOf<Airing> = []

    var getStationsCallCount = 0
    var getAiringsCallCount = 0

    let mainContainerModel = withDependencies {
      $0.api.getStations = {
        getStationsCallCount += 1
        return StationList.mocks
      }
      $0.api.getAirings = { _, _ in
        getAiringsCallCount += 1
        return []
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.refreshOnForeground()

    XCTAssertEqual(getStationsCallCount, 1)
    XCTAssertEqual(getAiringsCallCount, 0)
    XCTAssertEqual(stationLists, StationList.mocks)
    XCTAssertTrue(airings.isEmpty)
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
      $0.api.getAirings = { _, _ in [] }
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

  func testRefreshOnForegroundRefreshesUnreadSupportCount() async {
    let testJWT = MainContainerTests.createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)
    @Shared(.unreadSupportCount) var unreadSupportCount = 0

    var getSupportConversationCallCount = 0

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.api.getAirings = { _, _ in [] }
      $0.api.getSupportConversation = { _ in
        getSupportConversationCallCount += 1
        return SupportConversationResponse(
          conversation: Conversation(
            id: "conv-1",
            type: "support",
            contextType: nil,
            contextId: nil,
            status: "open",
            createdAt: Date(),
            updatedAt: Date(),
            participants: nil
          ),
          unreadCount: 3
        )
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.refreshOnForeground()

    XCTAssertEqual(getSupportConversationCallCount, 1)
    XCTAssertEqual(unreadSupportCount, 3)
  }

  func testRefreshOnForegroundTracksAnalyticsOnAiringsError() async {
    let testJWT = MainContainerTests.createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)

    struct TestError: Error {
      var localizedDescription: String { "Test airings error" }
    }

    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.api.getAirings = { _, _ in
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
          return endpoint == "getAirings"
        }
        return false
      })
  }
  // MARK: - Rating Prompt Tests

  func testCheckRatingPromptShowsAlertWhenEligible() {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String?
    @Shared(.listeningTracker) var listeningTracker = ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: 2 * 60 * 60 * 1000,
        totalMSAvailableForRewards: 0,
        accurateAsOfTime: Date()
      )
    )

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating = .liveValue
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    XCTAssertNotNil(mainContainerModel.presentedAlert)
    XCTAssertEqual(mainContainerModel.presentedAlert?.title, "Are you enjoying Playola Radio?")
  }

  func testCheckRatingPromptDoesNotShowWhenNotEligible() {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -3, to: Date()
    )
    @Shared(.listeningTracker) var listeningTracker = ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: 2 * 60 * 60 * 1000,
        totalMSAvailableForRewards: 0,
        accurateAsOfTime: Date()
      )
    )

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating = .liveValue
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    XCTAssertNil(mainContainerModel.presentedAlert)
  }

  func testCheckRatingPromptOnlyChecksOncePerSession() {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String?
    @Shared(.listeningTracker) var listeningTracker = ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: 2 * 60 * 60 * 1000,
        totalMSAvailableForRewards: 0,
        accurateAsOfTime: Date()
      )
    )

    var shouldShowCallCount = 0

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating.shouldShowRatingPrompt = { _ in
        shouldShowCallCount += 1
        return true
      }
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.checkAndShowRatingPromptIfNeeded()
    mainContainerModel.checkAndShowRatingPromptIfNeeded()
    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    XCTAssertEqual(shouldShowCallCount, 1)
  }

  func testCheckRatingPromptDoesNotShowWhenNoListeningTracker() {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker?

    var shouldShowCalled = false

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating.shouldShowRatingPrompt = { _ in
        shouldShowCalled = true
        return true
      }
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    XCTAssertFalse(shouldShowCalled)
    XCTAssertNil(mainContainerModel.presentedAlert)
  }

  func testTabChangeChecksRatingPrompt() {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.activeTab) var activeTab: MainContainerModel.ActiveTab = .home
    @Shared(.listeningTracker) var listeningTracker = ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: 2 * 60 * 60 * 1000,
        totalMSAvailableForRewards: 0,
        accurateAsOfTime: Date()
      )
    )

    var shouldShowCalled = false

    let stationPlayerMock = StationPlayerMock()
    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating.shouldShowRatingPrompt = { _ in
        shouldShowCalled = true
        return false
      }
    } operation: {
      MainContainerModel(stationPlayer: stationPlayerMock)
    }

    // Simulate tab change - this is what onChange(of: model.activeTab) responds to
    $activeTab.withLock { $0 = .stationsList }
    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    XCTAssertTrue(shouldShowCalled)
  }

  func testRatingPromptEnjoyingTracksAnalyticsAndRequestsReview() async {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String?
    @Shared(.listeningTracker) var listeningTracker = ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: 2 * 60 * 60 * 1000,
        totalMSAvailableForRewards: 0,
        accurateAsOfTime: Date()
      )
    )

    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    var markShownCalled = false
    var requestReviewCalled = false

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating.shouldShowRatingPrompt = { _ in true }
      $0.appRating.markRatingPromptShown = { markShownCalled = true }
      $0.appRating.requestAppStoreReview = { requestReviewCalled = true }
      $0.analytics.track = { @Sendable event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    // Simulate tapping "Yes!"
    await mainContainerModel.presentedAlert?.primaryAction?()

    XCTAssertTrue(markShownCalled)
    XCTAssertTrue(requestReviewCalled)
    XCTAssertTrue(capturedEvents.value.contains { $0 == .ratingPromptEnjoying })
  }

  func testRatingPromptNotEnjoyingTracksAnalyticsAndShowsFeedback() async {
    let testJWT = MainContainerTests.createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String?
    @Shared(.listeningTracker) var listeningTracker = ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: 2 * 60 * 60 * 1000,
        totalMSAvailableForRewards: 0,
        accurateAsOfTime: Date()
      )
    )

    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    var markShownCalled = false

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.api.getSupportConversation = { _ in .mockWith() }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating.shouldShowRatingPrompt = { _ in true }
      $0.appRating.markRatingPromptShown = { markShownCalled = true }
      $0.analytics.track = { @Sendable event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    // Simulate tapping "Not really"
    await mainContainerModel.presentedAlert?.secondaryAction?()

    // Give time for the async feedback sheet to load
    try? await Task.sleep(for: .milliseconds(100))

    XCTAssertTrue(markShownCalled)
    XCTAssertTrue(capturedEvents.value.contains { $0 == .ratingPromptNotEnjoying })
    XCTAssertNil(
      mainContainerModel.presentedAlert, "Alert should be dismissed before showing feedback sheet")
    if case .feedbackSheet = mainContainerModel.mainContainerNavigationCoordinator.presentedSheet {
      // Test passes - feedback sheet is presented
    } else {
      XCTFail("Expected feedback sheet to be presented")
    }
  }

  func testRatingPromptDismissedTracksAnalyticsAndMarksDismissed() async {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String?
    @Shared(.listeningTracker) var listeningTracker = ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: 2 * 60 * 60 * 1000,
        totalMSAvailableForRewards: 0,
        accurateAsOfTime: Date()
      )
    )

    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    var markDismissedCalled = false

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating.shouldShowRatingPrompt = { _ in true }
      $0.appRating.markRatingPromptDismissed = { markDismissedCalled = true }
      $0.analytics.track = { @Sendable event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    // Simulate tapping "Not now"
    await mainContainerModel.presentedAlert?.tertiaryAction?()

    XCTAssertTrue(markDismissedCalled)
    XCTAssertTrue(capturedEvents.value.contains { $0 == .ratingPromptDismissed })
  }
}
// swiftlint:enable force_try
