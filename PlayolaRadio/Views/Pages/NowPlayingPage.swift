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
  
  @Reducer(state: .equatable)
  enum Destination {
    case add(AboutPageReducer)
    case dismiss
  }

  @ObservableState
  struct State: Equatable, Sendable {
    @Presents var destination: Destination.State?
    var stationPlayerState: StationPlayer.State = StationPlayer.State(playbackState: .stopped)
    var albumArtworkURL: URL = NowPlayingReducer.placeholderImageURL
  }

  enum Action {
    case viewAppeared
    case stationsPlayerStateDidChange(StationPlayer.State)
    case albumArtworkDidChange(URL?)
    case playButtonTapped
    case playolaIconTapped
    case dismissAboutViewButtonTapped
    case destination(PresentationAction<Destination.Action>)
    case showStationDetailButtonTapped
    case path(StackAction<StationDetailReducer.State, StationDetailReducer.Action>)

    case delegate(Delegate)

    enum Delegate {
      case pushStationDetailOntoNavStack(RadioStation)
    }
  }
  
  @Dependency(\.dismiss) var dismiss
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

      case .playButtonTapped:
        stationPlayer.stopStation()
        return .run { _ in
          await self.dismiss()
        }

      case .playolaIconTapped:
        state.destination = .add(AboutPageReducer.State())
        return .none
        
      case .dismissAboutViewButtonTapped:
        state.destination = nil
        return .none

      case .showStationDetailButtonTapped:
        if let station = state.stationPlayerState.currentStation {
          return .run { send in
            print("sending action")
            await send(.delegate(.pushStationDetailOntoNavStack(station)))
          }
        }
        return .none

      case .destination(.dismiss):
        state.destination = nil
        return .none

      case .destination(_):
        return .none

      case .destination(_):
        return .none

      case .path(_):
          return .none

      case .delegate(_):
        return .none
      }
    }
    
  }
}

struct NowPlayingPage: View {
  @Bindable var store: StoreOf<NowPlayingReducer>

  var body: some View {
    ZStack {
      Image("background")
        .resizable()
        .edgesIgnoringSafeArea(.all)

      VStack {
        AsyncImage(url: store.albumArtworkURL) { image in
          image
            .resizable()
            .scaledToFill()
            .padding(.top, 35)
        } placeholder: {
          Image("AppIcon")
        }
        .frame(width: 274, height: 274)

        HStack(spacing: 12) {
//              Image("btn-previous")
//                  .resizable()
//                  .frame(width: 45, height: 45)
//                  .onTapGesture {
//                      print("Back")
//                  }
          Image(store.stationPlayerState.playbackState == .playing ? "btn-stop" : "btn-play")
                  .resizable()
                  .frame(width: 45, height: 45)
                  .onTapGesture {
                    store.send(.playButtonTapped)
                  }
//              Image("btn-next")
//                  .resizable()
//                  .frame(width: 45, height: 45)
//                  .onTapGesture {
//                      print("Back")
//                  }
          }
        .padding(.top, 30)
        
        Text(store.stationPlayerState.nowPlaying?.trackName ??
             store.stationPlayerState.currentStation?.name ??
             "Unknown")
          .font(.title)

        Text(store.stationPlayerState.nowPlaying?.artistName ??
             store.stationPlayerState.currentStation?.desc ??
             "Track")


        Spacer()
        
        ZStack {
          HStack(alignment: .center) {
            Button(action: { store.send(.playolaIconTapped) }, label: {
              Image("PlayolaLogo")
                .resizable()
                .scaledToFit()
                .foregroundColor(Color(hex: "#7F7F7F"))
                .frame(width: 26, height: 26)
                .padding(.bottom, -5)
            })

            Spacer()

            Button(action: {}, label: {
              Image("share")
                .resizable()
                .foregroundColor(Color(hex: "#7F7F7F"))
                .frame(width: 26, height: 26)
                .padding(.bottom, 4)
            })

            Button(action: { store.send(.showStationDetailButtonTapped)}, label: {
              Image(systemName: "info.circle")
                .resizable()
                .foregroundColor(Color(hex: "#7F7F7F"))
                .frame(width: 22, height: 22)
            })

          }.padding(.leading, 35)
            .padding(.trailing, 35)
            .padding(.bottom, 15)

          AirPlayView()
            .frame(width: 42, height: 45)
            .padding(.bottom, 15)

        }

      }
    }
    .navigationTitle(store.stationPlayerState.currentStation?.longName ?? "")
    .edgesIgnoringSafeArea(.bottom)
    .foregroundColor(.white)
    .accentColor(.white)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      store.send(.viewAppeared)
    }
    .sheet(item: $store.scope(state: \.destination?.add, action: \.destination.add)) { store in
      NavigationStack {
        AboutPage(store: store)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button(action: { self.store.send(.dismissAboutViewButtonTapped) }) {
                Image(systemName: "xmark.circle.fill")
                  .resizable()
                  .frame(width: 32, height: 32)
                  .foregroundColor(.gray)
                  .padding(20)
              }
            }
          }
      }
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
