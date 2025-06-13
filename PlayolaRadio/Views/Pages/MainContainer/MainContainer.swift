//
//  MainContainer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/11/25.
//

import SwiftUI
import Sharing

@MainActor
@Observable
class MainContainerModel: ViewModel {
  var api: API!

  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool


  enum ActiveTab {
    case home
    case stationsList
    case profile
  }

  var selectedTab: ActiveTab = .home
  var presentedAlert: PlayolaAlert? = nil

  var homePageModel = HomePageModel()

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

            StationListPage()
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
        .onAppear { Task { await model.viewAppeared() } }
    }
}

struct MainContainer_Previews: PreviewProvider {
    static var previews: some View {
      MainContainer(model: MainContainerModel())
            .preferredColorScheme(.dark)
    }
}
