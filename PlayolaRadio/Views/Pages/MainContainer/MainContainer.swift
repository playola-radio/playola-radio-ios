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
    TabView(selection: activeTabBinding) {
      if model.isInBroadcastMode {
        artistHomeTab
        artistDashboardTab
        settingsTab
      } else {
        homeTab
        stationsTab
        yourLibraryTab
        profileTab
      }
    }
    .accentColor(.white)  // Makes the selected tab icon white
    .playolaTabBarChrome()
    .playolaTabBarMinimize(isEnabled: model.shouldShowSmallPlayer)
    .playolaBottomAccessory(isEnabled: model.shouldShowSmallPlayer) {
      smallPlayer(isGlassAccessory: true)
    }
    .playolaAlert($model.presentedAlert)
    .onChange(of: model.activeTab) {
      model.checkAndShowRatingPromptIfNeeded()
    }
    .sheet(
      item: Binding(
        get: {
          switch model.mainContainerNavigationCoordinator.presentedSheet {
          case .player, .feedbackSheet, .share, .redeemPrize, .artistSuggestion, .welcomeMessage,
            .giveawayWinner, .giveawayCongrats, .developerOptions:
            return model.mainContainerNavigationCoordinator.presentedSheet
          default:
            return nil
          }
        },
        set: { newValue in
          model.$mainContainerNavigationCoordinator.withLock {
            $0.presentedSheet = newValue
          }
        }
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
          case .redeemPrize(let redeemModel):
            RedeemPrizeSheetView(model: redeemModel)
          case .artistSuggestion(let artistSuggestionModel):
            StationSuggestionPageView(model: artistSuggestionModel)
          case .welcomeMessage(let welcomeModel):
            WelcomeMessagePageView(model: welcomeModel)
          case .giveawayWinner(let winnerModel):
            GiveawayWinnerSheetView(model: winnerModel)
          case .giveawayCongrats(let congratsModel):
            GiveawayCongratsSheetView(model: congratsModel)
          case .developerOptions(let developerOptionsModel):
            DeveloperOptionsSheetView(model: developerOptionsModel)
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
        set: { newValue in
          model.$mainContainerNavigationCoordinator.withLock {
            $0.presentedSheet = newValue
          }
        }
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
        model.$activeTab.withLock { $0 = .artistHome }
      } else {
        model.$activeTab.withLock { $0 = .home }
      }
    }
  }

  // MARK: - Listening Mode Tabs

  @ViewBuilder
  private var homeTab: some View {
    NavigationStack(path: navigationPathBinding(\.homePath)) {
      tabContentWithSmallPlayer {
        HomePageView(model: model.homePageModel)
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image("HomeTabImage")
      Text(model.homeTabTitle)
    }
    .tag(MainContainerModel.ActiveTab.home)
  }

  @ViewBuilder
  private var stationsTab: some View {
    NavigationStack(path: navigationPathBinding(\.stationsPath)) {
      tabContentWithSmallPlayer {
        StationListPage(model: model.stationListModel)
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image("RadioStationsTabImage")
      Text(model.stationsTabTitle)
    }
    .tag(MainContainerModel.ActiveTab.stationsList)
  }

  @ViewBuilder
  private var yourLibraryTab: some View {
    NavigationStack(path: navigationPathBinding(\.yourLibraryPath)) {
      tabContentWithSmallPlayer {
        YourLibraryPageView(model: model.yourLibraryPageModel)
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image(systemName: "heart.fill")
      Text(model.yourLibraryTabTitle)
    }
    .tag(MainContainerModel.ActiveTab.yourLibrary)
  }

  @ViewBuilder
  private var profileTab: some View {
    NavigationStack(path: navigationPathBinding(\.profilePath)) {
      tabContentWithSmallPlayer {
        ContactPageView(model: model.contactPageModel)
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image("ProfileTabImage")
      Text(model.profileTabTitle)
    }
    .tag(MainContainerModel.ActiveTab.profile)
  }

  // MARK: - Broadcast Mode Tabs

  @ViewBuilder
  private var artistHomeTab: some View {
    NavigationStack(path: navigationPathBinding(\.artistHomePath)) {
      tabContentWithSmallPlayer {
        ArtistHomePageView(model: model.artistHomePageModel)
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image("HomeTabImage")
      Text(model.artistHomeTabTitle)
    }
    .tag(MainContainerModel.ActiveTab.artistHome)
  }

  @ViewBuilder
  private var artistDashboardTab: some View {
    NavigationStack(path: navigationPathBinding(\.artistDashboardPath)) {
      tabContentWithSmallPlayer {
        ArtistDashboardPageView(model: model.artistDashboardPageModel)
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image(systemName: "chart.xyaxis.line")
      Text(model.artistDashboardTabTitle)
    }
    .tag(MainContainerModel.ActiveTab.artistDashboard)
  }

  @ViewBuilder
  private var settingsTab: some View {
    NavigationStack(path: navigationPathBinding(\.settingsPath)) {
      tabContentWithSmallPlayer {
        ContactPageView(model: model.contactPageModel)
      }
      .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
        path.destinationView
      }
    }
    .tabItem {
      Image("ProfileTabImage")
      Text(model.settingsTabTitle)
    }
    .tag(MainContainerModel.ActiveTab.settings)
  }

  // MARK: - Helper Views

  @ViewBuilder
  private func tabContentWithSmallPlayer<Content: View>(@ViewBuilder content: () -> Content)
    -> some View
  {
    content()
      .playolaLegacySmallPlayer(isEnabled: model.shouldShowSmallPlayer) {
        smallPlayer(isGlassAccessory: false)
      }
  }

  private func smallPlayer(isGlassAccessory: Bool) -> some View {
    SmallPlayer(isGlassAccessory: isGlassAccessory)
      .onTapGesture {
        model.onSmallPlayerTapped()
      }
  }

  private var activeTabBinding: Binding<MainContainerModel.ActiveTab> {
    Binding(
      get: { model.activeTab },
      set: { newValue in
        model.$activeTab.withLock { $0 = newValue }
      }
    )
  }

  private func navigationPathBinding(
    _ keyPath: WritableKeyPath<
      MainContainerNavigationCoordinator, [MainContainerNavigationCoordinator.Path]
    >
  ) -> Binding<[MainContainerNavigationCoordinator.Path]> {
    Binding(
      get: {
        model.mainContainerNavigationCoordinator[keyPath: keyPath]
      },
      set: { newValue in
        model.$mainContainerNavigationCoordinator.withLock {
          $0[keyPath: keyPath] = newValue
        }
      }
    )
  }

}

struct MainContainer_Previews: PreviewProvider {
  static var previews: some View {
    MainContainer(model: MainContainerModel())
      .preferredColorScheme(.dark)
  }
}
