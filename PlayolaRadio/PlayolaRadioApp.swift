//
//  PlayolaRadioApp.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import GoogleSignIn
import GoogleSignInSwift
import SDWebImage
import SDWebImageSVGCoder
import SwiftUI

@main
struct PlayolaRadioApp: App {
  init() {
    // Register SVG coder for SDWebImage
    SDImageCodersManager.shared.addCoder(SDImageSVGCoder.shared)

    NowPlayingUpdater.shared.setupRemoteControlCenter()
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
