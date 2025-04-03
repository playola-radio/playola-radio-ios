//
//  BroadcastBasePage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/26/25.
//

import SwiftUI
import PlayolaPlayer

@MainActor
struct BroadcastBasePage: View {
  @Bindable var model: BroadcastBaseModel

  var body: some View {
    ZStack {
      // Background
      Color.black.edgesIgnoringSafeArea(.all)
      let _ = print("RENDERING BROADCASTBASEPAGE: \(model.id)")
      VStack(spacing: 0) {
          if model.selectedTab == .schedule {
            BroadcastPage(model: BroadcastPageModel(station: model.station))
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
//      await model.viewAppeared()
    }
  }
}

// MARK: - Tab Views
// Simple placeholder tab views
private struct EmptyStateView: View {
  var body: some View {
    VStack {
      Spacer()
      Text("No Stations Available")
        .foregroundStyle(.white)
        .padding()
      Text("Please contact support to create a station.")
        .foregroundStyle(.gray)
        .font(.subheadline)
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
    BroadcastBasePage(model: BroadcastBaseModel(station: .mock))
  }
  .onAppear {
    UINavigationBar.appearance().barStyle = .black
    UINavigationBar.appearance().tintColor = .white
  }
}
