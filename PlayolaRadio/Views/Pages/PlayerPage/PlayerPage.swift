//
//  PlayerPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/12/25.
//

import SwiftUI

struct PlayerPage: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and station info
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }

                Spacer()

                VStack(spacing: 4) {
                    Text("Jacob Stelly's")
                        .font(.custom(FontNames.Inter_500_Medium, size: 20))
                        .foregroundColor(.white)
                    Text("Moondog Radio")
                        .font(.custom(FontNames.Inter_400_Regular, size: 14))
                        .foregroundColor(Color(hex: "#C7C7C7"))
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

          ScrollView {



            // Main Image
            AsyncImage(url: URL(string: "https://playola-static.s3.amazonaws.com/station-images/Jacob-Stelly-1-116029.jpg")) { image in
              image
                .resizable()
                .aspectRatio(contentMode: .fill)
            } placeholder: {
              Color(white: 0.2)
            }
            .frame(width: UIScreen.main.bounds.width - 148, height: UIScreen.main.bounds.width - 148)
            .cornerRadius(14)
            .padding(.top, 32)
            .padding(.horizontal, 74)

            // Now Playing Section
            VStack(alignment: .center, spacing: 4) {
              Text("NOW PLAYING")
                .font(.custom(FontNames.Inter_500_Medium, size: 12))
                .foregroundColor(.gray)

              Text("Jacob Stelly - Sweet Irene")
                .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
                .foregroundColor(.white)

              ProgressView(value: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.playolaRed))
                .cornerRadius(8)
                .scaleEffect(y: 2, anchor: .center)
                .padding(.top, 32)

              // Live indicator
              HStack(spacing: 8) {
                Text("ON AIR")
                  .font(.custom(FontNames.Inter_400_Regular, size: 12))
                  .foregroundColor(.gray)

                Spacer()

                Text("LIVE")
                  .font(.custom(FontNames.Inter_400_Regular, size: 12))
                  .foregroundColor(.gray)

                Image("LiveIcon")
                  .resizable()
                  .foregroundColor(Color.playolaRed)
                  .frame(width: 8, height: 8)
              }
              .padding(.top, 8)


            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.top, 32)

            // Play Button
            Button(action: {}) {
              Circle()
                .fill(Color.white)
                .frame(width: 80, height: 80)
                .overlay(
                  Image(systemName: "stop.fill")
                    .foregroundColor(.black)
                    .font(.system(size: 40))
                )
            }
            .padding(.top, 32)

            VStack(alignment: .leading, spacing: 16) {
              Text("Why I chose this song")
                .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 18))
                .foregroundColor(.white)

              Text("This song really hits home for me. It brings back memories of warm summer nights with friends, filled with laughter and joy. Its beautiful melodies and touching lyrics make it a special part of my musical journey, and I hope it resonates with others too.")
                .font(.custom(FontNames.Inter_400_Regular, size: 14))
                .foregroundColor(.gray)
                .lineSpacing(4)

              Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
                .font(.custom(FontNames.Inter_400_Regular, size: 14))
                .foregroundColor(.gray)
                .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(hex: "#333333"))
            .padding(.horizontal, 24)
            .padding(.top, 32)
          }
          .scrollIndicators(.hidden)

//            Spacer()
        }
        .background(Color.black)
    }
}

#Preview {
    PlayerPage()
        .preferredColorScheme(.dark)
}
