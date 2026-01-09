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
            onIconTapped10Times: model.handlePlayolaIconTapped10Times)

          ListeningTimeTile(model: model.listeningTimeTileModel)

          if model.hasLiveShows {
            liveShowsSection()
          }

          HomePageStationList(stations: model.forYouStations) { station in
            Task { await model.handleStationTapped(station) }
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

  @ViewBuilder
  private func liveShowsSection() -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Stations broadcasting live")
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
        .foregroundColor(.white)

      AiringsListView(
        model: AiringsListModel(
          airings: model.airings.elements.filter { airing in
            let durationMS = airing.episode?.durationMS ?? 0
            let endTime = airing.airtime.addingTimeInterval(TimeInterval(durationMS) / 1000.0)
            return endTime > Date()
          }
        ),
        presentAlert: { model.presentedAlert = $0 }
      )
    }
    .padding(.top, 16)
  }
}

struct HomePageView_Previews: PreviewProvider {
  static var previews: some View {
    HomePageView(model: HomePageModel())
      .preferredColorScheme(.dark)
  }
}
