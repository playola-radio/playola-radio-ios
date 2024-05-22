//
//  NowPlayingPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/22/24.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct NowPlayingReducer {
  struct State: Equatable, Sendable {
  }

  enum Action: Equatable, Sendable {
  }

  @Dependency(\.uuid) var uuid

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      return .none
    }
  }
}

struct NowPlayingPage: View {
  @Bindable var store: StoreOf<NowPlayingReducer>

  var body: some View {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      VStack {
        Spacer()

        HStack {

          AirPlayView()
            .frame(width: 42, height: 45)

          Spacer()

          Button(action: {}, label: {
            Image("share")
              .resizable()
              .foregroundColor(Color(hex: "#7F7F7F"))
              .frame(width: 26, height: 26)
          })

          Button(action: {}, label: {
            Image(systemName: "info.circle")
              .resizable()
              .foregroundColor(Color(hex: "#7F7F7F"))
              .frame(width: 22, height: 22)
          })
        }.padding(.leading, 35)
          .padding(.trailing, 35)
      }
    }
    .navigationTitle("Station Name")
    .edgesIgnoringSafeArea(.bottom)
    .foregroundColor(.white)
    .accentColor(.white)
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      NowPlayingPage(
        store: Store(initialState: NowPlayingReducer.State()) {
          NowPlayingReducer()
        }
      )
      .onAppear {
        UINavigationBar.appearance().barStyle = .black
        UINavigationBar.appearance().tintColor = .white
      }
    }
  }
  .accentColor(.white)
  .foregroundStyle(.white)
}
