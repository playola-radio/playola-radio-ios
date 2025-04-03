//
//  BroadcastStationSelectionPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//

import SwiftUI
import PlayolaPlayer

struct StationSelectionList: View {
    @Bindable var model: BroadcastStationSelectionPageModel

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
            ForEach(model.stations, id: \.id) { station in
                stationRow(for: station)
            }
        }
        .padding()
    }

    private func stationRow(for station: PlayolaPlayer.Station) -> some View {
        Button {
            model.stationSelected(station)
        } label: {
          BroadcastStationSelectionRowContent(station: station)
        }
    }
}


