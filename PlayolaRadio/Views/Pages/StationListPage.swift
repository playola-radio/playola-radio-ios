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

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .alert(_):
        return .none
      case .viewAppeared:
        return .none
      case .stationsListResponseReceived(_):
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
        EmptyView()

      }

//
    }
    .navigationTitle(Text("Playola Radio"))
    .navigationBarTitleDisplayMode(.automatic)
    .navigationBarHidden(false)
  }
}

#Preview {
  StationListPage(store: Store(initialState: StationListReducer.State()) {
    StationListReducer()
      ._printChanges()
  })
}

