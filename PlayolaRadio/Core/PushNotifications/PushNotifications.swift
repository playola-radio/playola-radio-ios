//
//  PushNotifications.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/15/25.
//

import Dependencies
import DependenciesMacros
import Foundation
import Sharing
import UIKit
import UserNotifications

enum NotificationPayload {
  static func stationId(from userInfo: [AnyHashable: Any]) -> String? {
    userInfo["stationId"] as? String
  }
}

@DependencyClient
struct PushNotificationsClient: Sendable {
  /// Schedule a local notification
  /// - Parameters:
  ///   - identifier: Unique identifier for the notification
  ///   - title: Notification title
  ///   - body: Notification body
  ///   - date: When to deliver the notification
  var scheduleNotification:
    @Sendable (
      _ identifier: String,
      _ title: String,
      _ body: String,
      _ date: Date
    ) async throws -> Void

  /// Request notification permissions from the user
  var requestAuthorization: @Sendable () async throws -> Bool

  /// Cancel a specific notification
  var cancelNotification: @Sendable (_ identifier: String) async -> Void

  /// Cancel all pending notifications
  var cancelAllNotifications: @Sendable () async -> Void

  /// Register for remote notifications with APNs
  var registerForRemoteNotifications: @Sendable () async -> Void

  /// Handle device token received from APNs and register with server
  /// - Parameter deviceToken: The raw device token data from APNs
  var handleDeviceToken: @Sendable (_ deviceToken: Data) async -> Void

  /// Handle notification tap - extracts station ID and plays it
  /// - Parameter userInfo: The notification payload
  var handleNotificationTap: @Sendable (_ userInfo: [AnyHashable: Any]) async -> Void
}

extension PushNotificationsClient: DependencyKey {
  static let liveValue: Self = Self(
    scheduleNotification: { identifier, title, body, date in
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default

      let calendar = Calendar.current
      let components = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute, .second],
        from: date
      )
      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

      let request = UNNotificationRequest(
        identifier: identifier,
        content: content,
        trigger: trigger
      )

      try await UNUserNotificationCenter.current().add(request)
    },
    requestAuthorization: {
      try await UNUserNotificationCenter.current().requestAuthorization(options: [
        .alert, .sound, .badge,
      ])
    },
    cancelNotification: { identifier in
      UNUserNotificationCenter.current().removePendingNotificationRequests(
        withIdentifiers: [identifier])
    },
    cancelAllNotifications: {
      UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    },
    registerForRemoteNotifications: {
      await MainActor.run {
        UIApplication.shared.registerForRemoteNotifications()
      }
    },
    handleDeviceToken: { deviceToken in
      @Dependency(\.api) var api
      @Shared(.auth) var auth
      @Shared(.registeredDeviceId) var registeredDeviceId

      let hexToken = deviceToken.map { String(format: "%02x", $0) }.joined()
      let appVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

      print("📱 Device token received: \(hexToken.prefix(20))...")

      guard let jwt = auth.jwt else {
        print("📱 No JWT available, skipping device registration")
        return
      }

      print("📱 Registering device with server...")
      do {
        let device = try await api.registerDevice(jwt, hexToken, "ios", appVersion)
        print("📱 Device registered successfully: \(device.id)")
        await MainActor.run {
          $registeredDeviceId.withLock { $0 = device.id }
        }
      } catch {
        print("📱 Failed to register device: \(error)")
      }
    },
    handleNotificationTap: { userInfo in
      @Shared(.stationLists) var stationLists

      guard let stationId = NotificationPayload.stationId(from: userInfo) else {
        return
      }

      let allStations = stationLists.flatMap { $0.stationItems(includeHidden: true) }
        .map { $0.anyStation }

      guard let station = allStations.first(where: { $0.id == stationId }) else {
        return
      }

      await MainActor.run {
        StationPlayer.shared.play(station: station)
      }
    }
  )
}

extension PushNotificationsClient: TestDependencyKey {
  static let testValue = PushNotificationsClient()
}

extension DependencyValues {
  var pushNotifications: PushNotificationsClient {
    get { self[PushNotificationsClient.self] }
    set { self[PushNotificationsClient.self] = newValue }
  }
}
