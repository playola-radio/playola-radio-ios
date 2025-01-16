//
//  ContentView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/19/24.
//

import ComposableArchitecture
import SwiftUI

// possibly use later for navigation
class ViewModel {
  static func == (lhs: ViewModel, rhs: ViewModel) -> Bool {
    ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}


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
    NavigationStack {
      StationListPage(
        model: StationListModel()
      )
    }
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
