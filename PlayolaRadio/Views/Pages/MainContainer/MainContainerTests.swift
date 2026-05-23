//
//  MainContainerTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/12/25.
//

// swiftlint:disable force_try

import ConcurrencyExtras
import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

// Helper function to create valid JWT tokens for testing.
// Module-internal (not file-private) so HomePageTests can reuse it.
func createTestJWT(
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

@MainActor
struct MainContainerTests {
  // MARK: - ViewAppeared Tests

  @Test
  func testViewAppearedRegistersForRemoteNotifications() async {
    @Shared(.stationListsLoaded) var stationListsLoaded = false
    let registerForRemoteNotificationsCalled = LockIsolated(false)

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {
        registerForRemoteNotificationsCalled.setValue(true)
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    #expect(registerForRemoteNotificationsCalled.value)
  }

  @Test
  func testViewAppearedCorrectlyRetrievesStationListsWhenApiIsSuccessful() async {
    @Shared(.stationListsLoaded) var stationListsLoaded = false
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    let getStationsCallCount = LockIsolated(0)

    let mainContainerModel = withDependencies {
      $0.api.getStations = {
        getStationsCallCount.withValue { $0 += 1 }
        return StationList.mocks
      }
      $0.pushNotifications.registerForRemoteNotifications = {}
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    #expect(getStationsCallCount.value == 1)
    #expect(stationLists == StationList.mocks)
    #expect(stationListsLoaded)
  }

  @Test
  func testViewAppearedDisplaysAnErrorAlertOnApiError() async {
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
    #expect(mainContainerModel.presentedAlert == .errorLoadingStations)
    #expect(!stationListsLoaded)

    let events = capturedEvents.value
    #expect(events.count == 1)
    if case .apiError(let endpoint, let error) = events.first {
      #expect(endpoint == "getStations")
      #expect(
        error.contains("TestError"), "Expected error to contain 'TestError', got: \(error)")
    } else {
      Issue.record("Expected apiError event, got: \(String(describing: events.first))")
    }
  }

  @Test
  func testViewAppearedExitsEarlyWhenStationListsAlreadyLoaded() async {
    @Shared(.stationListsLoaded) var stationListsLoaded = true
    let getStationsCallCount = LockIsolated(0)

    let mainContainerModel = withDependencies {
      $0.api.getStations = {
        getStationsCallCount.withValue { $0 += 1 }
        return StationList.mocks
      }
      $0.pushNotifications.registerForRemoteNotifications = {}
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    #expect(getStationsCallCount.value == 0)
  }

  @Test
  func testViewAppearedLoadsAiringsWhenLoggedIn() async {
    let testJWT = createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)
    @Shared(.stationListsLoaded) var stationListsLoaded = false
    @Shared(.airings) var airings: IdentifiedArrayOf<Airing> = []

    let getAiringsCallCount = LockIsolated(0)
    let mockAirings = [
      Airing.mockWith(id: "airing1"),
      Airing.mockWith(id: "airing2"),
    ]

    let mainContainerModel = withDependencies {
      $0.api.getStations = { StationList.mocks }
      $0.api.getAirings = { _, _ in
        getAiringsCallCount.withValue { $0 += 1 }
        return mockAirings
      }
      $0.pushNotifications.registerForRemoteNotifications = {}
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()

    #expect(getAiringsCallCount.value == 1)
    #expect(airings.count == 2)
  }

  // MARK: - Small Player Properties Tests

  @Test
  func testSmallPlayerPropertiesShouldShowSmallPlayerWhenPlaying() async {
    let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.stationPlayer = stationPlayerMock
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    #expect(mainContainerModel.shouldShowSmallPlayer)
  }

  @Test
  func testSmallPlayerPropertiesShouldShowSmallPlayerWhenLoading() async {
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .loading(.mock))

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.stationPlayer = stationPlayerMock
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    #expect(mainContainerModel.shouldShowSmallPlayer)
  }

  @Test
  func testSmallPlayerPropertiesShouldShowSmallPlayerWhenStopped() async {
    let stationPlayerMock = StationPlayerMock.mockStoppedPlayer()

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.stationPlayer = stationPlayerMock
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    #expect(!mainContainerModel.shouldShowSmallPlayer)
  }

  @Test
  func testSmallPlayerPropertiesShouldShowSmallPlayerWhenError() async {
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .error)

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.stationPlayer = stationPlayerMock
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    #expect(!mainContainerModel.shouldShowSmallPlayer)
  }

  @Test
  func testSmallPlayerPropertiesShouldShowSmallPlayerWhenStartingNewStation() async {
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = StationPlayer.State(playbackStatus: .startingNewStation(.mock))

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.stationPlayer = stationPlayerMock
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.viewAppeared()
    #expect(mainContainerModel.shouldShowSmallPlayer)
  }

  // MARK: - Small Player Actions Tests

  @Test
  func testSmallPlayerActionsOnSmallPlayerTapped() {
    let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
    let mainContainerModel = withDependencies {
      $0.stationPlayer = stationPlayerMock
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.onSmallPlayerTapped()

    #expect(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet != nil)
    if case .player = mainContainerModel.mainContainerNavigationCoordinator.presentedSheet {
      // Test passes
    } else {
      Issue.record("Expected player sheet to be presented")
    }
  }

  // MARK: - Process New Station State Tests

  @Test
  func testProcessNewStationStatePresentsPlayerSheetWhenStartingNewStation() {
    let stationPlayerMock = StationPlayerMock()
    let mainContainerModel = withDependencies {
      $0.stationPlayer = stationPlayerMock
    } operation: {
      MainContainerModel()
    }

    let newState = StationPlayer.State(playbackStatus: .startingNewStation(.mock))
    mainContainerModel.processNewStationState(newState)

    #expect(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet != nil)
    if case .player = mainContainerModel.mainContainerNavigationCoordinator.presentedSheet {
      // Test passes
    } else {
      Issue.record("Expected player sheet to be presented")
    }
  }

  @Test
  func testProcessNewStationStateDoesNotPresentSheetForOtherStates() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()

    let stationPlayerMock = StationPlayerMock()
    let mainContainerModel = withDependencies {
      $0.stationPlayer = stationPlayerMock
    } operation: {
      MainContainerModel()
    }

    let playingState = StationPlayer.State(playbackStatus: .playing(.mock))
    mainContainerModel.processNewStationState(playingState)
    #expect(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet == nil)

    let stoppedState = StationPlayer.State(playbackStatus: .stopped)
    mainContainerModel.processNewStationState(stoppedState)
    #expect(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet == nil)

    let loadingState = StationPlayer.State(playbackStatus: .loading(.mock))
    mainContainerModel.processNewStationState(loadingState)
    #expect(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet == nil)

    let errorState = StationPlayer.State(playbackStatus: .error)
    mainContainerModel.processNewStationState(errorState)
    #expect(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet == nil)
  }

  // MARK: - Dismiss Button Tests

  @Test
  func testDismissButtonPlayerPageOnDismissClearsPresentedSheet() {
    let stationPlayerMock = StationPlayerMock.mockPlayingPlayer()
    let mainContainerModel = withDependencies {
      $0.stationPlayer = stationPlayerMock
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.onSmallPlayerTapped()

    #expect(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet != nil)

    guard
      case .player(let playerPageModel) = mainContainerModel.mainContainerNavigationCoordinator
        .presentedSheet
    else {
      Issue.record("Expected player sheet to be presented")
      return
    }

    playerPageModel.onDismiss?()

    #expect(mainContainerModel.mainContainerNavigationCoordinator.presentedSheet == nil)
  }

  // MARK: - Playola Station Player Configuration Tests

  @Test
  func testPlayolaStationPlayerConfiguresPlayolaStationPlayerOnInit() async {
    let testJWT = createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)

    _ = MainContainerModel()
  }

  @Test
  func testPlayolaStationPlayerUsesAuthenticatedSessionReporting() async {
    let testJWT = createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)

    _ = MainContainerModel()

    #expect(auth.isLoggedIn)
    #expect(auth.jwt == testJWT)
  }

  // MARK: - Authentication State Lifecycle Tests

  @Test
  func testAuthStateLifecycleMainContainerExistsOnlyWhenAuthenticated() async {
    let testJWT = createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)

    #expect(auth.isLoggedIn)
    _ = MainContainerModel()

    $auth.withLock { $0 = Auth() }
    #expect(!auth.isLoggedIn)
  }

  @Test
  func testAuthStateLifecycleMultipleLoginSessionsGetFreshConfig() async {
    @Shared(.auth) var auth = Auth()

    let firstJWT = createTestJWT(
      id: "user1", firstName: "First", lastName: "User")
    $auth.withLock { $0 = Auth(jwtToken: firstJWT) }
    _ = MainContainerModel()
    #expect(auth.jwt == firstJWT)

    $auth.withLock { $0 = Auth() }
    let secondJWT = createTestJWT(
      id: "user2", firstName: "Second", lastName: "User")
    $auth.withLock { $0 = Auth(jwtToken: secondJWT) }
    _ = MainContainerModel()
    #expect(auth.jwt == secondJWT)
  }

  // MARK: - Refresh On Foreground Tests

  @Test
  func testRefreshOnForegroundRefreshesStationListsAndAirings() async {
    let testJWT = createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.airings) var airings: IdentifiedArrayOf<Airing> = []

    let getStationsCallCount = LockIsolated(0)
    let getAiringsCallCount = LockIsolated(0)
    let mockAirings = [
      Airing.mockWith(id: "airing1"),
      Airing.mockWith(id: "airing2"),
    ]

    let mainContainerModel = withDependencies {
      $0.api.getStations = {
        getStationsCallCount.withValue { $0 += 1 }
        return StationList.mocks
      }
      $0.api.getAirings = { _, _ in
        getAiringsCallCount.withValue { $0 += 1 }
        return mockAirings
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.refreshOnForeground()

    #expect(getStationsCallCount.value == 1)
    #expect(getAiringsCallCount.value == 1)
    #expect(stationLists == StationList.mocks)
    #expect(airings.count == 2)
    #expect(airings[id: "airing1"]?.id == "airing1")
    #expect(airings[id: "airing2"]?.id == "airing2")
  }

  @Test
  func testRefreshOnForegroundSkipsAiringsWhenNotLoggedIn() async {
    @Shared(.auth) var auth = Auth()
    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
    @Shared(.airings) var airings: IdentifiedArrayOf<Airing> = []

    let getStationsCallCount = LockIsolated(0)
    let getAiringsCallCount = LockIsolated(0)

    let mainContainerModel = withDependencies {
      $0.api.getStations = {
        getStationsCallCount.withValue { $0 += 1 }
        return StationList.mocks
      }
      $0.api.getAirings = { _, _ in
        getAiringsCallCount.withValue { $0 += 1 }
        return []
      }
    } operation: {
      MainContainerModel()
    }

    await mainContainerModel.refreshOnForeground()

    #expect(getStationsCallCount.value == 1)
    #expect(getAiringsCallCount.value == 0)
    #expect(stationLists == StationList.mocks)
    #expect(airings.isEmpty)
  }

  @Test
  func testRefreshOnForegroundTracksAnalyticsOnStationsError() async {
    let testJWT = createTestJWT()
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
    #expect(
      events.contains { event in
        if case .apiError(let endpoint, _) = event {
          return endpoint == "getStations"
        }
        return false
      })
  }

  @Test
  func testRefreshOnForegroundRefreshesUnreadSupportCount() async {
    let testJWT = createTestJWT()
    @Shared(.auth) var auth = Auth(jwtToken: testJWT)
    @Shared(.unreadSupportCount) var unreadSupportCount = 0

    let getSupportConversationCallCount = LockIsolated(0)

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.api.getAirings = { _, _ in [] }
      $0.api.getSupportConversation = { _ in
        getSupportConversationCallCount.withValue { $0 += 1 }
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

    #expect(getSupportConversationCallCount.value == 1)
    #expect(unreadSupportCount == 3)
  }

  @Test
  func testRefreshOnForegroundTracksAnalyticsOnAiringsError() async {
    let testJWT = createTestJWT()
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
    #expect(
      events.contains { event in
        if case .apiError(let endpoint, _) = event {
          return endpoint == "getAirings"
        }
        return false
      })
  }

  // MARK: - Rating Prompt Tests

  @Test
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

    withDependencies {
      $0.date = .constant(Date())
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating = .liveValue
    } operation: {
      let mainContainerModel = MainContainerModel()
      mainContainerModel.checkAndShowRatingPromptIfNeeded()

      #expect(mainContainerModel.presentedAlert != nil)
      #expect(mainContainerModel.presentedAlert?.title == "Are you enjoying Playola Radio?")
    }
  }

  @Test
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

    withDependencies {
      $0.date = .constant(Date())
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating = .liveValue
    } operation: {
      let mainContainerModel = MainContainerModel()
      mainContainerModel.checkAndShowRatingPromptIfNeeded()

      #expect(mainContainerModel.presentedAlert == nil)
    }
  }

  @Test
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

    let shouldShowCallCount = LockIsolated(0)

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating.shouldShowRatingPrompt = { _ in
        shouldShowCallCount.withValue { $0 += 1 }
        return true
      }
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.checkAndShowRatingPromptIfNeeded()
    mainContainerModel.checkAndShowRatingPromptIfNeeded()
    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    #expect(shouldShowCallCount.value == 1)
  }

  @Test
  func testCheckRatingPromptDoesNotShowWhenNoListeningTracker() {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker?

    let shouldShowCalled = LockIsolated(false)

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating.shouldShowRatingPrompt = { _ in
        shouldShowCalled.setValue(true)
        return true
      }
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    #expect(!shouldShowCalled.value)
    #expect(mainContainerModel.presentedAlert == nil)
  }

  @Test
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

    let shouldShowCalled = LockIsolated(false)

    let stationPlayerMock = StationPlayerMock()
    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating.shouldShowRatingPrompt = { _ in
        shouldShowCalled.setValue(true)
        return false
      }
      $0.stationPlayer = stationPlayerMock
    } operation: {
      MainContainerModel()
    }

    $activeTab.withLock { $0 = .stationsList }
    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    #expect(shouldShowCalled.value)
  }

  @Test
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
    let markShownCalled = LockIsolated(false)
    let requestReviewCalled = LockIsolated(false)

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating.shouldShowRatingPrompt = { _ in true }
      $0.appRating.markRatingPromptShown = { markShownCalled.setValue(true) }
      $0.appRating.requestAppStoreReview = { requestReviewCalled.setValue(true) }
      $0.analytics.track = { @Sendable event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    await mainContainerModel.presentedAlert?.primaryAction?()

    #expect(markShownCalled.value)
    #expect(requestReviewCalled.value)
    #expect(capturedEvents.value.contains { $0 == .ratingPromptEnjoying })
  }

  @Test
  func testRatingPromptNotEnjoyingTracksAnalyticsAndShowsFeedback() async {
    await withMainSerialExecutor {
      let testJWT = createTestJWT()
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
      let markShownCalled = LockIsolated(false)
      let markDismissedCalled = LockIsolated(false)

      let mainContainerModel = withDependencies {
        $0.api.getStations = { [] }
        $0.pushNotifications.registerForRemoteNotifications = {}
        $0.appRating.shouldShowRatingPrompt = { _ in true }
        $0.appRating.markRatingPromptShown = { markShownCalled.setValue(true) }
        $0.appRating.markRatingPromptDismissed = { markDismissedCalled.setValue(true) }
        $0.analytics.track = { @Sendable event in
          capturedEvents.withValue { $0.append(event) }
        }
      } operation: {
        MainContainerModel()
      }

      mainContainerModel.checkAndShowRatingPromptIfNeeded()
      await mainContainerModel.presentedAlert?.secondaryAction?()
      await waitForFeedbackSheet(on: mainContainerModel.mainContainerNavigationCoordinator)

      #expect(markShownCalled.value)
      #expect(
        markDismissedCalled.value,
        "Not really should also set dismiss date for 7-day cooldown")
      #expect(capturedEvents.value.contains { $0 == .ratingPromptNotEnjoying })
      #expect(capturedEvents.value.contains { $0 == .feedbackSheetPresented })
      #expect(
        mainContainerModel.presentedAlert == nil,
        "Alert should be dismissed before showing feedback sheet")
      guard
        case .feedbackSheet = mainContainerModel.mainContainerNavigationCoordinator.presentedSheet
      else {
        Issue.record("Expected feedback sheet to be presented")
        return
      }
    }
  }

  @Test
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
    let markDismissedCalled = LockIsolated(false)

    let mainContainerModel = withDependencies {
      $0.api.getStations = { [] }
      $0.pushNotifications.registerForRemoteNotifications = {}
      $0.appRating.shouldShowRatingPrompt = { _ in true }
      $0.appRating.markRatingPromptDismissed = { markDismissedCalled.setValue(true) }
      $0.analytics.track = { @Sendable event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      MainContainerModel()
    }

    mainContainerModel.checkAndShowRatingPromptIfNeeded()

    await mainContainerModel.presentedAlert?.tertiaryAction?()

    #expect(markDismissedCalled.value)
    #expect(capturedEvents.value.contains { $0 == .ratingPromptDismissed })
  }

  // MARK: - Mode-Aware Properties Tests

  @Test
  func testIsInBroadcastModeReturnsFalseWhenListening() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .listening

    let mainContainerModel = MainContainerModel()

    #expect(!mainContainerModel.isInBroadcastMode)
  }

  @Test
  func testIsInBroadcastModeReturnsTrueWhenBroadcasting() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")

    let mainContainerModel = MainContainerModel()

    #expect(mainContainerModel.isInBroadcastMode)
  }

  @Test
  func testBroadcastStationIdReturnsNilWhenListening() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .listening

    let mainContainerModel = MainContainerModel()

    #expect(mainContainerModel.broadcastStationId == nil)
  }

  @Test
  func testBroadcastStationIdReturnsStationIdWhenBroadcasting() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")

    let mainContainerModel = MainContainerModel()

    #expect(mainContainerModel.broadcastStationId == "station-123")
  }

  @Test
  func testEnsureBroadcastModelsCreatesBroadcastPageModel() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")

    let mainContainerModel = MainContainerModel()
    #expect(mainContainerModel.broadcastPageModel == nil)

    mainContainerModel.ensureBroadcastModels()

    #expect(mainContainerModel.broadcastPageModel != nil)
    #expect(mainContainerModel.broadcastPageModel?.stationId == "station-123")
  }

  @Test
  func testEnsureBroadcastModelsDoesNothingWhenListening() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .listening

    let mainContainerModel = MainContainerModel()
    mainContainerModel.ensureBroadcastModels()

    #expect(mainContainerModel.broadcastPageModel == nil)
  }

  @Test
  func testEnsureBroadcastModelsRecreatesModelsWhenStationIdChanges() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")

    let mainContainerModel = MainContainerModel()
    mainContainerModel.ensureBroadcastModels()

    let originalModel = mainContainerModel.broadcastPageModel
    #expect(originalModel?.stationId == "station-123")

    coordinator.appMode = .broadcasting(stationId: "station-456")
    mainContainerModel.ensureBroadcastModels()

    #expect(mainContainerModel.broadcastPageModel?.stationId == "station-456")
    #expect(!(mainContainerModel.broadcastPageModel === originalModel))
  }
}

// Drain the fire-and-forget Task in MainContainerModel.showFeedbackSheet()
// (it awaits analytics.track then assigns presentedSheet). Polling on the
// observable end-state is resilient to changes in the number of internal
// async hops.
@MainActor
private func waitForFeedbackSheet(on coordinator: MainContainerNavigationCoordinator) async {
  for _ in 0..<50 {
    if case .feedbackSheet = coordinator.presentedSheet { return }
    await Task.yield()
  }
}
// swiftlint:enable force_try
