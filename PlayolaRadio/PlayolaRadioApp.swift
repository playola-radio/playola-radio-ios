//
//  PlayolaRadioApp.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import ComposableArchitecture
import SwiftUI

@main
struct PlayolaRadioApp: App {
  var body: some Scene {
    WindowGroup {
      if _XCTIsTesting {
        // NB: Don't run application in tests to avoid interference between the app and the test.
        EmptyView()
      } else {
        AppView()
      }
    }
  }
}
