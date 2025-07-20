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

  @ObservationIgnored var api: API!
  @ObservationIgnored @Dependency(\.stationPlayer) var stationPlayer

  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool

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

  var smallPlayerMainTitle: String {
    stationPlayer.currentState().currentStation?.name ?? ""
  }

  var smallPlayerSecondaryTitle: String {
    return stationPlayer.currentState().currentStation?.desc ?? ""
  }

  var smallPlayerArtworkURL: URL {
    let currentState = stationPlayer.currentState()
    return currentState.albumArtworkUrl ?? currentState.currentStation?.processedImageURL() ?? URL(
      string: "https://example.com")!
  }

  init(api: API? = nil) {
    self.api = api ?? API()
  }

  func viewAppeared() async {
    // Exit early if we already have the data.
    guard !stationListsLoaded else { return }
    guard let api = self.api else { return }

    do {
      try await api.getStations()
    } catch {
      presentedAlert = .errorLoadingStations
    }

    stationPlayer.statePublisher.sink { self.processNewStationState($0) }.store(in: &cancellables)
  }

  func dismissButtonInSheetTapped() {
    self.presentedSheet = nil
  }

  func processNewStationState(_ newState: StationPlayerState) {
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

  func setShouldShowSmallPlayer(_ stationPlayerState: StationPlayerState) {
    withAnimation {
      switch stationPlayerState.playbackStatus {
      case .playing, .startingNewStation, .loading:
        self.shouldShowSmallPlayer = true
      default:
        self.shouldShowSmallPlayer = false
      }
    }
  }

  func onSmallPlayerStopTapped() {
    Task { await stationPlayer.stop() }
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
        case let .about(aboutModel):
          NavigationStack {
            AboutPage(model: aboutModel)
          }
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
        SmallPlayer(
          mainTitle: model.smallPlayerMainTitle,

          secondaryTitle: model.smallPlayerSecondaryTitle,
          artworkURL: model.smallPlayerArtworkURL,
          onStopButtonTapped: model.onSmallPlayerStopTapped
        )
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
