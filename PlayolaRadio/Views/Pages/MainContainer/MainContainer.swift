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
      self.presentedSheet = .player(PlayerPageModel())
    default:
      return
    }
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
      TabView(selection: $model.selectedTab) {
        HomePageView(model: model.homePageModel)
                .tabItem {
                    Image("HomeTabImage")
                    Text("Home")
                }
                .tag(MainContainerModel.ActiveTab.home)

        StationListPage(model: model.stationListModel)
                .tabItem {
                    Image("RadioStationsTabImage")
                    Text("Radio Stations")
                }
                .tag(MainContainerModel.ActiveTab.stationsList)

        HomePageView(model: model.homePageModel) // Temporarily using HomePageView
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
        .alert(item: $model.presentedAlert) { $0.alert }
        .sheet(item: $model.presentedSheet, content: { item in
                  switch item {
                  case let .about(aboutModel):
                      NavigationStack {
                          AboutPage(model: aboutModel)
//                              .toolbar {
//                                  ToolbarItem(placement: .confirmationAction) {
//                                      Button(action: { model.dismissButtonInSheetTapped() }) {
//                                          Image(systemName: "xmark.circle.fill")
//                                              .resizable()
//                                              .frame(width: 32, height: 32)
//                                              .foregroundColor(.gray)
//                                              .padding(20)
//                                      }
//                                  }
//                              }
                      }
                  case let .player(playerPageModel):
                    PlayerPage(model: PlayerPageModel())
                  }
              })
        .onAppear { Task { await model.viewAppeared() } }
    }
}

struct MainContainer_Previews: PreviewProvider {
    static var previews: some View {
      MainContainer(model: MainContainerModel())
            .preferredColorScheme(.dark)
    }
}
