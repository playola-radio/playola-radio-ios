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
  static let placeholderImageURL = URL(string: "https://playola-static.s3.amazonaws.com/PlayolaBlankAlbumImage.png")!

  struct State: Equatable, Sendable {
    var stationPlayerState: StationPlayer.State = StationPlayer.State(playbackState: .stopped)
    var albumArtworkURL: URL = NowPlayingReducer.placeholderImageURL
  }

  enum Action: Equatable, Sendable {
    case viewAppeared
    case stationsPlayerStateDidChange(StationPlayer.State)
    case albumArtworkDidChange(URL?)
  }

  @Dependency(\.stationPlayer) var stationPlayer

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .stationsPlayerStateDidChange(stationPlayerState):
        state.stationPlayerState = stationPlayerState
        return .none
      case .viewAppeared:
        return .run { send in
          await withTaskGroup(of: Void.self) { group in
            group.addTask {
              for await managerState in await self.stationPlayer.subscribeToPlayerState() {
                await send(.stationsPlayerStateDidChange(managerState))
              }
            }
            group.addTask {
              for await url in await self.stationPlayer.subscribeToAlbumImageURL() {
                await send(.albumArtworkDidChange(url))
              }
            }
          }
        }
      case let .albumArtworkDidChange(albumArtworkURL):
        state.albumArtworkURL = albumArtworkURL ??
        state.stationPlayerState.currentStation?.processedImageURL() ??
        NowPlayingReducer.placeholderImageURL
        return .none
      }
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
    .onAppear {
      store.send(.viewAppeared)
    }
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
