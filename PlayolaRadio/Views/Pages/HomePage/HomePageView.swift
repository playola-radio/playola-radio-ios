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

  var body: some View {
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
            onIconTapped10Times: model.playolaIconTapped10Times)

          if model.hasUnreadSupportMessages {
            NewFeatureTile(model: model.supportMessageTileModel)
              .padding(.bottom, 20)
          }

          if model.hasScheduledShows {
            NewFeatureTile(model: model.scheduledShowsTileModel)
              .padding(.bottom, 20)
          }

          if model.hasUpcomingQuestionAiring {
            NewFeatureTile(model: model.questionAiringTileModel)
              .padding(.bottom, 20)
          }

          ListeningTimeTile(model: model.listeningTimeTileModel)

          HomePageStationList(
            stations: model.forYouStations,
            liveStatusForStation: model.liveStatusForStation
          ) { station in
            Task { await model.stationTapped(station) }
          }
        }
        .padding(.horizontal, 24)
        .scrollIndicators(.hidden)
      }
      .circleBackground(offsetY: -180)
    }
    .background(Color.black.ignoresSafeArea())
    .alert(item: $model.presentedAlert) { $0.alert }
    .onAppear { Task { await model.viewAppeared() } }
  }
}

struct HomePageView_Previews: PreviewProvider {
  static var previews: some View {
    HomePageView(model: HomePageModel())
      .preferredColorScheme(.dark)
  }
}
