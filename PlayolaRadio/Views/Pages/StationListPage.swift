//
//  StationListPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import ComposableArchitecture
import SwiftUI
import Combine

@Observable
class StationListModel {
  var disposeBag: Set<AnyCancellable> = Set()

  // MARK: State
  var isLoadingStationLists: Bool = false
  var isShowingSecretStations: Bool = false
  var stationLists: IdentifiedArrayOf<StationList> = []
  var stationPlayerState: StationPlayer.State = StationPlayer.State(playbackState: .stopped)
  var presentedAlert: PlayolaAlert?

  @ObservationIgnored var api: API = API()
  @ObservationIgnored var stationPlayer: StationPlayer = StationPlayer.shared

  init(api:API? = nil, stationPlayer: StationPlayer? = nil) {
    self.api = api ?? API()
    self.stationPlayer = stationPlayer ?? StationPlayer.shared
  }

  // MARK: Actions
  func viewAppeared() async {
    self.isLoadingStationLists = true
    defer { self.isLoadingStationLists = false }
    do {
      let stationListsRaw = try await self.api.getStations()
      self.stationLists = IdentifiedArray(uniqueElements: stationListsRaw)
    } catch (_) {
      self.presentedAlert = .errorLoadingStations
    }
    self.stationPlayer.$state.sink { self.stationPlayerState = $0 }.store(in: &disposeBag)
  }
  func hamburgerButtonTapped() {}
  func dismissAboutViewButtonTapped() {}
  func stationSelected(_ station: RadioStation) {
    stationPlayer.set(station: station)
  }
}

extension PlayolaAlert {
  static var errorLoadingStations: PlayolaAlert {
    return PlayolaAlert(title: "Error Loading Stations",
                        message: "There was an error loading the stations. Please check yout connection and try again.",
                        dismissButton: .cancel(Text("OK")))
  }
}

struct StationListPage: View {
  @Bindable var model: StationListModel

  var body: some View {
    ZStack {
      Image("background")
        .resizable()
        .edgesIgnoringSafeArea(.all)
      
      VStack {
        List {
          ForEach(model.stationLists.filter { $0.stations.count > 0 }) { stationList in
            Section(stationList.title) {
              ForEach(stationList.stations.indices, id: \.self) { index in
                StationListCellView(station: stationList.stations[index])
                  .listRowBackground((index  % 2 == 0) ? Color(.clear) : Color(.black).opacity(0.2))
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
        
        NowPlayingSmallView(metadata: model.stationPlayerState.nowPlaying, stationName: model.stationPlayerState.currentStation?.name)
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
            self.model.hamburgerButtonTapped()
          }
      }
      if model.stationPlayerState.currentStation != nil {
        ToolbarItem(placement: .topBarTrailing) {
          Image("btn-nowPlaying")
            .foregroundColor(.white)
          
        }
      }
    })
//    .sheet(item: $store.scope(state: \.destination?.add, action: \.destination.add)) { store in
//      NavigationStack {
//        AboutPage(store: store)
//          .toolbar {
//            ToolbarItem(placement: .confirmationAction) {
//              Button(action: { self.store.send(.dismissAboutViewButtonTapped) }) {
//                Image(systemName: "xmark.circle.fill")
//                  .resizable()
//                  .frame(width: 32, height: 32)
//                  .foregroundColor(.gray)
//                  .padding(20)
//              }
//            }
//          }
//      }
//    }
    .onAppear {
      Task { await self.model.viewAppeared() }
    }
//    .alert($store.scope(state: \.alert, action: \.alert))
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
