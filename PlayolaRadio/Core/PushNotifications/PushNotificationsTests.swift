//
//  PushNotificationsTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/17/25.
//

import ConcurrencyExtras
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct PushNotificationsTests {

  // MARK: - registerForRemoteNotifications

  @Test
  func testRegisterForRemoteNotificationsRequestsAuthorization() async throws {
    let authorizationRequested = LockIsolated(false)

    try await withDependencies {
      $0.pushNotifications.requestAuthorization = {
        authorizationRequested.setValue(true)
        return true
      }
      $0.pushNotifications.registerForRemoteNotifications = {}
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      _ = try await pushNotifications.requestAuthorization()
    }

    #expect(authorizationRequested.value)
  }

  @Test
  func testRegisterForRemoteNotificationsCallsUIApplicationRegister() async throws {
    let registerCalled = LockIsolated(false)

    await withDependencies {
      $0.pushNotifications.registerForRemoteNotifications = {
        registerCalled.setValue(true)
      }
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      await pushNotifications.registerForRemoteNotifications()
    }

    #expect(registerCalled.value)
  }

  // MARK: - Device Token Handling

  @Test
  func testDeviceTokenConvertedToHexString() {
    let tokenBytes: [UInt8] = [0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56, 0x78, 0x90]
    let tokenData = Data(tokenBytes)

    let hexString = tokenData.map { String(format: "%02x", $0) }.joined()

    #expect(hexString == "abcdef1234567890")
  }

  @Test
  func testHandleDeviceTokenCallsAPIWhenLoggedIn() async throws {
    let capturedToken = LockIsolated<String?>(nil)
    let capturedPlatform = LockIsolated<String?>(nil)
    let capturedAppVersion = LockIsolated<String?>(nil)

    await withDependencies {
      $0.pushNotifications.handleDeviceToken = { deviceToken in
        capturedToken.setValue(deviceToken.map { String(format: "%02x", $0) }.joined())
        capturedPlatform.setValue("ios")
        capturedAppVersion.setValue("1.0.0")
      }
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      let tokenBytes: [UInt8] = [0xAB, 0xCD, 0xEF, 0x12]
      let tokenData = Data(tokenBytes)
      await pushNotifications.handleDeviceToken(tokenData)
    }

    #expect(capturedToken.value == "abcdef12")
    #expect(capturedPlatform.value == "ios")
    #expect(capturedAppVersion.value == "1.0.0")
  }

  // MARK: - Notification Payload Parsing

  @Test
  func testParseNotificationPayloadExtractsStationId() {
    let userInfo: [String: any Sendable] = [
      "stationId": "test-station-123"
    ]

    let stationId = NotificationPayload.stationId(from: userInfo)

    #expect(stationId == "test-station-123")
  }

  @Test
  func testParseNotificationPayloadReturnsNilWhenNoStationId() {
    let userInfo: [String: any Sendable] = [:]

    let stationId = NotificationPayload.stationId(from: userInfo)

    #expect(stationId == nil)
  }

  // MARK: - Notification Response Handling

  @Test
  func testHandleNotificationResponsePlaysStation() async {
    let playedStationId = LockIsolated<String?>(nil)

    await withDependencies {
      $0.pushNotifications.handleNotificationTap = { userInfo in
        if let stationId = userInfo["stationId"] as? String {
          playedStationId.setValue(stationId)
        }
      }
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      let userInfo: [String: any Sendable] = ["stationId": "station-abc"]
      await pushNotifications.handleNotificationTap(userInfo)
    }

    #expect(playedStationId.value == "station-abc")
  }

  // MARK: - Support Notification Badge Handling

  @Test
  func testHandleSupportNotificationBadgeSetsCountFromPayload() async {
    @Shared(.unreadSupportCount) var unreadSupportCount = 0
    let capturedBadgeCount = LockIsolated<Int?>(nil)

    await withDependencies {
      $0.pushNotifications.setBadgeCount = { count in
        capturedBadgeCount.setValue(count)
      }
      $0.pushNotifications.handleSupportNotificationBadge = { badgeFromPayload in
        await PushNotificationsClient.liveValue.handleSupportNotificationBadge(badgeFromPayload)
      }
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      await pushNotifications.handleSupportNotificationBadge(badgeFromPayload: 5)
    }

    #expect(unreadSupportCount == 5)
    #expect(capturedBadgeCount.value == 5)
  }

  @Test
  func testHandleSupportNotificationBadgeIncrementsWhenNoPayload() async {
    @Shared(.unreadSupportCount) var unreadSupportCount = 2
    let capturedBadgeCount = LockIsolated<Int?>(nil)

    await withDependencies {
      $0.pushNotifications.setBadgeCount = { count in
        capturedBadgeCount.setValue(count)
      }
      $0.pushNotifications.handleSupportNotificationBadge = { badgeFromPayload in
        await PushNotificationsClient.liveValue.handleSupportNotificationBadge(badgeFromPayload)
      }
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      await pushNotifications.handleSupportNotificationBadge(badgeFromPayload: nil)
    }

    #expect(unreadSupportCount == 3)
    #expect(capturedBadgeCount.value == 3)
  }

  @Test
  func testClearSupportBadgeSetsCountToZero() async {
    @Shared(.unreadSupportCount) var unreadSupportCount = 5
    let capturedBadgeCount = LockIsolated<Int?>(nil)

    await withDependencies {
      $0.pushNotifications.setBadgeCount = { count in
        capturedBadgeCount.setValue(count)
      }
      $0.pushNotifications.clearSupportBadge = {
        await PushNotificationsClient.liveValue.clearSupportBadge()
      }
    } operation: {
      @Dependency(\.pushNotifications) var pushNotifications
      await pushNotifications.clearSupportBadge()
    }

    #expect(unreadSupportCount == 0)
    #expect(capturedBadgeCount.value == 0)
  }

  // MARK: - Support Message Notification Tap

  @Test
  func testHandleNotificationTapPostsRefreshWhenSupportMessageAndOnSupportPage() async {
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    // Simulate being on the support page
    let supportModel = SupportPageModel()
    navCoordinator.path.append(.supportPage(supportModel))

    let refreshNotificationPosted = LockIsolated(false)
    let observer = NotificationCenter.default.addObserver(
      forName: .refreshSupportMessages,
      object: nil,
      queue: .main
    ) { _ in
      refreshNotificationPosted.setValue(true)
    }

    defer { NotificationCenter.default.removeObserver(observer) }

    let userInfo: [String: any Sendable] = [
      "type": "support_message",
      "conversationId": "conv-123",
    ]
    await PushNotificationsClient.liveValue.handleNotificationTap(userInfo)

    #expect(refreshNotificationPosted.value)
  }
}
