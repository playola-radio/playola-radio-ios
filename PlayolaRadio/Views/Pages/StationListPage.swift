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
  }

  enum Action {
    case alert(PresentationAction<Alert>)
    case viewAppeared
    case stationsListResponseReceived(Result<[StationList], Error>)
    case hamburgerButtonTapped
    case dismissAboutViewButtonTapped
  }

  @Dependency(\.apiClient) var apiClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .alert(_):
        return .none

      case .viewAppeared:
        state.isLoadingStationLists = true
        return .run { send in
          await send(.stationsListResponseReceived(Result { try await self.apiClient.getStationLists() } ))
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
  }
}

#Preview {
  StationListPage(store: Store(initialState: StationListReducer.State()) {
    StationListReducer()
      ._printChanges()
  })
}

