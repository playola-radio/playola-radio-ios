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
  @Reducer(state: .equatable)
  enum Destination {
    case add(AboutPageReducer)
  }
  
  @ObservableState
  struct State: Equatable {
    @Presents var destination: Destination.State?
    @Presents var alert: AlertState<Action.Alert>?
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
    case destination(PresentationAction<Destination.Action>)
    case dismissAboutViewButtonTapped
    case stationPlayerStateDidChange(StationPlayer.State)
    case stationSelected(RadioStation)
    case nowPlayingButtonTapped

    case path(StackAction<NowPlayingReducer.State, NowPlayingReducer.Action>)

    @CasePathable
    enum Alert: Equatable {}

    case delegate(Delegate)

    enum Delegate {
      case pushNowPlayingOntoNavStack
    }
  }
  
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.stationPlayer) var stationPlayer
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
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
        state.alert = .stationListLoadFailure
        return .none
        
      case .hamburgerButtonTapped:
        state.destination = .add(AboutPageReducer.State())
        return .none
        
      case .dismissAboutViewButtonTapped:
        state.destination = nil
        return .none
        
      case .nowPlayingButtonTapped:
        if let station = state.stationPlayerState.currentStation {
          return .run { send in
            await send(.delegate(.pushNowPlayingOntoNavStack))
          }
        }
        return .none

      case .stationPlayerStateDidChange(let stationPlayerState):
        state.stationPlayerState = stationPlayerState
        return .none
        
      case .stationSelected(let station):
        return .run { send in
          self.stationPlayer.playStation(station)
          await send(.delegate(.pushNowPlayingOntoNavStack))
        }
        
      case .alert(_):
        return .none

      case .destination(.dismiss):
        state.destination = nil
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
        
        NowPlayingSmallView(metadata: store.stationPlayerState.nowPlaying, stationName: store.stationPlayerState.currentStation?.name)
          .edgesIgnoringSafeArea(.bottom)
          .padding(.bottom, 5)
          .onTapGesture {
            store.send(.nowPlayingButtonTapped)
          }
      }
    }
    .navigationTitle(Text("Playola Radio"))
    .navigationBarTitleDisplayMode(.automatic)
    .navigationBarHidden(false)
    .toolbar(content: {
      ToolbarItem(placement: .topBarLeading) {
        Image(systemName: "line.3.horizontal")
          .foregroundColor(.white)
          .onTapGesture {
            self.store.send(.hamburgerButtonTapped)
          }
      }
      if let station = store.stationPlayerState.currentStation {
        ToolbarItem(placement: .topBarTrailing) {
          Image("btn-nowPlaying")
            .foregroundColor(.white)
            .onTapGesture {
              store.send(.nowPlayingButtonTapped)
            }
        }
      }
    })
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
    .onAppear {
      self.store.send(.viewAppeared)
    }
    .alert($store.scope(state: \.alert, action: \.alert))
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

extension AlertState where Action == StationListReducer.Action.Alert {
  static let stationListLoadFailure = AlertState(
    title: TextState("Error Loading Stations"),
    message: TextState("There was an error loading the stations. Please check yout connection and try again."))
}
