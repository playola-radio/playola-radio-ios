//
//  ContactPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/29/25.
//
import ConcurrencyExtras
import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct ContactPageTests {
  @Test
  func testOnLogOutTappedStopsPlayerAndClearsAllUserState() async {
    let audioBlock = AudioBlock.mock
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.registeredDeviceId) var registeredDeviceId = "device-xyz"
    @Shared(.userLikes) var userLikes = [
      audioBlock.id: UserSongLike(userId: "u1", audioBlockId: audioBlock.id, audioBlock: audioBlock)
    ]
    @Shared(.pendingLikeOperations) var pendingLikeOperations = [
      LikeOperation(audioBlock: audioBlock, type: .like)
    ]
    @Shared(.airings) var airings: IdentifiedArrayOf<Airing> = [Airing.mockWith(id: "airing-1")]
    @Shared(.lastNotificationSentAt) var lastNotificationSentAt = ["station-1": Date()]
    @Shared(.isBroadcaster) var isBroadcaster = true
    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "analytics_session_paused_at")

    let unregisterCalls = LockIsolated<[(String, String)]>([])
    let resetCallCount = LockIsolated(0)
    let stationPlayerMock = StationPlayerMock()

    await withDependencies {
      $0.api.unregisterDevice = { jwt, deviceId in
        unregisterCalls.withValue { $0.append((jwt, deviceId)) }
      }
      $0.analytics = .noop
      $0.analytics.reset = { resetCallCount.withValue { $0 += 1 } }
    } operation: {
      await ContactPageModel(stationPlayer: stationPlayerMock).onLogOutTapped()
    }

    #expect(stationPlayerMock.stopCalledCount == 1)
    #expect(unregisterCalls.value.count == 1)
    #expect(unregisterCalls.value.first?.0 == "test-jwt")
    #expect(unregisterCalls.value.first?.1 == "device-xyz")
    #expect(resetCallCount.value == 1)
    #expect(!auth.isLoggedIn)
    #expect(registeredDeviceId == nil)
    #expect(userLikes.isEmpty)
    #expect(pendingLikeOperations.isEmpty)
    #expect(airings.isEmpty)
    #expect(lastNotificationSentAt.isEmpty)
    #expect(!isBroadcaster)
    #expect(UserDefaults.standard.object(forKey: "analytics_session_paused_at") == nil)
  }

  @Test
  func testNameDisplayReturnsFullNameWhenLoggedIn() {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "Jane",
      lastName: "Smith",
      email: "jane@example.com",
      role: "user"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = ContactPageModel()

    #expect(model.name == "Jane Smith")
  }

  @Test
  func testNameDisplayReturnsAnonymousWhenNotLoggedIn() {
    @Shared(.auth) var auth = Auth()

    let model = ContactPageModel()

    #expect(model.name == "Anonymous")
  }

  @Test
  func testEmailDisplayReturnsEmailWhenLoggedIn() {
    let loggedInUser = LoggedInUser(
      id: "456",
      firstName: "Bob",
      lastName: "Johnson",
      email: "bob@test.com",
      role: "admin"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = ContactPageModel()

    #expect(model.email == "bob@test.com")
  }

  @Test
  func testEmailDisplayReturnsUnknownWhenNotLoggedIn() {
    @Shared(.auth) var auth = Auth()

    let model = ContactPageModel()

    #expect(model.email == "Unknown")
  }

  @Test
  func testOnLikedSongsTappedNavigatesToLikedSongsPage() {
    let model = ContactPageModel()

    // Verify initial navigation state
    #expect(model.mainContainerNavigationCoordinator.path.isEmpty)

    // Tap liked songs button
    model.onLikedSongsTapped()

    // Verify navigation occurred
    #expect(model.mainContainerNavigationCoordinator.path.count == 1)

    if case .likedSongsPage = model.mainContainerNavigationCoordinator.path.first {
      // Successfully navigated to liked songs page
    } else {
      Issue.record("Expected navigation to liked songs page")
    }
  }

  @Test
  func testOnNotificationsTappedNavigatesToNotificationsSettingsPage() {
    let model = ContactPageModel()

    // Verify initial navigation state
    #expect(model.mainContainerNavigationCoordinator.path.isEmpty)

    // Tap notifications button
    model.onNotificationsTapped()

    // Verify navigation occurred
    #expect(model.mainContainerNavigationCoordinator.path.count == 1)

    if case .notificationsSettingsPage = model.mainContainerNavigationCoordinator.path.first {
      // Successfully navigated to notifications settings page
    } else {
      Issue.record("Expected navigation to notifications settings page")
    }
  }

  @Test
  func testOnMyStationTappedSwitchesToBroadcastMode() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    await withMainSerialExecutor {
      let mockStations = [Station.mockWith(id: "test-station-id")]

      await withDependencies {
        $0.api.fetchUserStations = { _ in mockStations }
        $0.analytics.track = { @Sendable _ in }
      } operation: {
        let model = ContactPageModel()

        await model.onViewAppeared()

        #expect(model.mainContainerNavigationCoordinator.appMode == .listening)

        await model.onMyStationTapped()

        #expect(
          model.mainContainerNavigationCoordinator.appMode
            == .broadcasting(stationId: "test-station-id")
        )
        #expect(model.mainContainerNavigationCoordinator.path.isEmpty)
      }
    }
  }

  // MARK: - My Station Button Visibility Tests

  @Test
  func testMyStationButtonVisibleIsFalseInitially() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let model = ContactPageModel()

    #expect(!model.myStationButtonVisible)
    #expect(model.stationIdToTransitionTo == nil)
  }

  @Test
  func testMyStationButtonVisibleIsFalseWhenUserHasNoStations() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.fetchUserStations = { _ in [] }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()

      #expect(!model.myStationButtonVisible)
      #expect(model.stationIdToTransitionTo == nil)
    }
  }

  @Test
  func testMyStationButtonVisibleIsTrueWhenUserHasStations() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockStations = [
      Station.mockWith(id: "station-1", name: "First Station"),
      Station.mockWith(id: "station-2", name: "Second Station"),
    ]

    await withDependencies {
      $0.api.fetchUserStations = { _ in mockStations }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()

      #expect(model.myStationButtonVisible)
      #expect(model.stationIdToTransitionTo == "station-1")
    }
  }

  @Test
  func testStationIdToTransitionToIsFirstStationId() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockStations = [
      Station.mockWith(id: "first-station-id", name: "First Station"),
      Station.mockWith(id: "second-station-id", name: "Second Station"),
      Station.mockWith(id: "third-station-id", name: "Third Station"),
    ]

    await withDependencies {
      $0.api.fetchUserStations = { _ in mockStations }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()

      #expect(model.stationIdToTransitionTo == "first-station-id")
    }
  }

  @Test
  func testOnMyStationTappedWithSingleStationSwitchesToBroadcastMode() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockStations = [
      Station.mockWith(id: "single-station-id", name: "My Only Station")
    ]

    await withDependencies {
      $0.api.fetchUserStations = { _ in mockStations }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()
      await model.onMyStationTapped()

      #expect(
        model.mainContainerNavigationCoordinator.appMode
          == .broadcasting(stationId: "single-station-id")
      )
      #expect(model.mainContainerNavigationCoordinator.path.isEmpty)
    }
  }

  @Test
  func testOnMyStationTappedWithMultipleStationsNavigatesToChooseStationPage() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockStations = [
      Station.mockWith(id: "station-1", name: "First Station"),
      Station.mockWith(id: "station-2", name: "Second Station"),
      Station.mockWith(id: "station-3", name: "Third Station"),
    ]

    await withDependencies {
      $0.api.fetchUserStations = { _ in mockStations }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()
      await model.onMyStationTapped()

      #expect(model.mainContainerNavigationCoordinator.path.count == 1)

      if case .chooseStationToBroadcastPage(let chooseModel) = model
        .mainContainerNavigationCoordinator
        .path.first
      {
        #expect(chooseModel.stations.count == 3)
        #expect(chooseModel.stations[0].id == "station-1")
        #expect(chooseModel.stations[1].id == "station-2")
        #expect(chooseModel.stations[2].id == "station-3")
      } else {
        Issue.record("Expected navigation to choose station page")
      }
    }
  }

  @Test
  func testOnMyStationTappedWithTwoStationsNavigatesToChooseStationPage() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockStations = [
      Station.mockWith(id: "station-a", name: "Station A"),
      Station.mockWith(id: "station-b", name: "Station B"),
    ]

    await withDependencies {
      $0.api.fetchUserStations = { _ in mockStations }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()
      await model.onMyStationTapped()

      #expect(model.mainContainerNavigationCoordinator.path.count == 1)

      if case .chooseStationToBroadcastPage(let chooseModel) = model
        .mainContainerNavigationCoordinator
        .path.first
      {
        #expect(chooseModel.stations.count == 2)
      } else {
        Issue.record("Expected navigation to choose station page")
      }
    }
  }

  // MARK: - My Station Button Label Tests

  @Test
  func testMyStationButtonLabelReturnsSingularWhenOneStation() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockStations = [Station.mockWith(id: "station-1", name: "My Only Station")]

    await withDependencies {
      $0.api.fetchUserStations = { _ in mockStations }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()

      #expect(model.myStationButtonLabel == "My Station")
    }
  }

  @Test
  func testMyStationButtonLabelReturnsPluralWhenMultipleStations() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockStations = [
      Station.mockWith(id: "station-1", name: "First Station"),
      Station.mockWith(id: "station-2", name: "Second Station"),
    ]

    await withDependencies {
      $0.api.fetchUserStations = { _ in mockStations }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()

      #expect(model.myStationButtonLabel == "My Stations")
    }
  }

  // MARK: - Analytics Tests

  @Test
  func testOnMyStationTappedWithSingleStationTracksAnalyticsEvent() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockStation = Station.mockWith(id: "my-station-id", name: "My Station")
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.api.fetchUserStations = { _ in [mockStation] }
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()
      await model.onMyStationTapped()

      let events = capturedEvents.value
      let hasViewedBroadcastEvent = events.contains { event in
        if case .viewedBroadcastScreen(let stationId, let stationName, _) = event {
          return stationId == "my-station-id" && stationName == "My Station"
        }
        return false
      }
      #expect(hasViewedBroadcastEvent)
    }
  }

  @Test
  func testOnMyStationTappedWithMultipleStationsDoesNotTrackAnalyticsEvent() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockStations = [
      Station.mockWith(id: "station-1", name: "Station 1"),
      Station.mockWith(id: "station-2", name: "Station 2"),
    ]
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.api.fetchUserStations = { _ in mockStations }
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()
      await model.onMyStationTapped()

      let events = capturedEvents.value
      let hasViewedBroadcastEvent = events.contains { event in
        if case .viewedBroadcastScreen = event {
          return true
        }
        return false
      }
      #expect(!hasViewedBroadcastEvent)
    }
  }

  // MARK: - Broadcast Mode Tests

  @Test
  func testIsInBroadcastModeReturnsFalseWhenListening() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .listening

    let model = ContactPageModel()

    #expect(!model.isInBroadcastMode)
  }

  @Test
  func testIsInBroadcastModeReturnsTrueWhenBroadcasting() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")

    let model = ContactPageModel()

    #expect(model.isInBroadcastMode)
  }

  @Test
  func testSwitchToListeningModeSwitchesMode() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")

    let model = ContactPageModel()
    model.switchToListeningMode()

    #expect(coordinator.appMode == .listening)
  }

  @Test
  func testLogoutResetsAppModeToListening() async {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")

    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "John",
      lastName: "Doe",
      email: "john@example.com",
      role: "user"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let stationPlayerMock = StationPlayerMock()

    await withDependencies {
      $0.api.unregisterDevice = { _, _ in }
      $0.analytics = .noop
    } operation: {
      let model = ContactPageModel(stationPlayer: stationPlayerMock)
      await model.onLogOutTapped()
    }

    #expect(coordinator.appMode == .listening)
  }

  // MARK: - Sign Out Edge Cases

  @Test
  func testOnLogOutTappedSkipsServerCallWhenDeviceNotRegistered() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt-abc")
    @Shared(.registeredDeviceId) var registeredDeviceId = String?.none

    let unregisterCallCount = LockIsolated(0)

    await withDependencies {
      $0.api.unregisterDevice = { _, _ in
        unregisterCallCount.withValue { $0 += 1 }
      }
      $0.analytics = .noop
    } operation: {
      let model = ContactPageModel(stationPlayer: StationPlayerMock())
      await model.onLogOutTapped()
    }

    #expect(unregisterCallCount.value == 0)
    #expect(!auth.isLoggedIn)
  }

  @Test
  func testOnLogOutTappedStillClearsLocalStateWhenServerCallFails() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt-abc")
    @Shared(.registeredDeviceId) var registeredDeviceId = "device-xyz"

    struct UnregisterError: Error {}

    await withDependencies {
      $0.api.unregisterDevice = { _, _ in throw UnregisterError() }
      $0.analytics = .noop
    } operation: {
      let model = ContactPageModel(stationPlayer: StationPlayerMock())
      await model.onLogOutTapped()
    }

    #expect(!auth.isLoggedIn)
    #expect(registeredDeviceId == nil)
  }

  @Test
  func testMyStationButtonHiddenWhenInBroadcastMode() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")

    let mockStations = [Station.mockWith(id: "station-123", name: "My Station")]

    await withDependencies {
      $0.api.fetchUserStations = { _ in mockStations }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()

      #expect(!model.myStationButtonVisible)
    }
  }
}
