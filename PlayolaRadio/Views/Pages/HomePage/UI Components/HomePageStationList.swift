//
//  HomePageStationList.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/11/25.
//

import SwiftUI
import IdentifiedCollections

struct Station: Identifiable {
  let id = UUID()
  let name: String
  let stationName: String
  let description: String
  let imageUrl: String
}

struct StationCardView: View {
  let station: RadioStation
  let onRadioStationSelected: (RadioStation) -> Void

  var body: some View {
    Button(action: { onRadioStationSelected(station) }) {
      HStack(spacing: 0) {
        AsyncImage(url: URL(string: station.imageURL )) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Color(white: 0.3)
        }
        .frame(width: 160, height: 160)
        .clipped()
        
        // Right side - Text content
        VStack(alignment: .leading, spacing: 8) {
          Text(station.name)
            .font(.custom("Inter-Regular", size: 12))
            .foregroundColor(Color(hex: "#C7C7C7"))
          
          Text(station.desc)
            .font(.custom("SpaceGrotesk-Light_Bold", size: 16))
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.bottom, 4)
          
          Text(station.longDesc)
            .font(.custom("Inter-Regular", size: 14))
            .foregroundColor(Color(hex: "#C7C7C7"))
            .lineLimit(nil)
            .lineSpacing(4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity,
               maxHeight: 160,
               alignment: .leading)
      }
      .background(Color(white: 0.15))
      .cornerRadius(6)
    }
  }
}

struct HomePageStationList: View {
  var stations: IdentifiedArrayOf<RadioStation>
  var onRadioStationSelected: (RadioStation) -> Void

  var body: some View {
    VStack(alignment: .leading) {
      Text("Artist stations for you")
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
        .fontWeight(.bold)
        .foregroundColor(.white)
        .padding(.bottom, 8)

      VStack(spacing: 12) {  // Reduced spacing between cards
        ForEach(stations) { station in
          StationCardView(station: station) {
            onRadioStationSelected($0)
          }
        }
      }
    }
    .padding(.vertical, 20)
    .background(Color.black)
  }
}

struct HomePageStationList_Previews: PreviewProvider {
  static var previews: some View {
    HomePageStationList(stations: [.mock], onRadioStationSelected: { _ in })
      .preferredColorScheme(.dark)
      .padding(.horizontal, 24)
  }
}
