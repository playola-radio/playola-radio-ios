//
//  ContentView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import ComposableArchitecture
import SwiftUI


@Reducer
struct AppReducer {
  @Reducer(state: .equatable)
  enum Path {
    case nowPlaying(NowPlayingReducer)
  }

  @ObservableState
  struct State: Equatable {
    var path = StackState<Path.State>()
    var stationListReducer = StationListReducer.State()
  }
  
  enum Action {
    case path(StackActionOf<Path>)
    case stationListReducer(StationListReducer.Action)
  }
  
  var body: some ReducerOf<Self> {
    Scope(state: \.stationListReducer, action: \.stationListReducer) {
      StationListReducer()
    }
    Reduce { state, action in
      switch action {
      case .path:
        return .none

      case .stationListReducer(.delegate(.pushNowPlayingOntoNavStack)):
        state.path.append(.nowPlaying(NowPlayingReducer.State()))
        return .none

      case .stationListReducer(_):
        return .none
      }
    }
    .forEach(\.path, action: \.path)
  }
}

struct AppView: View {
  @Bindable var store: StoreOf<AppReducer>

  @MainActor
  init(store: StoreOf<AppReducer>) {
    self.store = store
    UINavigationBar.appearance().barStyle = .black
    UINavigationBar.appearance().tintColor = .white
    UINavigationBar.appearance().prefersLargeTitles = true
  }
  
  var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      StationListPage(
        store: store.scope(state: \.stationListReducer,
                           action: \.stationListReducer)
      )
    } destination: { store in
      switch store.case {
      case let .nowPlaying(store):
        NowPlayingPage(store: store)
      }
    }
    .tint(.white)
  }
}

#Preview {
  NavigationStack {
    AppView(store: Store(initialState: AppReducer.State()) {
      AppReducer()
        ._printChanges()
    })
  }.accentColor(.white)
    .foregroundStyle(.white)
}
