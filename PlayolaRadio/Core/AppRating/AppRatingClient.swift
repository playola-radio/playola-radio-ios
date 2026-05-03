//
//  AppRatingClient.swift
//  PlayolaRadio
//

import Dependencies
import DependenciesMacros
import Foundation
import Sharing
import StoreKit

@DependencyClient
struct AppRatingClient: Sendable {
  var shouldShowRatingPrompt: @Sendable (_ totalListenTimeMS: Int) -> Bool = { _ in false }
  var recordInstallDateIfNeeded: @Sendable () -> Void
  var markRatingPromptShown: @Sendable () -> Void
  var markRatingPromptDismissed: @Sendable () -> Void
  var requestAppStoreReview: @Sendable () async -> Void
}

extension AppRatingClient: TestDependencyKey {
  static let testValue = AppRatingClient()
}

extension DependencyValues {
  var appRating: AppRatingClient {
    get { self[AppRatingClient.self] }
    set { self[AppRatingClient.self] = newValue }
  }
}

extension AppRatingClient: DependencyKey {
  private static let oneHourMS = 60 * 60 * 1000
  private static let sevenDaysInterval: TimeInterval = 7 * 24 * 60 * 60

  static var liveValue: Self {
    Self(
      shouldShowRatingPrompt: { totalListenTimeMS in
        @Dependency(\.date) var date
        @Shared(.appInstallDate) var appInstallDate
        @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion
        @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate

        let currentVersion = Bundle.main.releaseVersionNumber ?? "unknown"

        // Already shown for this version
        if lastRatingPromptVersion == currentVersion {
          return false
        }

        // Not enough listening time (need 1 hour)
        guard totalListenTimeMS >= oneHourMS else {
          return false
        }

        // App not installed long enough (need 7 days)
        guard let installDate = appInstallDate else {
          return false
        }
        let daysSinceInstall = date.now.timeIntervalSince(installDate)
        guard daysSinceInstall >= sevenDaysInterval else {
          return false
        }

        // If previously dismissed, check if 7 days have passed
        if let dismissDate = lastRatingPromptDismissDate {
          let daysSinceDismiss = date.now.timeIntervalSince(dismissDate)
          guard daysSinceDismiss >= sevenDaysInterval else {
            return false
          }
        }

        return true
      },
      recordInstallDateIfNeeded: {
        @Dependency(\.date) var date
        @Shared(.appInstallDate) var appInstallDate
        if appInstallDate == nil {
          $appInstallDate.withLock { $0 = date.now }
        }
      },
      markRatingPromptShown: {
        @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion
        @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate
        let currentVersion = Bundle.main.releaseVersionNumber ?? "unknown"
        $lastRatingPromptVersion.withLock { $0 = currentVersion }
        $lastRatingPromptDismissDate.withLock { $0 = nil }
      },
      markRatingPromptDismissed: {
        @Dependency(\.date) var date
        @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate
        $lastRatingPromptDismissDate.withLock { $0 = date.now }
      },
      requestAppStoreReview: {
        await MainActor.run {
          if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
          {
            AppStore.requestReview(in: scene)
          }
        }
      }
    )
  }
}
