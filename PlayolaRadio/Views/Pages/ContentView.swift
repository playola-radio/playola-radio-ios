//
//  ContentView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import Dependencies
import Sharing
import SwiftUI

@MainActor
struct ContentView: View {
  @Shared(.auth) var auth
  @Dependency(\.analytics) var analytics
  @State private var hasTrackedAppOpen = false

  var body: some View {
    Group {
      if auth.isLoggedIn {
        MainContainer(model: MainContainerModel())
      } else {
        SignInPage(model: SignInPageModel())
      }
    }
    .task {
      guard !hasTrackedAppOpen else { return }
      hasTrackedAppOpen = true

      await analytics.track(
        .appOpened(
          source: .direct,  // TODO: Handle deep links and push notifications
          isFirstOpen: isFirstAppOpen()
        ))
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
