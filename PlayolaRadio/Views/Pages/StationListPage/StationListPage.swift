//
//  StationListPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Combine
import SwiftUI
import IdentifiedCollections
import Sharing



extension PlayolaAlert {
  static var errorLoadingStations: PlayolaAlert {
    PlayolaAlert(
      title: "Error Loading Stations",
      message: "There was an error loading the stations. Please check your connection and try again.",
      dismissButton: .cancel(Text("OK"))
    )
  }
}

@MainActor
struct StationListPage: View {
  @Bindable var model: StationListModel

  var body: some View {
    ZStack {
      Image("background")
        .resizable()
        .edgesIgnoringSafeArea(.all)

      VStack {
        List {
          ForEach(model.stationLists
            .filter { $0.stations.count > 0 }
            .filter { model.showSecretStations ? true : $0.hidden != true })
          { stationList in
            Section(stationList.title) {
              ForEach(stationList.stations.indices, id: \.self) { index in
                StationListCellView(station: stationList.stations[index])
                  .listRowBackground((index % 2 == 0) ? Color(.clear) : Color(.black).opacity(0.2))
                  .listRowSeparator(.hidden)
                  .onTapGesture {
                    let station = stationList.stations[index]
                    model.stationSelected(station)
                  }
              }
            }
          }
        }.listStyle(.grouped)
          .scrollContentBackground(.hidden)
          .background(.clear)

        NowPlayingSmallView(artist: model.stationPlayerState.artistPlaying,
                            title: model.stationPlayerState.titlePlaying,
                            stationName: model.stationPlayer.currentStation?.name)
        .edgesIgnoringSafeArea(.bottom)
        .padding(.bottom, 5)
      }
    }
    .navigationTitle(Text("Playola Radio"))
    .navigationBarTitleDisplayMode(.automatic)
    .navigationBarHidden(false)
    .toolbar(content: {
      ToolbarItem(placement: .topBarLeading) {
        Image(systemName: "line.3.horizontal")
          .foregroundColor(.white)
          .onTapGesture {
            model.hamburgerButtonTapped()
          }
      }
      if model.stationPlayer.currentStation != nil {
        ToolbarItem(placement: .topBarTrailing) {
          Image("btn-nowPlaying")
            .foregroundColor(.white)
            .onTapGesture {
              model.nowPlayingToolbarButtonTapped()
            }
        }
      }
    })
    .sheet(item: $model.presentedSheet, content: { item in
      switch item {
      case let .about(aboutModel):
        NavigationStack {
          AboutPage(model: aboutModel)
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button(action: { model.dismissButtonInSheetTapped() }) {
                  Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.gray)
                    .padding(20)
                }
              }
            }
        }
      }
    })
    .onAppear {
      Task { await model.viewAppeared() }
    }
    .animation(nil)
    .foregroundStyle(.white)
  }
}

#Preview {
  NavigationStack {
    StationListPage(model: StationListModel())
  }
  .onAppear {
    UINavigationBar.appearance().barStyle = .black
    UINavigationBar.appearance().tintColor = .white
    UINavigationBar.appearance().prefersLargeTitles = true
  }
}
