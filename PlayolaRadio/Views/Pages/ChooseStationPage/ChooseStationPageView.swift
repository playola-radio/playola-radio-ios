//
//  ChooseStationPageView.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

struct ChooseStationPageView: View {
  @Bindable var model: ChooseStationPageModel

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 1) {
        ForEach(model.sortedStations, id: \.id) { station in
          Button {
            model.stationTapped(station)
          } label: {
            StationRow(station: station)
          }
        }
      }
    }
    .background(Color.black)
    .navigationTitle("Choose Station")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.black, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
  }
}

private struct StationRow: View {
  let station: Station

  var body: some View {
    HStack(spacing: 16) {
      AsyncImage(url: station.imageUrl) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Color(white: 0.2)
      }
      .frame(width: 64, height: 64)
      .clipped()
      .cornerRadius(6)

      VStack(alignment: .leading, spacing: 2) {
        Text(station.curatorName)
          .font(.custom(FontNames.Inter_500_Medium, size: 22))
          .foregroundColor(.white)
          .multilineTextAlignment(.leading)

        Text(station.name)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.playolaGray)
          .multilineTextAlignment(.leading)
      }

      Spacer()

      Image(systemName: "chevron.right")
        .foregroundColor(.playolaGray)
        .font(.system(size: 14))
    }
    .padding(.horizontal)
    .padding(.vertical, 12)
  }
}

#Preview {
  NavigationStack {
    ChooseStationPageView(
      model: ChooseStationPageModel(
        stations: [.mock],
        onStationSelected: { _ in }
      )
    )
  }
  .preferredColorScheme(.dark)
}
