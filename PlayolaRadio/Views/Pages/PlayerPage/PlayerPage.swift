//
//  PlayerPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/12/25.
//

import SwiftUI

struct PlayerPage: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) var scenePhase
  @Bindable var model: PlayerPageModel

  var body: some View {
    VStack(spacing: 0) {
      // Header with back button and station info
      HStack {
        Button(
          action: { dismiss() },
          label: {
            Image(systemName: "chevron.down")
              .foregroundColor(.white)
              .font(.system(size: 24))
          })

        Spacer()

        VStack(spacing: 4) {
          Text(model.primaryNavBarTitle)
            .font(.custom(FontNames.Inter_500_Medium, size: 20))
            .foregroundColor(.white)
          Text(model.secondaryNavBarTitle)
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(Color(hex: "#C7C7C7"))
        }

        Spacer()

        Button(
          action: {},
          label: {
            Image(systemName: "ellipsis")
              .foregroundColor(.white)
              .font(.system(size: 24))
          })
      }
      .padding(.horizontal)
      .padding(.top, 8)

      ScrollView {

        // Main Image
        AsyncImage(url: model.stationArtUrl) { image in
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

          Text(model.nowPlayingText)
            .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 20))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)

          ProgressView(value: model.loadingPercentage)
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
        Button(
          action: { model.playPauseButtonTapped() },
          label: {
            Circle()
              .fill(Color.white)
              .frame(width: 80, height: 80)
              .overlay(
                Image(systemName: model.playerButtonImageName.rawValue)
                  .foregroundColor(.black)
                  .font(.system(size: 40))
              )
          }
        )
        .padding(.top, 32)

        if let relatedText = model.relatedText {

          VStack(alignment: .leading, spacing: 16) {
            Text(relatedText.title)
              .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 18))
              .foregroundColor(.white)

            Text(relatedText.body)
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
      }
      .scrollIndicators(.hidden)

      //            Spacer()
    }
    .background(Color.black)
    .onChange(of: scenePhase) { _, newValue in
      model.scenePhaseChanged(newPhase: newValue)
    }
  }
}

#Preview {
  PlayerPage(model: PlayerPageModel())
    .preferredColorScheme(.dark)
}
