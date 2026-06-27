//
//  PlayolaRadioApp.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import Dependencies
import GoogleSignIn
import GoogleSignInSwift
import SDWebImage
import SDWebImageSVGCoder
import Sharing
import SwiftUI
import UIKit
import UserNotifications

#if canImport(Sentry)
  import Sentry
#endif

extension Notification.Name {
  static let refreshSupportMessages = Notification.Name("refreshSupportMessages")
  static let scheduleUpdated = Notification.Name("scheduleUpdated")
}

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate
{
  @Dependency(\.pushNotifications) var pushNotifications

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    #if canImport(Sentry)
      let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
      if !isRunningTests {
        SentrySDK.start { options in
          options.dsn =
            "https://c024cbc3afc46a4539e4cd73ea4f32c0@o4511043985801216.ingest.us.sentry.io/4511043987898368"
          options.sendDefaultPii = false
          options.tracesSampleRate = 0.1
          options.configureProfiling = {
            $0.sessionSampleRate = 0.1
            $0.lifecycle = .trace
          }
          options.enableLogs = true

          // App Hang Tracking: capture the real main-thread blocking stack so
          // hangs resolve to named functions instead of collapsing into the
          // generic `$main` bucket (Sentry APPLE-IOS-V / 7460768272).
          //
          // App Hang Tracking V2 captures the stack at hang onset and is the
          // default on iOS/tvOS as of sentry-cocoa 9.x — the old
          // `enableAppHangTrackingV2` toggle was removed (#5615), so no flag is
          // needed to turn it on.
          //
          // 2.0s is the SDK default; set explicitly as the tuning knob if these
          // turn out noisy.
          options.appHangTimeoutInterval = 2.0
          // Ignore non-fully-blocking hangs (app stutters but still renders a
          // few frames): their stacks don't pinpoint the blocking location, so
          // they add noise without being actionable.
          options.enableReportNonFullyBlockingAppHangs = false
        }
      }
    #endif

    UNUserNotificationCenter.current().delegate = self
    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Task {
      await pushNotifications.handleDeviceToken(deviceToken)
    }
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Failed to register for remote notifications: \(error)")
  }

  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if userInfo["type"] as? String == "schedule_updated",
      let stationId = userInfo["stationId"] as? String
    {
      var info: [String: Any] = ["stationId": stationId]
      if let editorName = userInfo["editorName"] as? String {
        info["editorName"] = editorName
      }
      NotificationCenter.default.post(
        name: .scheduleUpdated,
        object: nil,
        userInfo: info
      )
      completionHandler(.newData)
    } else if userInfo["type"] as? String == "giveaway_winner" {
      let payload = userInfo.sendablePayload()
      Task {
        await pushNotifications.handleGiveawayWinnerPush(payload)
        completionHandler(.newData)
      }
    } else if userInfo["type"] as? String == "giveaway_winner_pending" {
      let payload = userInfo.sendablePayload()
      Task {
        await pushNotifications.handleGiveawayWinnerPendingPush(payload)
        completionHandler(.newData)
      }
    } else {
      completionHandler(.noData)
    }
  }

  // MARK: - UNUserNotificationCenterDelegate

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("📬 Notification received in foreground: \(notification.request.content.title)")

    if userInfo["type"] as? String == "schedule_updated" {
      completionHandler([])
      return
    }

    if userInfo["type"] as? String == "giveaway_winner" {
      let payload = userInfo.sendablePayload()
      Task {
        await pushNotifications.handleGiveawayWinnerPush(payload)
      }
      // The arbiter presents the winner sheet in-app; no redundant OS banner.
      completionHandler([])
      return
    }

    if userInfo["type"] as? String == "giveaway_winner_pending" {
      let payload = userInfo.sendablePayload()
      Task {
        await pushNotifications.handleGiveawayWinnerPendingPush(payload)
      }
      // The arbiter presents the congrats sheet in-app; no redundant OS banner.
      completionHandler([])
      return
    }

    if userInfo["type"] as? String == "support_message" {
      let badgeFromPayload = userInfo["badge"] as? Int
      Task {
        await pushNotifications.handleSupportNotificationBadge(badgeFromPayload)
      }

      @Shared(.mainContainerNavigationCoordinator) var navCoordinator
      let isSupportPageVisible = navCoordinator.path.contains { pathItem in
        if case .supportPage = pathItem { return true }
        return false
      }

      if isSupportPageVisible {
        NotificationCenter.default.post(name: .refreshSupportMessages, object: nil)
        completionHandler([])
      } else {
        completionHandler([.banner, .sound])
      }
    } else {
      completionHandler([.banner, .sound])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo.sendablePayload()
    if userInfo["type"] as? String == "giveaway_winner" {
      // Defer completion until the participation mutation persists, so the system doesn't suspend
      // mid-write and drop the win.
      Task {
        await pushNotifications.handleGiveawayWinnerPush(userInfo)
        completionHandler()
      }
    } else if userInfo["type"] as? String == "giveaway_winner_pending" {
      Task {
        await pushNotifications.handleGiveawayWinnerPendingPush(userInfo)
        completionHandler()
      }
    } else {
      Task {
        await pushNotifications.handleNotificationTap(userInfo)
      }
      completionHandler()
    }
  }
}

@main
struct PlayolaRadioApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  init() {
    // Register SVG coder for SDWebImage
    SDImageCodersManager.shared.addCoder(SDImageSVGCoder.shared)

    // Cap SDWebImage's in-memory decoded-image cache so cached artwork can't
    // dominate graphics memory and trigger jetsam during long sessions.
    // maxMemoryCost is decoded pixel bytes (~width*height*4); 64 MB holds a
    // few hundred downsampled thumbnails, well under the device pressure point.
    SDImageCache.shared.config.maxMemoryCost = 64 * 1024 * 1024
    SDImageCache.shared.config.maxMemoryCount = 100

    @Dependency(\.nowPlayingUpdater) var nowPlayingUpdater
    nowPlayingUpdater.setupRemoteControlCenter()

    // Initialize analytics
    Task {
      @Dependency(\.analytics) var analytics
      await analytics.initialize()
    }

    // Once per build per device, probe whether TLS 1.3 works on this user's
    // network. The aggregated `tls13_probe` Sentry events tell us when the iOS
    // 26 middlebox issue has cleared enough to revert the global TLS 1.2 cap
    // in APIClient+Live.swift.
    Task {
      await probeTLS13()
    }
  }

  var body: some Scene {
    WindowGroup {
      if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        // NB: Don't run application in tests to avoid interference between the app and the test.
        EmptyView()
      } else {
        ContentView()
          .onOpenURL { url in
            GIDSignIn.sharedInstance.handle(url)
          }
          .onAppear {
            GIDSignIn.sharedInstance.restorePreviousSignIn { _, _ in
              // Check if `user` exists; otherwise, do something with `error`
            }
          }
      }
    }
  }
}
