//
//  HomePageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import SwiftUI
import PlayolaPlayer

struct HomePageView: View {
  @Bindable var model: HomePageModel

  var body: some View {
    VStack {
      VStack {
        Text("Welcome, Brian")
          .font(.custom("SpaceGrotesk-Light_Bold", size: 32))
          .fontWeight(.bold)
          .foregroundColor(.white)
          .padding(.horizontal, 18)
          .padding(.top, 12)
          .padding(.bottom, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.black)

        ScrollView {
          HomeIntroSection(
            onIconTapped10Times: model.handlePlayolaIconTapped10Times)

          HomePageStationList(stations: model.forYouStations) {
            model.handleStationTapped($0)
          }
        }
        .padding(.horizontal, 24)
        .scrollIndicators(.hidden)
      }
      .circleBackground(offsetY: -180)
    }
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
