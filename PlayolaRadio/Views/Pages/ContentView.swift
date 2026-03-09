//
//  ContentView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import Dependencies
import Sharing
import SwiftUI
import UIKit

extension Notification.Name {
  static let requiresAppUpdate = Notification.Name("requiresAppUpdate")
}

@MainActor
struct ContentView: View {
  @Shared(.auth) var auth
  @Shared(.appVersionRequirements) var appVersionRequirements
  @Shared(.isBroadcaster) var isBroadcaster
  @Dependency(\.api) var api
  @Dependency(\.analytics) var analytics
  @State private var hasTrackedAppOpen = false
  @State private var requiresUpdate = false

  var mainContainerModel = MainContainerModel()

  init() {
    // Ensure StationPlayer and NowPlayingUpdater are initialized early
    _ = StationPlayer.shared
    _ = NowPlayingUpdater.shared
  }

  private let appStoreURL = URL(
    string: "itms-apps://itunes.apple.com/app/id6480465361"
  )!

  var body: some View {
    Group {
      if auth.isLoggedIn {
        MainContainer(model: mainContainerModel)
      } else {
        SignInPage(model: SignInPageModel())
      }
    }
    .alert(
      "Update Required",
      isPresented: $requiresUpdate
    ) {
      Button("Update") {
        UIApplication.shared.open(appStoreURL)
        requiresUpdate = true
      }
    } message: {
      Text("A new version of Playola Radio is available. Please update to continue.")
    }
    .task {
      await checkVersionRequirements()

      guard !hasTrackedAppOpen else { return }
      hasTrackedAppOpen = true

      await analytics.track(
        .appOpened(
          source: .direct,  // TODO: Handle deep links and push notifications
          isFirstOpen: isFirstAppOpen()
        ))
    }
    .onReceive(NotificationCenter.default.publisher(for: .requiresAppUpdate)) { _ in
      requiresUpdate = true
    }
  }

  private func checkVersionRequirements() async {
    do {
      let requirements = try await api.getAppVersionRequirements()
      $appVersionRequirements.withLock { $0 = requirements }

      guard let currentVersion = Bundle.main.releaseVersionNumber else { return }

      if isVersion(currentVersion, lessThan: requirements.minimumVersion) {
        requiresUpdate = true
        return
      }

      if isBroadcaster,
        isVersion(currentVersion, lessThan: requirements.minimumBroadcasterVersion)
      {
        requiresUpdate = true
        return
      }
    } catch {
      // Network failure → fail open (allow app)
    }
  }

  private func isFirstAppOpen() -> Bool {
    let key = "has_opened_app_before"
    let hasOpenedBefore = UserDefaults.standard.bool(forKey: key)
    if !hasOpenedBefore {
      UserDefaults.standard.set(true, forKey: key)
      return true
    }
    return false
  }
}

#Preview {
  NavigationStack {
    ContentView()
  }
}
