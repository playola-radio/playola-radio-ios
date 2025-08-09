//
//  ContentView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import PlayolaCore
import Sharing
import SwiftUI

@MainActor
struct ContentView: View {
  @Shared(.auth) var auth

  var body: some View {
    if auth.isLoggedIn {
      MainContainer(model: MainContainerModel())
    } else {
      SignInPage(model: SignInPageModel())
    }
  }
}

#Preview {
  NavigationStack {
    ContentView()
  }
}
