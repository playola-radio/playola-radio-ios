//
//  HomePageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import SwiftUI
import PlayolaPlayer

struct HomePageView: View {
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
      ScrollView {
        VStack {
          HomeIntroSection()

          HomePageStationList()
        }
        .padding(.horizontal, 24)
      }
      .circleBackground(offsetY: -120)
    }
}

struct HomePageView_Previews: PreviewProvider {
    static var previews: some View {
        HomePageView()
            .preferredColorScheme(.dark)
    }
}
