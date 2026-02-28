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
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    TabView(selection: $model.activeTab) {
      if model.isInBroadcastMode {
        broadcastTab
        libraryTab
        listenersTab
        settingsTab
      } else {
        homeTab
        stationsTab
        rewardsTab
        profileTab
      }
    }
    //        .tabBarMinimizeBehavior(.onScrollDown)  // add in iOS 26
    .accentColor(.white)  // Makes the selected tab icon white
    .onAppear {
      let tabBarAppearance = UITabBarAppearance()
      tabBarAppearance.configureWithOpaqueBackground()
      tabBarAppearance.backgroundColor = .black

      UITabBar.appearance().standardAppearance = tabBarAppearance
      UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
      UITabBar.appearance().unselectedItemTintColor = UIColor(white: 0.7, alpha: 1.0)
    }
    .playolaAlert($model.presentedAlert)
    .onChange(of: model.activeTab) {
      model.checkAndShowRatingPromptIfNeeded()
    }
    .sheet(
      item: Binding(
        get: {
          switch model.mainContainerNavigationCoordinator.presentedSheet {
          case .player, .feedbackSheet, .share:
            return model.mainContainerNavigationCoordinator.presentedSheet
          default:
            return nil
          }
        },
        set: { model.mainContainerNavigationCoordinator.presentedSheet = $0 }
      ),
      content: { item in
        ZStack {
          switch item {
          case .player(let playerPageModel):
            PlayerPage(model: playerPageModel)
          case .feedbackSheet(let feedbackModel):
            FeedbackSheetView(model: feedbackModel)
          case .share(let shareModel):
            ShareSheet(items: shareModel.items)
          default:
            EmptyView()
          }

          VStack {
            Spacer()
            ToastOverlayView()
          }
          .zIndex(1)  // Ensure toast appears above content
        }
      }
    )
    .fullScreenCover(
      item: Binding(
        get: {
          switch model.mainContainerNavigationCoordinator.presentedSheet {
          case .recordPage, .recordIntroPage, .songSearchPage:
            return model.mainContainerNavigationCoordinator.presentedSheet
          default:
            return nil
          }
        },
        set: { model.mainContainerNavigationCoordinator.presentedSheet = $0 }
      ),
      content: { item in
        switch item {
        case .recordPage(let recordPageModel):
          NavigationStack {
            RecordPageView(model: recordPageModel)
          }
        case .recordIntroPage(let recordIntroPageModel):
          NavigationStack {
            RecordIntroPageView(model: recordIntroPageModel)
          }
        case .songSearchPage(let songSearchPageModel):
          SongSearchPageView(model: songSearchPageModel)
        default:
          EmptyView()
        }
      }
    )
    .overlay(alignment: .bottom) {
      if let toast = model.presentedToast {
        ToastView(toast: toast)
          .padding(.horizontal, 20)
          .padding(.bottom, 0)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.easeInOut(duration: 0.3), value: model.presentedToast)
    .onAppear { Task { await model.viewAppeared() } }
    .onChange(of: scenePhase) { _, newPhase in
      model.handleScenePhaseChange(newPhase)
      if newPhase == .active {
        Task { await model.refreshOnForeground() }
      }
    }
    .onChange(of: model.mainContainerNavigationCoordinator.appMode) { _, newMode in
      if case .broadcasting = newMode {
        model.ensureBroadcastModels()
        model.$activeTab.withLock { $0 = .broadcast }
      } else {
        model.$activeTab.withLock { $0 = .home }
      }
    }
  }

  // MARK: - Listening Mode Tabs

  @ViewBuilder
  private var homeTab: some View {
    NavigationStack(path: $model.mainContainerNavigationCoordinator.homePath) {
      tabContentWithSmallPlayer {
        HomePageView(model: model.homePageModel)
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image("HomeTabImage")
      Text("Home")
    }
    .tag(MainContainerModel.ActiveTab.home)
  }

  @ViewBuilder
  private var stationsTab: some View {
    NavigationStack(path: $model.mainContainerNavigationCoordinator.stationsPath) {
      tabContentWithSmallPlayer {
        StationListPage(model: model.stationListModel)
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image("RadioStationsTabImage")
      Text("Radio Stations")
    }
    .tag(MainContainerModel.ActiveTab.stationsList)
  }

  @ViewBuilder
  private var rewardsTab: some View {
    NavigationStack(path: $model.mainContainerNavigationCoordinator.rewardsPath) {
      tabContentWithSmallPlayer {
        RewardsPageView(model: model.rewardsPageModel)
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image("gift")
      Text("Rewards")
    }
    .tag(MainContainerModel.ActiveTab.rewards)
  }

  @ViewBuilder
  private var profileTab: some View {
    NavigationStack(path: $model.mainContainerNavigationCoordinator.profilePath) {
      tabContentWithSmallPlayer {
        ContactPageView(model: model.contactPageModel)
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image("ProfileTabImage")
      Text("Your Profile")
    }
    .tag(MainContainerModel.ActiveTab.profile)
  }

  // MARK: - Broadcast Mode Tabs

  @ViewBuilder
  private var broadcastTab: some View {
    NavigationStack(path: $model.mainContainerNavigationCoordinator.broadcastPath) {
      tabContentWithSmallPlayer {
        if let broadcastModel = model.broadcastPageModel {
          BroadcastPageView(model: broadcastModel)
        }
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image(systemName: "antenna.radiowaves.left.and.right")
      Text("Broadcast")
    }
    .tag(MainContainerModel.ActiveTab.broadcast)
  }

  @ViewBuilder
  private var libraryTab: some View {
    NavigationStack(path: $model.mainContainerNavigationCoordinator.libraryPath) {
      tabContentWithSmallPlayer {
        if let libraryModel = model.libraryPageModel {
          LibraryPageView(model: libraryModel)
        }
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image(systemName: "music.note.list")
      Text("Library")
    }
    .tag(MainContainerModel.ActiveTab.library)
  }

  @ViewBuilder
  private var listenersTab: some View {
    NavigationStack(path: $model.mainContainerNavigationCoordinator.listenersPath) {
      tabContentWithSmallPlayer {
        if let listenerModel = model.listenerQuestionPageModel {
          BroadcastersListenerQuestionPageView(model: listenerModel)
        }
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image(systemName: "bubble.left.and.bubble.right")
      Text("Listeners")
    }
    .tag(MainContainerModel.ActiveTab.listeners)
  }

  @ViewBuilder
  private var settingsTab: some View {
    NavigationStack(path: $model.mainContainerNavigationCoordinator.settingsPath) {
      tabContentWithSmallPlayer {
        ContactPageView(model: model.contactPageModel)
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image("ProfileTabImage")
      Text("Profile")
    }
    .tag(MainContainerModel.ActiveTab.settings)
  }

  // MARK: - Helper Views

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
