//
//  ContentView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import SwiftUI
import Sharing

@MainActor
class ViewModel: Hashable {
    nonisolated static func == (lhs: ViewModel, rhs: ViewModel) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}



@MainActor
struct AppView: View {
  @Shared(.slideOutViewModel) var slideOutViewModel
  @State var tempIsShowing: Bool = true
    @Bindable var navigationCoordinator: NavigationCoordinator = .init()

    @MainActor
    init() {
        navigationCoordinator = NavigationCoordinator.shared
        UINavigationBar.appearance().barStyle = .black
        UINavigationBar.appearance().tintColor = .white
        UINavigationBar.appearance().prefersLargeTitles = true
    }

    var body: some View {
      ZStack {
        
        
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
        .accentColor(.white)
        
        SideMenu(
          isShowing: self.slideOutViewModel.isShowing,
          content: AnyView(
            SideMenuView()))
      }
    }
}

#Preview {
    NavigationStack {
        AppView()
    }
}
