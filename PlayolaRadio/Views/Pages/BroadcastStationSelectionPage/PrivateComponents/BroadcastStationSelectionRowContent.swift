//
//  BroadcastStationSelectionRowContent.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//
import SwiftUI
import PlayolaPlayer

struct BroadcastStationSelectionRowContent: View {
  let station: PlayolaPlayer.Station

  var body: some View {
    HStack(spacing: 12) {
      AsyncImage(url: station.imageUrl) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Color.gray.opacity(0.3)
      }
      .frame(width: 60, height: 60)
      .clipShape(RoundedRectangle(cornerRadius: 8))

      VStack(alignment: .leading, spacing: 4) {
        Text("\(station.curatorName)'s \(station.name)")
          .foregroundStyle(.white)
          .font(.headline)
      }

      Spacer()

      Image(systemName: "chevron.right")
        .foregroundStyle(.gray)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color.black.opacity(0.3))
    .cornerRadius(8)
  }
}
