//
//  AboutPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct AboutPageReducer {
  struct State: Equatable, Sendable {}

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {

      case .binding:
        return .none
      }
    }
  }

}

struct AboutPage: View {
  @Bindable var store: StoreOf<AboutPageReducer>
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
  AboutPage(store: Store(initialState: AboutPageReducer.State()) {
    AboutPageReducer()
  })
}
