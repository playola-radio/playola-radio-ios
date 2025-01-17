//
//  ContentView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import ComposableArchitecture
import SwiftUI

// possibly use later for navigation
class ViewModel: Hashable {
  nonisolated static func == (lhs: ViewModel, rhs: ViewModel) -> Bool {
    ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }

  nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

@Observable
class NavigationCoordinator {
  static let shared = NavigationCoordinator()
  var path: [Path] = []

  enum Path: Hashable {
    case stationListPage(StationListModel)
    case aboutPage(AboutPageModel)
    case nowPlayingPage(NowPlayingPageModel)
  }
}

struct AppView: View {
  @Bindable var navigationCoordinator: NavigationCoordinator = NavigationCoordinator()

  @MainActor
  init() {
    self.navigationCoordinator = NavigationCoordinator.shared
    UINavigationBar.appearance().barStyle = .black
    UINavigationBar.appearance().tintColor = .white
    UINavigationBar.appearance().prefersLargeTitles = true
  }
  
  var body: some View {
    NavigationStack(path: $navigationCoordinator.path) {
        StationListPage(model: StationListModel())
        .navigationDestination(for: NavigationCoordinator.Path.self) { path in
          switch path {
          case let .aboutPage(model):
            AboutPage(model: model)
          case let .stationListPage(model):
            StationListPage(model: model)
          case let .nowPlayingPage(model):
            NowPlayingView(model: model)
          }
        }
      }
  }
}

#Preview {
  NavigationStack {
    AppView()
  }
}
