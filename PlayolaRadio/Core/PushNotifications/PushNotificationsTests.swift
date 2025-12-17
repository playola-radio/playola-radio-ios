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
}
