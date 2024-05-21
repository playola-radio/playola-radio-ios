//
//  StationListPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct StationListReducer {

  @ObservableState
  struct State: Equatable {
    var isLoadingStationLists: Bool = false
    var isShowingSecretStations: Bool = false
    var stationLists: IdentifiedArrayOf<StationList> = []
    var stationPlayerState: StationPlayer.State = StationPlayer.State(playbackState: .stopped)
  }

  enum Action {
    case alert(PresentationAction<Alert>)
    case viewAppeared
    case stationsListResponseReceived(Result<[StationList], Error>)
    case hamburgerButtonTapped
    case dismissAboutViewButtonTapped
    case stationPlayerStateDidChange(StationPlayer.State)
    case stationSelected(RadioStation)
  }

  @Dependency(\.apiClient) var apiClient
  @Dependency(\.stationPlayer) var stationPlayer

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .alert(_):
        return .none

      case .viewAppeared:
        state.isLoadingStationLists = true
        return .run { send in
          await withTaskGroup(of: Void.self) { group in
            group.addTask {
              await send(.stationsListResponseReceived(Result { try await self.apiClient.getStationLists() } ))
            }
            group.addTask {
              for await playerState in await self.stationPlayer.subscribeToPlayerState() {
                await send(.stationPlayerStateDidChange(playerState))
              }
            }
          }
        }

      case .stationsListResponseReceived(.success(let stationLists)):
        state.isLoadingStationLists = false
        let stationLists = stationLists.filter { state.isShowingSecretStations ? true : $0.id != "in_development" }
        state.stationLists = IdentifiedArray(uniqueElements: stationLists)
        return .none

      case .stationsListResponseReceived(.failure):
        state.isLoadingStationLists = false
        return .none

      case .hamburgerButtonTapped:
        return .none

      case .dismissAboutViewButtonTapped:
        return .none

      case .stationPlayerStateDidChange(let stationPlayerState):
        state.stationPlayerState = stationPlayerState
        return .none

      case .stationSelected(let station):
        return .run { send in
          self.stationPlayer.playStation(station)
        }
      }
    }
  }
}

struct StationListPage: View {
  @Bindable var store: StoreOf<StationListReducer>

  var body: some View {
    ZStack {
      Image("background")
        .resizable()
        .edgesIgnoringSafeArea(.all)

      VStack {
        List {
          ForEach(store.stationLists.filter { $0.stations.count > 0 }) { stationList in
            Section(stationList.title) {
              ForEach(stationList.stations.indices, id: \.self) { index in
                StationListCellView(station: stationList.stations[index])
                  .listRowBackground((index  % 2 == 0) ? Color(.clear) : Color(.black).opacity(0.2))
                  .listRowSeparator(.hidden)
                  .onTapGesture {
                    let station = stationList.stations[index]
                    self.store.send(.stationSelected(station))
                  }
              }
            }
          }
        }.listStyle(.grouped)
          .scrollContentBackground(.hidden)
          .background(.clear)
      }
    }
    .navigationTitle(Text("Playola Radio"))
    .navigationBarTitleDisplayMode(.automatic)
    .navigationBarHidden(false)
    .onAppear {
      self.store.send(.viewAppeared)
    }
    .foregroundStyle(.white)
  }
}

#Preview {
  NavigationStack {
    StationListPage(store: Store(initialState: StationListReducer.State()) {
      StationListReducer()
        ._printChanges()
    })
  }
  .onAppear {
    UINavigationBar.appearance().barStyle = .black
    UINavigationBar.appearance().tintColor = .white
    UINavigationBar.appearance().prefersLargeTitles = true
  }
}

