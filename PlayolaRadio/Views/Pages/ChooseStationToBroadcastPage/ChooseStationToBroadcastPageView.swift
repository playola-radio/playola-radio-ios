//
//  ChooseStationToBroadcastPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/2/25.
//

import PlayolaPlayer
import SwiftUI

struct ChooseStationToBroadcastPageView: View {
  @Bindable var model: ChooseStationToBroadcastPageModel

  var body: some View {
    List {
      ForEach(model.sortedStations, id: \.id) { station in
        Text(model.displayName(for: station))
          .font(.custom(FontNames.Inter_500_Medium, size: 16))
          .foregroundColor(.white)
          .padding(.vertical, 12)
          .listRowBackground(Color.black)
          .listRowSeparatorTint(.playolaGray.opacity(0.3))
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color.black)
    .navigationTitle("Choose Station")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.black, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
  }
}

#Preview {
  let now = Date()
  let imageUrl: URL? = nil
  NavigationStack {
    ChooseStationToBroadcastPageView(
      model: ChooseStationToBroadcastPageModel(
        stations: [
          Station(
            id: "1", name: "Evening Vibes", curatorName: "Zara",
            imageUrl: imageUrl, description: "Description", createdAt: now, updatedAt: now),
          Station(
            id: "2", name: "Morning Show", curatorName: "Alex",
            imageUrl: imageUrl, description: "Description", createdAt: now, updatedAt: now),
          Station(
            id: "3", name: "Late Night Jams", curatorName: "Mike",
            imageUrl: imageUrl, description: "Description", createdAt: now, updatedAt: now),
        ]
      )
    )
  }
  .preferredColorScheme(.dark)
}
