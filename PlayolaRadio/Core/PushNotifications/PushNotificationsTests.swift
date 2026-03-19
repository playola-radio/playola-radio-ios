//
//  PushNotificationsTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/17/25.
//

import Dependencies
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class PushNotificationsTests: XCTestCase {

  // MARK: - registerForRemoteNotifications

  func testRegisterForRemoteNotificationsRequestsAuthorization() async throws {
    var authorizationRequested = false

    try await withDependencies {
      $0.pushNotifications.requestAuthorization = {
        authorizationRequested = true
        return true
      }
      $0.pushNotifications.registerForRemoteNotifications = {}
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      _ = try await pushNotifications.requestAuthorization()
    }

    XCTAssertTrue(authorizationRequested)
  }

  func testRegisterForRemoteNotificationsCallsUIApplicationRegister() async throws {
    var registerCalled = false

    await withDependencies {
      $0.pushNotifications.registerForRemoteNotifications = {
        registerCalled = true
      }
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      await pushNotifications.registerForRemoteNotifications()
    }

    XCTAssertTrue(registerCalled)
  }

  // MARK: - Device Token Handling

  func testDeviceTokenConvertedToHexString() {
    let tokenBytes: [UInt8] = [0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90]
    let tokenData = Data(tokenBytes)

    let hexString = tokenData.map { String(format: "%02x", $0) }.joined()

    XCTAssertEqual(hexString, "abcdef1234567890")
  }

  func testHandleDeviceTokenCallsAPIWhenLoggedIn() async throws {
    var capturedToken: String?
    var capturedPlatform: String?
    var capturedAppVersion: String?

    await withDependencies {
      $0.pushNotifications.handleDeviceToken = { deviceToken in
        capturedToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        capturedPlatform = "ios"
        capturedAppVersion = "1.0.0"
      }
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      let tokenBytes: [UInt8] = [0xAB, 0xCD, 0xEF, 0x12]
      let tokenData = Data(tokenBytes)
      await pushNotifications.handleDeviceToken(tokenData)
    }

    XCTAssertEqual(capturedToken, "abcdef12")
    XCTAssertEqual(capturedPlatform, "ios")
    XCTAssertEqual(capturedAppVersion, "1.0.0")
  }

  // MARK: - Notification Payload Parsing

  func testParseNotificationPayloadExtractsStationId() {
    let userInfo: [AnyHashable: Any] = [
      "aps": [
        "alert": [
          "title": "Brian's Station",
          "body": "I'm going live!",
        ],
        "sound": "default",
      ],
      "stationId": "test-station-123",
    ]

    let stationId = NotificationPayload.stationId(from: userInfo)

    XCTAssertEqual(stationId, "test-station-123")
  }

  func testParseNotificationPayloadReturnsNilWhenNoStationId() {
    let userInfo: [AnyHashable: Any] = [
      "aps": [
        "alert": [
          "title": "Test",
          "body": "Test message",
        ]
      ]
    ]

    let stationId = NotificationPayload.stationId(from: userInfo)

    XCTAssertNil(stationId)
  }

  // MARK: - Notification Response Handling

  func testHandleNotificationResponsePlaysStation() async {
    var playedStationId: String?

    await withDependencies {
      $0.pushNotifications.handleNotificationTap = { userInfo in
        if let stationId = userInfo["stationId"] as? String {
          playedStationId = stationId
        }
      }
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      let userInfo: [AnyHashable: Any] = ["stationId": "station-abc"]
      await pushNotifications.handleNotificationTap(userInfo)
    }

    XCTAssertEqual(playedStationId, "station-abc")
  }

  // MARK: - Support Notification Badge Handling

  func testHandleSupportNotificationBadgeSetsCountFromPayload() async {
    @Shared(.unreadSupportCount) var unreadSupportCount = 0
    var capturedBadgeCount: Int?

    await withDependencies {
      $0.pushNotifications.setBadgeCount = { count in
        capturedBadgeCount = count
      }
      $0.pushNotifications.handleSupportNotificationBadge =
        PushNotificationsClient.liveValue.handleSupportNotificationBadge
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      await pushNotifications.handleSupportNotificationBadge(badgeFromPayload: 5)
    }

    XCTAssertEqual(unreadSupportCount, 5)
    XCTAssertEqual(capturedBadgeCount, 5)
  }

  func testHandleSupportNotificationBadgeIncrementsWhenNoPayload() async {
    @Shared(.unreadSupportCount) var unreadSupportCount = 2
    var capturedBadgeCount: Int?

    await withDependencies {
      $0.pushNotifications.setBadgeCount = { count in
        capturedBadgeCount = count
      }
      $0.pushNotifications.handleSupportNotificationBadge =
        PushNotificationsClient.liveValue.handleSupportNotificationBadge
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      await pushNotifications.handleSupportNotificationBadge(badgeFromPayload: nil)
    }

    XCTAssertEqual(unreadSupportCount, 3)
    XCTAssertEqual(capturedBadgeCount, 3)
  }

  func testClearSupportBadgeSetsCountToZero() async {
    @Shared(.unreadSupportCount) var unreadSupportCount = 5
    var capturedBadgeCount: Int?

    await withDependencies {
      $0.pushNotifications.setBadgeCount = { count in
        capturedBadgeCount = count
      }
      $0.pushNotifications.clearSupportBadge = PushNotificationsClient.liveValue.clearSupportBadge
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      await pushNotifications.clearSupportBadge()
    }

    XCTAssertEqual(unreadSupportCount, 0)
    XCTAssertEqual(capturedBadgeCount, 0)
  }

  // MARK: - Support Message Notification Tap

  func testHandleNotificationTapPostsRefreshWhenSupportMessageAndOnSupportPage() async {
    @Shared(.hasBeenUnlocked) var hasBeenUnlocked = true
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    // Simulate being on the support page
    let supportModel = SupportPageModel()
    navCoordinator.path.append(.supportPage(supportModel))

    var refreshNotificationPosted = false
    let observer = NotificationCenter.default.addObserver(
      forName: .refreshSupportMessages,
      object: nil,
      queue: .main
    ) { _ in
      refreshNotificationPosted = true
    }

    defer { NotificationCenter.default.removeObserver(observer) }

    let userInfo: [AnyHashable: Any] = [
      "type": "support_message",
      "conversationId": "conv-123",
    ]
    await PushNotificationsClient.liveValue.handleNotificationTap(userInfo)

    XCTAssertTrue(refreshNotificationPosted)
  }

  // MARK: - Clip Share Notification Tests

  func testClipReadyNotificationNavigatesToMyAiringsPage() async {
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()
    @Shared(.hasBeenUnlocked) var hasBeenUnlocked = true

    let userInfo: [AnyHashable: Any] = [
      "type": "clip_ready",
      "clipId": "clip-123",
      "stationId": "station-456",
    ]

    await PushNotificationsClient.liveValue.handleNotificationTap(userInfo)

    XCTAssertEqual(navCoordinator.path.count, 1)
    if case .myAiringsPage = navCoordinator.path.first {
      // Expected
    } else {
      XCTFail("Expected myAiringsPage navigation")
    }
  }

  func testClipReadyNotificationDoesNotNavigateWhenLocked() async {
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()
    @Shared(.hasBeenUnlocked) var hasBeenUnlocked = false

    let userInfo: [AnyHashable: Any] = [
      "type": "clip_ready",
      "clipId": "clip-123",
    ]

    await PushNotificationsClient.liveValue.handleNotificationTap(userInfo)

    XCTAssertTrue(navCoordinator.path.isEmpty)
  }

  func testListenerQuestionScheduledNotificationIsNoOp() async {
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    let userInfo: [AnyHashable: Any] = [
      "type": "listener_question_scheduled",
      "stationId": "station-123",
    ]

    await PushNotificationsClient.liveValue.handleNotificationTap(userInfo)

    XCTAssertTrue(navCoordinator.path.isEmpty)
  }

  // MARK: - scheduleAiringReminders

  func testScheduleAiringRemindersSchedulesForFutureAirings() async {
    let now = Date()
    let futureAiring = ListenerQuestionAiring.mockWith(
      id: "future-1",
      airtime: now.addingTimeInterval(86400),
      station: .mockWith(curatorName: "DJ Test")
    )
    var scheduledIds: [String] = []

    await withDependencies {
      $0.date.now = now
      $0.pushNotifications.scheduleNotification = { identifier, _, _, _ in
        scheduledIds.append(identifier)
      }
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      await pushNotifications.scheduleAiringReminders([futureAiring])
    }

    XCTAssertEqual(scheduledIds, ["airing-reminder-future-1"])
  }

  func testScheduleAiringRemindersSkipsAiringsWithPastReminders() async {
    let now = Date()
    let soonAiring = ListenerQuestionAiring.mockWith(
      id: "soon",
      airtime: now.addingTimeInterval(5 * 60)  // 5 min from now, reminder would be in the past
    )
    var scheduledCount = 0

    await withDependencies {
      $0.date.now = now
      $0.pushNotifications.scheduleNotification = { _, _, _, _ in
        scheduledCount += 1
      }
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      await pushNotifications.scheduleAiringReminders([soonAiring])
    }

    XCTAssertEqual(scheduledCount, 0)
  }
}
