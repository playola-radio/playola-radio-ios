//
//  MainContainer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/11/25.
//

import SwiftUI
import Sharing
import Combine

@MainActor
@Observable
class MainContainerModel: ViewModel {
  var cancellables: Set<AnyCancellable> = []

  @ObservationIgnored var api: API!
  @ObservationIgnored var stationPlayer: StationPlayer!

  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool


  enum ActiveTab {
    case home
    case stationsList
    case profile
  }

  var selectedTab: ActiveTab = .home
  var presentedAlert: PlayolaAlert? = nil
  var presentedSheet: PlayolaSheet? = nil

  var homePageModel = HomePageModel()
  var stationListModel = StationListModel()

  var shouldShowSmallPlayer: Bool {
    switch stationPlayer.state.playbackStatus {
    case .playing, .loading:
      return true
    case .stopped, .error, .startingNewStation:
      return false
    }
  }

  var smallPlayerMainTitle: String {
    stationPlayer.currentStation?.name ?? ""
  }

  var smallPlayerSecondaryTitle: String {
      return stationPlayer.currentStation?.desc ?? ""
  }

  var smallPlayerArtworkURL: URL {
    stationPlayer.state.albumArtworkUrl ?? stationPlayer.currentStation?.processedImageURL() ?? URL(string: "https://example.com")!
  }

  init(api: API? = nil, stationPlayer: StationPlayer? = nil) {
    self.api = api ?? API()
    self.stationPlayer = stationPlayer ?? .shared
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

    stationPlayer.$state.sink { self.processNewStationState($0) }.store(in: &cancellables)
  }

  func dismissButtonInSheetTapped() {
    self.presentedSheet = nil
  }

  func processNewStationState(_ newState: StationPlayer.State) {
    switch newState.playbackStatus {
    case let .startingNewStation(station):
      self.presentedSheet = .player(PlayerPageModel(onDismiss: {
        self.presentedSheet = nil
      }))
    default:
      return
    }
  }

  func onSmallPlayerStopTapped() {
    stationPlayer.stop()
  }

  func onSmallPlayerTapped() {
    self.presentedSheet = .player(PlayerPageModel(onDismiss: { self.presentedSheet = nil }))
  }
}

extension PlayolaAlert {
  static var errorLoadingStations: PlayolaAlert {
    PlayolaAlert(
      title: "Error Loading Stations",
      message: "There was an error loading the stations. Please check your connection and try again.",
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
        TabContentWithSmallPlayer(content: {
          HomePageView(model: model.homePageModel)
        })
        .tabItem {
          Image("HomeTabImage")
          Text("Home")
        }
        .tag(MainContainerModel.ActiveTab.home)

        TabContentWithSmallPlayer(content: {
          StationListPage(model: model.stationListModel)
        })
        .tabItem {
          Image("RadioStationsTabImage")
          Text("Radio Stations")
        }
        .tag(MainContainerModel.ActiveTab.stationsList)

        TabContentWithSmallPlayer(content: {
          HomePageView(model: model.homePageModel) // Temporarily using HomePageView
        })
        .tabItem {
          Image("ProfileTabImage")
          Text("Profile")
        }
        .tag(MainContainerModel.ActiveTab.profile)
      }
      .accentColor(.white) // Makes the selected tab icon white
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
    .sheet(item: $model.presentedSheet, content: { item in
      switch item {
      case let .about(aboutModel):
        NavigationStack {
          AboutPage(model: aboutModel)
        }
      case let .player(playerPageModel):
        PlayerPage(model: playerPageModel)
      }
    })
    .onAppear { Task { await model.viewAppeared() } }
  }

  @ViewBuilder
  private func TabContentWithSmallPlayer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
