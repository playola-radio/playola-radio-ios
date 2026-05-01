//
//  ContactPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/29/25.
//
import ConcurrencyExtras
import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class ContactPageTests: XCTestCase {
  override static func setUp() {
    super.setUp()
    @Shared(.auth) var auth
  }

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

    XCTAssertEqual(stationPlayerMock.stopCalledCount, 1)
    XCTAssertEqual(unregisterCalls.value.count, 1)
    XCTAssertEqual(unregisterCalls.value.first?.0, "test-jwt")
    XCTAssertEqual(unregisterCalls.value.first?.1, "device-xyz")
    XCTAssertEqual(resetCallCount.value, 1)
    XCTAssertFalse(auth.isLoggedIn)
    XCTAssertNil(registeredDeviceId)
    XCTAssertTrue(userLikes.isEmpty)
    XCTAssertTrue(pendingLikeOperations.isEmpty)
    XCTAssertTrue(airings.isEmpty)
    XCTAssertTrue(lastNotificationSentAt.isEmpty)
    XCTAssertFalse(isBroadcaster)
    XCTAssertNil(UserDefaults.standard.object(forKey: "analytics_session_paused_at"))
  }

  func testNameDisplay_ReturnsFullNameWhenLoggedIn() {
    let loggedInUser = LoggedInUser(
      id: "123",
      firstName: "Jane",
      lastName: "Smith",
      email: "jane@example.com",
      role: "user"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = ContactPageModel()

    XCTAssertEqual(model.name, "Jane Smith")
  }

  func testNameDisplay_ReturnsAnonymousWhenNotLoggedIn() {
    @Shared(.auth) var auth = Auth()

    let model = ContactPageModel()

    XCTAssertEqual(model.name, "Anonymous")
  }

  func testEmailDisplay_ReturnsEmailWhenLoggedIn() {
    let loggedInUser = LoggedInUser(
      id: "456",
      firstName: "Bob",
      lastName: "Johnson",
      email: "bob@test.com",
      role: "admin"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    let model = ContactPageModel()

    XCTAssertEqual(model.email, "bob@test.com")
  }

  func testEmailDisplay_ReturnsUnknownWhenNotLoggedIn() {
    @Shared(.auth) var auth = Auth()

    let model = ContactPageModel()

    XCTAssertEqual(model.email, "Unknown")
  }

  func testOnLikedSongsTapped_NavigatesToLikedSongsPage() {
    let model = ContactPageModel()

    // Verify initial navigation state
    XCTAssertTrue(model.mainContainerNavigationCoordinator.path.isEmpty)

    // Tap liked songs button
    model.onLikedSongsTapped()

    // Verify navigation occurred
    XCTAssertEqual(model.mainContainerNavigationCoordinator.path.count, 1)

    if case .likedSongsPage = model.mainContainerNavigationCoordinator.path.first {
      // Successfully navigated to liked songs page
    } else {
      XCTFail("Expected navigation to liked songs page")
    }
  }

  func testOnNotificationsTapped_NavigatesToNotificationsSettingsPage() {
    let model = ContactPageModel()

    // Verify initial navigation state
    XCTAssertTrue(model.mainContainerNavigationCoordinator.path.isEmpty)

    // Tap notifications button
    model.onNotificationsTapped()

    // Verify navigation occurred
    XCTAssertEqual(model.mainContainerNavigationCoordinator.path.count, 1)

    if case .notificationsSettingsPage = model.mainContainerNavigationCoordinator.path.first {
      // Successfully navigated to notifications settings page
    } else {
      XCTFail("Expected navigation to notifications settings page")
    }
  }

  func testOnMyStationTapped_SwitchesToBroadcastMode() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth
      $auth.withLock { $0 = Auth(jwt: "test-jwt") }
      let mockStations = [Station.mockWith(id: "test-station-id")]

      await withDependencies {
        $0.api.fetchUserStations = { _ in mockStations }
        $0.analytics.track = { @Sendable _ in }
      } operation: {
        let model = ContactPageModel()

        await model.onViewAppeared()

        XCTAssertEqual(model.mainContainerNavigationCoordinator.appMode, .listening)

        await model.onMyStationTapped()

        XCTAssertEqual(
          model.mainContainerNavigationCoordinator.appMode,
          .broadcasting(stationId: "test-station-id")
        )
        XCTAssertTrue(model.mainContainerNavigationCoordinator.path.isEmpty)
      }
    }
  }

  // MARK: - My Station Button Visibility Tests

  func testMyStationButtonVisible_IsFalseInitially() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let model = ContactPageModel()

    XCTAssertFalse(model.myStationButtonVisible)
    XCTAssertNil(model.stationIdToTransitionTo)
  }

  func testMyStationButtonVisible_IsFalseWhenUserHasNoStations() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.fetchUserStations = { _ in [] }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()

      XCTAssertFalse(model.myStationButtonVisible)
      XCTAssertNil(model.stationIdToTransitionTo)
    }
  }

  func testMyStationButtonVisible_IsTrueWhenUserHasStations() async {
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

      XCTAssertTrue(model.myStationButtonVisible)
      XCTAssertEqual(model.stationIdToTransitionTo, "station-1")
    }
  }

  func testStationIdToTransitionTo_IsFirstStationId() async {
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

      XCTAssertEqual(model.stationIdToTransitionTo, "first-station-id")
    }
  }

  func testOnMyStationTapped_WithSingleStation_SwitchesToBroadcastMode() async {
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

      XCTAssertEqual(
        model.mainContainerNavigationCoordinator.appMode,
        .broadcasting(stationId: "single-station-id")
      )
      XCTAssertTrue(model.mainContainerNavigationCoordinator.path.isEmpty)
    }
  }

  func testOnMyStationTapped_WithMultipleStations_NavigatesToChooseStationPage() async {
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

      XCTAssertEqual(model.mainContainerNavigationCoordinator.path.count, 1)

      if case .chooseStationToBroadcastPage(let chooseModel) = model
        .mainContainerNavigationCoordinator
        .path.first
      {
        XCTAssertEqual(chooseModel.stations.count, 3)
        XCTAssertEqual(chooseModel.stations[0].id, "station-1")
        XCTAssertEqual(chooseModel.stations[1].id, "station-2")
        XCTAssertEqual(chooseModel.stations[2].id, "station-3")
      } else {
        XCTFail("Expected navigation to choose station page")
      }
    }
  }

  func testOnMyStationTapped_WithTwoStations_NavigatesToChooseStationPage() async {
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

      XCTAssertEqual(model.mainContainerNavigationCoordinator.path.count, 1)

      if case .chooseStationToBroadcastPage(let chooseModel) = model
        .mainContainerNavigationCoordinator
        .path.first
      {
        XCTAssertEqual(chooseModel.stations.count, 2)
      } else {
        XCTFail("Expected navigation to choose station page")
      }
    }
  }

  // MARK: - My Station Button Label Tests

  func testMyStationButtonLabel_ReturnsSingularWhenOneStation() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let mockStations = [Station.mockWith(id: "station-1", name: "My Only Station")]

    await withDependencies {
      $0.api.fetchUserStations = { _ in mockStations }
    } operation: {
      let model = ContactPageModel()

      await model.onViewAppeared()

      XCTAssertEqual(model.myStationButtonLabel, "My Station")
    }
  }

  func testMyStationButtonLabel_ReturnsPluralWhenMultipleStations() async {
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

      XCTAssertEqual(model.myStationButtonLabel, "My Stations")
    }
  }

  // MARK: - Analytics Tests

  func testOnMyStationTapped_WithSingleStation_TracksAnalyticsEvent() async {
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
      XCTAssertTrue(hasViewedBroadcastEvent)
    }
  }

  func testOnMyStationTapped_WithMultipleStations_DoesNotTrackAnalyticsEvent() async {
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
      XCTAssertFalse(hasViewedBroadcastEvent)
    }
  }

  // MARK: - Broadcast Mode Tests

  func testIsInBroadcastModeReturnsFalseWhenListening() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .listening

    let model = ContactPageModel()

    XCTAssertFalse(model.isInBroadcastMode)
  }

  func testIsInBroadcastModeReturnsTrueWhenBroadcasting() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")

    let model = ContactPageModel()

    XCTAssertTrue(model.isInBroadcastMode)
  }

  func testSwitchToListeningModeSwitchesMode() {
    @Shared(.mainContainerNavigationCoordinator)
    var coordinator = MainContainerNavigationCoordinator()
    coordinator.appMode = .broadcasting(stationId: "station-123")

    let model = ContactPageModel()
    model.switchToListeningMode()

    XCTAssertEqual(coordinator.appMode, .listening)
  }

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
    let model = ContactPageModel(stationPlayer: stationPlayerMock)

    await withDependencies {
      $0.api.unregisterDevice = { _, _ in }
      $0.analytics = .noop
    } operation: {
      await model.onLogOutTapped()
    }

    XCTAssertEqual(coordinator.appMode, .listening)
  }

  // MARK: - Sign Out Edge Cases

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

    XCTAssertEqual(unregisterCallCount.value, 0)
    XCTAssertFalse(auth.isLoggedIn)
  }

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

    XCTAssertFalse(auth.isLoggedIn)
    XCTAssertNil(registeredDeviceId)
  }

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

      XCTAssertFalse(model.myStationButtonVisible)
    }
  }
}
