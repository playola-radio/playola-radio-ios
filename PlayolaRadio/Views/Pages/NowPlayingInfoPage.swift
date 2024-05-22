//
//  NowPlayingInfoPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/22/24.
//

import SwiftUI

struct NowPlayingInfoPage: View {
  var station: RadioStation
  var onDismissButtonTapped: () -> Void = {}



    var body: some View {
      ZStack {
        Image("background")
          .resizable()
          .edgesIgnoringSafeArea(.all)
        
        VStack {
          HStack {
            AsyncImage(url: URL(string: station.imageURL)!) { image in
              image.resizable()
            } placeholder: {
              ProgressView().progressViewStyle(.circular)
            }
            .aspectRatio(contentMode: .fit)
            .frame(width: 68, height: 68)
            .padding(.trailing, 8)

            VStack(alignment: .leading) {
              Text(station.name)
                .font(.title3 )
              Text(station.desc)
            }

            Spacer()
          }
          .padding(.bottom, 20)

          Text(station.longDesc)
            .font(.subheadline)

          Spacer()

          Button(action: onDismissButtonTapped) {
            Text("Okay")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .background(Color(hex: "#333335"))
        }
        .padding()
      }
    }
}

#Preview {
  NavigationStack {
    NowPlayingInfoPage(station: RadioStation.mock)
      .foregroundStyle(.white)
  }

}
