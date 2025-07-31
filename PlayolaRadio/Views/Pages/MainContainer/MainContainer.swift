//
//  MainContainer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/11/25.
//

import Combine
import Dependencies
import Sharing
import SwiftUI

@MainActor
struct MainContainer: View {
  @Bindable var model: MainContainerModel

  var body: some View {
    NavigationStack(path: $model.mainContainerNavigationCoordinator.path) {
      VStack(spacing: 0) {
        TabView(selection: $model.activeTab) {
          tabContentWithSmallPlayer(content: {
            HomePageView(model: model.homePageModel)
          })
          .tabItem {
            Image("HomeTabImage")
            Text("Home")
          }
          .tag(MainContainerModel.ActiveTab.home)

          tabContentWithSmallPlayer(content: {
            StationListPage(model: model.stationListModel)
          })
          .tabItem {
            Image("RadioStationsTabImage")
            Text("Radio Stations")
          }
          .tag(MainContainerModel.ActiveTab.stationsList)

          tabContentWithSmallPlayer(content: {
            RewardsPageView(model: model.rewardsPageModel)
          })
          .tabItem {
            Image("gift")
            Text("Rewards")
          }
          .tag(MainContainerModel.ActiveTab.rewards)

          tabContentWithSmallPlayer(content: {
            ContactPageView(model: model.contactPageModel)
          })
          .tabItem {
            Image("ProfileTabImage")
            Text("Your Profile")
          }
          .tag(MainContainerModel.ActiveTab.profile)
        }
        .accentColor(.white)  // Makes the selected tab icon white
        .onAppear {
          let tabBarAppearance = UITabBarAppearance()
          tabBarAppearance.configureWithOpaqueBackground()
          tabBarAppearance.backgroundColor = .black

          UITabBar.appearance().standardAppearance = tabBarAppearance
          UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
          UITabBar.appearance().unselectedItemTintColor = UIColor(white: 0.7, alpha: 1.0)
        }
      }
    }
    .alert(item: $model.presentedAlert) { $0.alert }
    .sheet(
      item: $model.presentedSheet,
      content: { item in
        switch item {
        case let .player(playerPageModel):
          PlayerPage(model: playerPageModel)
        }
      }
    )
    .onAppear { Task { await model.viewAppeared() } }
    .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
      switch path {
      case let .editProfilePage(model):
        EditProfilePageView(model: model)
      }
    }
  }

  @ViewBuilder
  private func tabContentWithSmallPlayer<Content: View>(@ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(spacing: 0) {
      content()

      if model.shouldShowSmallPlayer {
        SmallPlayer()
          .onTapGesture {
            model.onSmallPlayerTapped()
          }
          .transition(.move(edge: .bottom))
          .zIndex(1)
      }
    }
  }
}

struct MainContainer_Previews: PreviewProvider {
  static var previews: some View {
    MainContainer(model: MainContainerModel())
      .preferredColorScheme(.dark)
  }
}
