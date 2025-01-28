//
//  PlayolaRadioApp.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import ComposableArchitecture
import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

@main
struct PlayolaRadioApp: App {
  init() {
    NowPlayingUpdater.shared.setupRemoteControlCenter()
  }
  var body: some Scene {
    WindowGroup {
      if _XCTIsTesting || isTesting {
        // NB: Don't run application in tests to avoid interference between the app and the test.
        EmptyView()
      } else {
        AppView()
          .onOpenURL { url in
            GIDSignIn.sharedInstance.handle(url)
          }
          .onAppear {
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
              // Check if `user` exists; otherwise, do something with `error`
            }
          }
      }
    }
  }
}
