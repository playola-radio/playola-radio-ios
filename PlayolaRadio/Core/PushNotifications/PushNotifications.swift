//
//  PushNotifications.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/15/25.
//

import Dependencies
import DependenciesMacros
import Foundation
import UserNotifications

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
}

extension PushNotificationsClient: DependencyKey {
  static let liveValue: Self = {
    return Self(
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
      }
    )
  }()
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
