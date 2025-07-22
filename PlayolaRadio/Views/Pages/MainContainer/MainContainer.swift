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
@Observable
class MainContainerModel: ViewModel {
  var cancellables: Set<AnyCancellable> = []

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored var stationPlayer: StationPlayer!
  @ObservationIgnored @Shared(.stationLists) var stationLists
  @ObservationIgnored @Shared(.nowPlaying) var nowPlaying: NowPlaying?
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool = false

  enum ActiveTab {
    case home
    case stationsList
    case profile
  }

  var selectedTab: ActiveTab = .home
  var presentedAlert: PlayolaAlert?
  var presentedSheet: PlayolaSheet?

  var homePageModel = HomePageModel()
  var stationListModel = StationListModel()

  var shouldShowSmallPlayer: Bool = false

  init(stationPlayer: StationPlayer? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
    super.init()
  }

  func viewAppeared() async {
    // Exit early if we already have the data.
    guard !stationListsLoaded else { return }

    do {
      let retrievedStationsLists = try await api.getStations()
      self.$stationLists.withLock { $0 = retrievedStationsLists }
      self.$stationListsLoaded.withLock { $0 = true }
    } catch {
      presentedAlert = .errorLoadingStations
    }

    stationPlayer.$state.sink { self.processNewStationState($0) }.store(in: &cancellables)
  }

  func dismissButtonInSheetTapped() {
    self.presentedSheet = nil
  }

  func processNewStationState(_ newState: StationPlayer.State) {
    switch newState.playbackStatus {
    case let .startingNewStation(_):
      self.presentedSheet = .player(
        PlayerPageModel(onDismiss: {
          self.presentedSheet = nil
        }))
    default: break
    }
    self.setShouldShowSmallPlayer(newState)
  }

  func setShouldShowSmallPlayer(_ stationPlayerState: StationPlayer.State) {
    withAnimation {
      switch stationPlayerState.playbackStatus {
      case .playing, .startingNewStation, .loading:
        self.shouldShowSmallPlayer = true
      default:
        self.shouldShowSmallPlayer = false
      }
    }
  }

  func onSmallPlayerTapped() {
    self.presentedSheet = .player(PlayerPageModel(onDismiss: { self.presentedSheet = nil }))
  }
}

extension PlayolaAlert {
  static var errorLoadingStations: PlayolaAlert {
    PlayolaAlert(
      title: "Error Loading Stations",
      message:
        "There was an error loading the stations. Please check your connection and try again.",
      dismissButton: .cancel(Text("OK"))
    )
  }
}

@MainActor
struct MainContainer: View {
  @Bindable var model: MainContainerModel

  var body: some View {
    VStack(spacing: 0) {
      TabView(selection: $model.selectedTab) {
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
          HomePageView(model: model.homePageModel)  // Temporarily using HomePageView
        })
        .tabItem {
          Image("ProfileTabImage")
          Text("Profile")
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
