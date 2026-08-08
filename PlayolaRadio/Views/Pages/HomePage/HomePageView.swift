import PlayolaPlayer
//
//  HomePageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import SwiftUI

struct HomePageView: View {
  @Bindable var model: HomePageModel

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    Group {
      if horizontalSizeClass == .regular {
        HomePagePadView(model: model)
      } else {
        compactBody
      }
    }
    .background(Color.black.ignoresSafeArea())
    .playolaAlert($model.presentedAlert)
    .onAppear { Task { await model.viewAppeared() } }
  }

  // MARK: - Compact (iPhone) layout — unchanged
  private var compactBody: some View {
    VStack {
      VStack {
        Text(model.welcomeMessage)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 32))
          .fontWeight(.bold)
          .foregroundColor(.white)
          .padding(.horizontal, 18)
          .padding(.top, 12)
          .padding(.bottom, 4)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.black)

        ScrollView {
          HomeIntroSection(
            introMessage: model.introMessage,
            onIconTapped10Times: model.playolaIconTapped10Times)

          ForEach(model.visibleFeatureTileModels, id: \.label) { tile in
            NewFeatureTile(model: tile)
              .padding(.bottom, 20)
          }

          ListeningTimeTile(model: model.listeningTimeTileModel)

          HomePageStationList(
            title: model.stationListTitle,
            stations: model.forYouStations,
            liveStatusForStation: model.liveStatusForStation,
            hasUpcomingGiveawayForStation: model.hasUpcomingGiveawayForStation
          ) { station in
            Task { await model.stationTapped(station) }
          }
        }
        .padding(.horizontal, 24)
        .scrollIndicators(.hidden)
      }
      .circleBackground(offsetY: -180)
    }
  }
}

struct HomePageView_Previews: PreviewProvider {
  static var previews: some View {
    HomePageView(model: HomePageModel())
      .preferredColorScheme(.dark)
  }
}
