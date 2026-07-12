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
  @Dependency(\.analytics) var analytics
  @State private var hasTrackedAppOpen = false
  @State private var versionGate = AppVersionGateModel()

  @Dependency(\.stationPlayer) private var stationPlayer
  @Dependency(\.nowPlayingUpdater) private var nowPlayingUpdater

  var mainContainerModel = MainContainerModel()

  init() {
    // Resolve audio playback dependencies eagerly so the live singletons are
    // wired (state sinks, FRadioPlayer observers, remote-control center) by
    // the time the first view appears.
    _ = stationPlayer
    _ = nowPlayingUpdater
  }

  var body: some View {
    Group {
      if auth.isLoggedIn {
        MainContainer(model: mainContainerModel)
      } else {
        SignInPage(model: SignInPageModel())
      }
    }
    .alert(
      versionGate.alertTitle,
      isPresented: $versionGate.requiresUpdate
    ) {
      Button(versionGate.updateButtonTitle) {
        versionGate.requiresUpdate = true
        Task {
          await versionGate.updateButtonTapped()
          _ = await UIApplication.shared.open(versionGate.appStoreURL)
        }
      }
    } message: {
      Text(versionGate.alertMessage)
    }
    .task {
      await versionGate.checkVersionRequirements()

      guard !hasTrackedAppOpen else { return }
      hasTrackedAppOpen = true

      await analytics.track(
        .appOpened(
          source: .direct,  // TODO: Handle deep links and push notifications
          isFirstOpen: isFirstAppOpen()
        ))
    }
    .onReceive(NotificationCenter.default.publisher(for: .requiresAppUpdate)) { _ in
      Task { await versionGate.broadcasterUpdateDiscovered() }
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
