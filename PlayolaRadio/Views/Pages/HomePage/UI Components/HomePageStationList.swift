//
//  HomePageStationList.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/11/25.
//

import SwiftUI

struct Station: Identifiable {
    let id = UUID()
    let name: String
    let stationName: String
    let description: String
    let imageUrl: String
}

struct StationCardView: View {
  let station: Station
  
  var body: some View {
    HStack(spacing: 0) {
      AsyncImage(url: URL(string: station.imageUrl)) { image in
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
        Text(station.stationName)
          .font(.custom("Inter-Regular", size: 12))  // Smaller station name
          .foregroundColor(Color(hex: "#C7C7C7"))
        
        Text(station.name)
          .font(.custom("SpaceGrotesk-Light_Bold", size: 16))  // Adjusted name size
          .fontWeight(.bold)
          .foregroundColor(.white)
          .padding(.bottom, 4)
        
        Text(station.description)
          .font(.custom("Inter-Regular", size: 14))
          .foregroundColor(Color(hex: "#C7C7C7"))
          .lineLimit(nil)
          .lineSpacing(4)
//        Spacer()
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 20)
      .frame(maxWidth: .infinity,
             maxHeight: 160,
             alignment: .leading)
    }
    .background(Color(white: 0.15))
    .cornerRadius(6)
  }
}

struct HomePageStationList: View {
    // Sample data
    let stations = [
        Station(
            name: "Jacob Stelly",
            stationName: "Moondog Radio",
            description: "Hey fans, I'm really into classic country. Take a listen to my favs.",
            imageUrl: "https://playola-static.s3.amazonaws.com/station-images/Jacob-Stelly-1-116029.jpg"
        ),
        Station(
            name: "Bri Bagwell",
            stationName: "Banned Radio",
            description: "Hey fans, I'm really into classic country. Take a listen to my favs.",
            imageUrl: "https://playola-static.s3.amazonaws.com/bri_banned_logo.png"
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {  // Reduced spacing
            Text("Artist stations for you")
                .font(.custom("SpaceGrotesk-Light_Bold", size: 24))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.bottom, 8)  // Add some space after the header

            VStack(spacing: 12) {  // Reduced spacing between cards
                ForEach(stations) { station in
                    StationCardView(station: station)
                }
            }
        }
        .padding(.vertical, 20)
        .background(Color.black)
    }
}

struct HomePageStationList_Previews: PreviewProvider {
    static var previews: some View {
        HomePageStationList()
            .preferredColorScheme(.dark)
            .padding(.horizontal, 24)
    }
}
