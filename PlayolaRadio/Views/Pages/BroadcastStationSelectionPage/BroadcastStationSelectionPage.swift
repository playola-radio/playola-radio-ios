//
//  BroadcastStationSelectionPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//

import SwiftUI
import PlayolaPlayer

struct BroadcastStationSelectionPage: View {
  @Bindable var model: BroadcastStationSelectionPageModel

  var body: some View {
    let _ = print("⚡️ View Rendering - isLoading: \(model.isLoading), stations: \(model.stations.count)")

    ZStack {
        if model.isLoading {
            BroadcastStationSelectionPageIsLoadingView()
        } else if let selectedStation = model.selectedStation {
            BroadcastBasePage(model: BroadcastBaseModel(station: selectedStation))
        } else {
            StationSelectionList(stations: model.stations, onStationSelected: model.stationSelected)
        }
    }
    .task {
        await model.viewAppeared()
    }
  }

  struct StationSelectionList: View {
    let stations: [PlayolaPlayer.Station]
    let onStationSelected: (PlayolaPlayer.Station) -> Void

    var body: some View {
      ScrollView {
        stationList
      }
      .navigationTitle("Select a Station")
      .navigationBarTitleDisplayMode(.inline)
      .background(Color.black)
    }

    private var stationList: some View {
      LazyVStack(spacing: 12) {
        ForEach(stations, id: \.id) { station in
          stationRow(for: station)
        }
      }
      .padding()
    }

    private func stationRow(for station: PlayolaPlayer.Station) -> some View {
      Button {
        onStationSelected(station)
      } label: {
        BroadcastStationSelectionRowContent(station: station)
      }
    }
  }
}

struct BroadcastStationSelectionPageIsLoadingView: View {
  var body: some View {
    ProgressView("Loading stations...")
      .foregroundColor(.white)
  }
}
