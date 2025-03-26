//
//  BroadcastBasePage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/26/25.
//

import Combine
import SwiftUI
import Sharing

enum MyStationTab {
    case schedule
    case songs
}

@MainActor
@Observable
class BroadcastBaseModel: ViewModel {
    var disposeBag: Set<AnyCancellable> = Set()

    // MARK: - State
    var selectedTab: MyStationTab = .schedule
    var presentedAlert: PlayolaAlert?
    var station: Station?
    var isLoading: Bool = false

    // MARK: - Dependencies
    @ObservationIgnored var navigationCoordinator: NavigationCoordinator
    @ObservationIgnored var api: API
    @ObservationIgnored @Shared(.currentUser) var currentUser: User?

    init(navigationCoordinator: NavigationCoordinator = .shared,
         api: API = API(),
         selectedTab: MyStationTab = .schedule) {
        self.navigationCoordinator = navigationCoordinator
        self.api = api
        self.selectedTab = selectedTab
    }

    // MARK: - Actions

    func viewAppeared() async {
        isLoading = true
        defer { isLoading = false }

        // Load the user's station if it exists
        if let userStation = currentUser?.stations?.first {
            station = userStation
        } else {
            // Create a mock station for development
            station = Station.mock
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

            VStack(spacing: 0) {
                // Main content area based on selected tab
                if model.selectedTab == .schedule {
                    ScheduleTabView()
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
        .navigationTitle(model.station?.name ?? "My Station")
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
        .onAppear {
            Task {
                await model.viewAppeared()
            }
        }
    }
}

// MARK: - Tab Views
// Simple placeholder tab views

struct ScheduleTabView: View {
    var body: some View {

          ScheduleEditorView(model: SchedulePageModel())

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
