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

enum MyStationTab {
  case schedule
  case songs
}

@MainActor
@Observable
class BroadcastBaseModel: ViewModel {
  var disposeBag: Set<AnyCancellable> = Set()

  // MARK: - State
  var id = UUID()
  var selectedTab: MyStationTab = .schedule
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
       selectedTab: MyStationTab = .schedule) {
    self.navigationCoordinator = navigationCoordinator
    self.api = api
    self.selectedTab = selectedTab
    super.init()
  }

  // MARK: - Actions
  func viewAppeared() async {
    defer { print("setting isLoading to false"); self.isLoading = false }
    isLoading = true
    do {
      print("Fetching stations...")
      let stations = try await apiClient.fetchUserStations(userId: auth.jwtUser!.id)
      self.stations = stations
      print("Stations fetched: \(self.stations.count)")

      if (self.stations.count >= 1) {
        print("Setting selectedStation to: \(self.stations[0].id)")
        selectedStation = self.stations[0]
        print("selectedStation now set to: \(selectedStation?.id ?? "nil") on \(self.id)")
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

  func selectTab(_ tab: MyStationTab) {
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

import SwiftUI

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
        CustomTabBar(selectedTab: model.selectedTab) { tab in
          model.selectTab(tab)
        }
      }
    }
    .alert(item: $model.presentedAlert) { alert in
      alert.alert
    }
    .navigationTitle("My Station")
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
      let _ = print("ScheduleTabView rendering with station: \(selectedStation.id)")
      BroadcastPage(model: BroadcastPageModel(station: selectedStation))
    } else {
      let _ = print("ScheduleTabView rendering with NO station")
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

struct CustomTabBar: View {
  var selectedTab: MyStationTab
  var onTabSelected: (MyStationTab) -> Void

  var body: some View {
    HStack(spacing: 0) {
      TabButton(
        title: "Schedule",
        systemImage: "calendar",
        isSelected: selectedTab == .schedule,
        action: { onTabSelected(.schedule) }
      )

      TabButton(
        title: "Songs",
        systemImage: "music.note.list",
        isSelected: selectedTab == .songs,
        action: { onTabSelected(.songs) }
      )
    }
    .frame(height: 60)
    .background(Color(hex: "#1C1C1E"))
    .edgesIgnoringSafeArea(.bottom)
  }
}

struct TabButton: View {
  var title: String
  var systemImage: String
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: systemImage)
          .font(.system(size: 24))

        Text(title)
          .font(.system(size: 12))
      }
      .foregroundColor(isSelected ? .white : .gray)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
    }
    .background(
      isSelected ?
      Color.playolaLightPurple.opacity(0.2) :
        Color.clear
    )
  }
}

#Preview {
  NavigationStack {
    BroadcastBasePage(model: BroadcastBaseModel())
  }
  .onAppear {
    UINavigationBar.appearance().barStyle = .black
    UINavigationBar.appearance().tintColor = .white
  }
}
