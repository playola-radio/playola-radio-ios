//
//  BroadcastBasePage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/26/25.
//

import Combine
import SwiftUI
import Sharing
import Dependencies
import PlayolaPlayer

enum BroadcastTab {
  case schedule
  case songs
}

@MainActor
@Observable
class BroadcastBaseModel: ViewModel {
  var disposeBag: Set<AnyCancellable> = Set()

  // MARK: - State
  var id = UUID()
  var selectedTab: BroadcastTab = .schedule
  var presentedAlert: PlayolaAlert?
  var stations: [Station] = []
  var selectedStation: Station?
  var isLoading: Bool = false

  // MARK: - Dependencies
  @ObservationIgnored var navigationCoordinator: NavigationCoordinator
  @ObservationIgnored var api: API
  @ObservationIgnored @Shared(.currentUser) var currentUser: User?
  @ObservationIgnored @Dependency(APIClient.self) var apiClient
  @ObservationIgnored @Shared(.auth) var auth: Auth

  init(navigationCoordinator: NavigationCoordinator = .shared,
       api: API = API(),
       selectedTab: BroadcastTab = .schedule) {
    self.navigationCoordinator = navigationCoordinator
    self.api = api
    self.selectedTab = selectedTab
    super.init()
  }

  // MARK: - Actions
  func viewAppeared() async {
    defer { self.isLoading = false }
    isLoading = true
    do {
      let stations = try await apiClient.fetchUserStations(userId: auth.jwtUser!.id)
      self.stations = stations

      if (self.stations.count >= 1) {
        selectedStation = self.stations.first { $0.id == "f3864734-de35-414f-b0b3-e6909b0b77bd" }
      } else {
        print("No stations found")
      }
    } catch (let err) {
      print("Error downloading stations: \(err)")
    }
  }

  func hamburgerButtonTapped() {
    navigationCoordinator.slideOutMenuIsShowing = true
  }

  func selectTab(_ tab: BroadcastTab) {
    selectedTab = tab
  }
}

extension PlayolaAlert {
  static var noStationFound: PlayolaAlert {
    PlayolaAlert(
      title: "No Station Found",
      message: "You don't have a station yet. Please contact support to create one.",
      dismissButton: .cancel(Text("OK"))
    )
  }
}

@MainActor
struct BroadcastBasePage: View {
  @Bindable var model: BroadcastBaseModel

  var body: some View {
    ZStack {
      // Background
      Color.black.edgesIgnoringSafeArea(.all)
      let _ = print("RENDERING BROADCASTBASEPAGE: \(model.id)")
      VStack(spacing: 0) {
        // Main content area based on selected tab
        if model.selectedTab == .schedule {
          ScheduleTabView(selectedStation: $model.selectedStation)
        } else {
          SongsTabView()
        }

        // Custom Tab Bar
        BroadcastTabBar(selectedTab: model.selectedTab) { tab in
          model.selectTab(tab)
        }
      }
    }
    .alert(item: $model.presentedAlert) { alert in
      alert.alert
    }
    .navigationTitle(model.selectedStation?.name ?? "My Station")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(content: {
      ToolbarItem(placement: .topBarLeading) {
        Image(systemName: "line.3.horizontal")
          .foregroundColor(.white)
          .onTapGesture {
            model.hamburgerButtonTapped()
          }
      }
    })
    .task {
      // This will run once when the view appears and cancel when it disappears
      await model.viewAppeared()
    }
  }
}

// MARK: - Tab Views
// Simple placeholder tab views

struct ScheduleTabView: View {
  @Binding var selectedStation: Station?

  var body: some View {
    if let selectedStation {
      BroadcastPage(model: BroadcastPageModel(station: selectedStation))
    } else {
      Spacer()
      Text("No Selected Station")
        .foregroundStyle(.white)
        .padding()
      Spacer()
    }
  }
}

struct SongsTabView: View {
  var body: some View {
    VStack {
      Spacer()
      Text("Songs Tab")
        .font(.title)
        .foregroundColor(.white)
      Text("Station songs placeholder")
        .foregroundColor(.gray)
        .padding()
      Spacer()
    }
  }
}

// MARK: - Custom Tab Bar
#Preview {
  NavigationStack {
    BroadcastBasePage(model: BroadcastBaseModel())
  }
  .onAppear {
    UINavigationBar.appearance().barStyle = .black
    UINavigationBar.appearance().tintColor = .white
  }
}
