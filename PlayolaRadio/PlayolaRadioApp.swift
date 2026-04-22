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

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  @Dependency(\.pushNotifications) var pushNotifications

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    #if canImport(Sentry)
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
    let userInfo = response.notification.request.content.userInfo
    Task {
      await pushNotifications.handleNotificationTap(userInfo)
    }
    completionHandler()
  }
}

@main
struct PlayolaRadioApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  init() {
    // Register SVG coder for SDWebImage
    SDImageCodersManager.shared.addCoder(SDImageSVGCoder.shared)

    NowPlayingUpdater.shared.setupRemoteControlCenter()

    // Initialize analytics
    Task {
      @Dependency(\.analytics) var analytics
      await analytics.initialize()
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
