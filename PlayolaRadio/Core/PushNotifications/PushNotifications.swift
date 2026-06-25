//
//  PushNotifications.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/15/25.
//

import Dependencies
import DependenciesMacros
import Foundation
import IssueReporting
import Sharing
import UIKit
import UserNotifications

enum NotificationPayload {
  static func stationId(from userInfo: [String: any Sendable]) -> String? {
    userInfo["stationId"] as? String
  }

  static func notificationType(from userInfo: [String: any Sendable]) -> String? {
    userInfo["type"] as? String
  }
}

extension [AnyHashable: Any] {
  /// Extracts an APNs userInfo dict into a Sendable payload that can cross actor boundaries.
  ///
  /// Intentionally narrowed to primitive leaf values (String/Int/Double/Bool) keyed by String.
  /// Non-string keys, nested dictionaries, arrays, and any other types are silently dropped.
  /// If a future APNs payload adds nested structure we need to read, extend this helper to
  /// handle the new shape explicitly rather than loosening the type guards.
  func sendablePayload() -> [String: any Sendable] {
    var result: [String: any Sendable] = [:]
    for (key, value) in self {
      guard let keyString = key as? String else { continue }
      if let value = value as? String {
        result[keyString] = value
      } else if let value = value as? Int {
        result[keyString] = value
      } else if let value = value as? Double {
        result[keyString] = value
      } else if let value = value as? Bool {
        result[keyString] = value
      }
    }
    return result
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
  var handleNotificationTap: @Sendable (_ userInfo: [String: any Sendable]) async -> Void

  /// Handle the targeted "you won" giveaway push. Flips (or creates) the winning participation in
  /// durable shared state; the MainContainer arbiter presents the winner sheet. Idempotent.
  /// - Parameter userInfo: The notification payload
  var handleGiveawayWinnerPush: @Sendable (_ userInfo: [String: any Sendable]) async -> Void

  /// Handle the owner-only "winner pending" giveaway push: the owner can record a congrats. Writes a
  /// pending `CongratsAction` into durable shared state; the MainContainer arbiter presents the
  /// congrats sheet. Never clobbers an in-progress (non-terminal) action.
  /// - Parameter userInfo: The notification payload
  var handleGiveawayWinnerPendingPush: @Sendable (_ userInfo: [String: any Sendable]) async -> Void

  /// Set the app icon badge count
  /// - Parameter count: The badge count to display
  var setBadgeCount: @Sendable (_ count: Int) async -> Void

  /// Handle support notification badge - updates shared state and app icon badge
  /// - Parameter badgeFromPayload: Badge count from notification payload, or nil to increment
  var handleSupportNotificationBadge: @Sendable (_ badgeFromPayload: Int?) async -> Void

  /// Clear support badge - sets count to zero
  var clearSupportBadge: @Sendable () async -> Void
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
        let deviceId = device.id
        let registeredDeviceIdShared = $registeredDeviceId
        await MainActor.run {
          registeredDeviceIdShared.withLock { $0 = deviceId }
        }
      } catch {
        print("📱 Failed to register device: \(error)")
      }
    },
    handleNotificationTap: { userInfo in
      @Shared(.stationLists) var stationLists
      @Shared(.mainContainerNavigationCoordinator) var navCoordinator
      let navCoordinatorShared = $navCoordinator

      if NotificationPayload.notificationType(from: userInfo) == "support_message" {
        // Decide on the main actor whether the support tap should refresh the
        // already-visible support page or push a new one, then await the push
        // outside the sync MainActor.run closure so we don't have to spawn an
        // unstructured Task to bridge the async navigateToSupport call.
        let needsNavigation = await MainActor.run { () -> Bool in
          let coordinator = navCoordinatorShared.wrappedValue
          let isSupportPageVisible = coordinator.path.contains { pathItem in
            if case .supportPage = pathItem { return true }
            return false
          }
          if isSupportPageVisible {
            NotificationCenter.default.post(name: .refreshSupportMessages, object: nil)
            return false
          }
          return true
        }
        if needsNavigation {
          await navCoordinatorShared.wrappedValue.navigateToSupport(SupportPageModel())
        }
        return
      }

      guard let stationId = NotificationPayload.stationId(from: userInfo) else {
        return
      }

      let allStations = stationLists.flatMap { $0.stationItems(includeHidden: true) }
        .map { $0.anyStation }

      guard let station = allStations.first(where: { $0.id == stationId }) else {
        return
      }

      @Dependency(\.stationPlayer) var stationPlayer
      await stationPlayer.play(station: station)
    },
    handleGiveawayWinnerPush: { userInfo in
      guard let push = GiveawayWinnerPush(userInfo: userInfo) else {
        // A malformed winner push is the one rescue path for a missed promotion — never drop it
        // silently. (A non-giveaway payload routed here by mistake is not worth reporting.)
        if userInfo["type"] as? String == "giveaway_winner" {
          reportIssue("Dropped malformed giveaway_winner push: \(userInfo)")
        }
        return
      }
      // Honor the server's claim flag: an already-claimed prize (other device) resolves straight to a
      // completed win, so the arbiter never prompts the form for it.
      let submissionCompleted = push.submissionCompleted ?? false
      @Shared(.giveawayParticipations) var participations
      let participationsShared = $participations
      await MainActor.run {
        participationsShared.withLock { dict in
          // Already a win. Honor a server "claimed elsewhere" upgrade by flipping a locally-pending
          // win to completed (so the arbiter stops re-presenting the claim form), but never clobber
          // the `winnerSheetPresentedAt` stamp or re-open an already-completed claim.
          if case .resolvedWon(let alreadyCompleted) = dict[push.eventId]?.status {
            if submissionCompleted, !alreadyCompleted {
              dict[push.eventId]?.status = .resolvedWon(submissionCompleted: true)
            }
            return
          }
          if dict[push.eventId] != nil {
            dict[push.eventId]?.status = .resolvedWon(submissionCompleted: submissionCompleted)
          } else {
            dict[push.eventId] = GiveawayParticipation(
              id: push.eventId, stationId: push.stationId ?? "", prizeName: push.prizeName,
              prizeDescription: push.prizeDescription, prizeImageUrl: push.prizeImageUrl,
              winningNumber: push.winningNumber, tapNumber: push.tapNumber,
              status: .resolvedWon(submissionCompleted: submissionCompleted), tappedAt: Date())
          }
        }
      }
    },
    handleGiveawayWinnerPendingPush: { userInfo in
      guard GiveawayFeature.isLiveDataEnabled else { return }
      guard let push = GiveawayWinnerPendingPush(userInfo: userInfo) else {
        if userInfo["type"] as? String == "giveaway_winner_pending" {
          reportIssue("Dropped malformed giveaway_winner_pending push: \(userInfo)")
        }
        return
      }
      @Shared(.pendingCongratsActions) var actions
      let actionsShared = $actions
      await MainActor.run {
        actionsShared.withLock { dict in
          if let existing = dict[push.eventId] {
            // A terminal action (submitted / skipped / alreadyClosed) must NOT be resurrected by a
            // delayed duplicate push — that would re-prompt the owner and allow a second congrats.
            // A non-terminal in-progress action keeps its recording / audioBlockId; only refresh
            // metadata.
            guard !existing.isTerminal else { return }
            var updated = existing
            updated.winnerName = push.winnerName ?? existing.winnerName
            updated.prizeName = push.prizeName ?? existing.prizeName
            updated.congratsExpiresAt = push.congratsExpiresAt ?? existing.congratsExpiresAt
            dict[push.eventId] = updated
            return
          }
          dict[push.eventId] = CongratsAction(
            eventId: push.eventId, stationId: push.stationId, winnerName: push.winnerName,
            prizeName: push.prizeName, congratsExpiresAt: push.congratsExpiresAt,
            state: .pending, startedAt: Date())
        }
      }
    },
    setBadgeCount: { count in
      try? await UNUserNotificationCenter.current().setBadgeCount(count)
    },
    handleSupportNotificationBadge: { badgeFromPayload in
      let newCount = await MainActor.run { () -> Int in
        @Shared(.unreadSupportCount) var unreadSupportCount
        if let badge = badgeFromPayload {
          $unreadSupportCount.withLock { $0 = badge }
          return badge
        } else {
          $unreadSupportCount.withLock { $0 += 1 }
          return unreadSupportCount
        }
      }
      @Dependency(\.pushNotifications) var pushNotifications
      await pushNotifications.setBadgeCount(newCount)
    },
    clearSupportBadge: {
      await MainActor.run {
        @Shared(.unreadSupportCount) var unreadSupportCount
        $unreadSupportCount.withLock { $0 = 0 }
      }
      @Dependency(\.pushNotifications) var pushNotifications
      await pushNotifications.setBadgeCount(0)
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
