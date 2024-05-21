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
  struct State: Equatable {}

  enum Action {}

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      return .none
    }
  }
}



struct AppView: View {
  var store: StoreOf<AppReducer>

  @MainActor
  init(store: StoreOf<AppReducer>) {
    self.store = store
    UINavigationBar.appearance().barStyle = .black
    UINavigationBar.appearance().tintColor = .white
    UINavigationBar.appearance().prefersLargeTitles = true
  }

    var body: some View {
        StationListPage(
          store: Store(initialState: StationListReducer.State()) {
            StationListReducer()
          }
        )
    }
}

#Preview {
  NavigationStack {
    AppView(store: Store(initialState: AppReducer.State()) {
      AppReducer()
        ._printChanges()
    })
  }
}
