//
//  NowPlayingPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/17/25.
//

import SwiftUI
import Combine

@Observable
class NowPlayingPageModel: ViewModel {
  var disposeBag: Set<AnyCancellable> = Set()

  // MARK: State
  var albumArtUrl: URL?
  var nowPlayingArtist: String = ""
  var nowPlayingTitle: String = ""
  var navigationBarTitle: String = ""
  var presentedSheet: PlayolaSheet?

  init(stationPlayer: StationPlayer? = nil, presentedSheet: PlayolaSheet? = nil) {
    self.stationPlayer = stationPlayer ?? StationPlayer.shared
  }

  // MARK: Dependencies
  @ObservationIgnored var stationPlayer: StationPlayer = StationPlayer.shared

  func viewAppeared() {
    if let currentStation = stationPlayer.state.currentStation {
      self.navigationBarTitle = "\(currentStation.name) \(currentStation.desc)"
    } else {
      self.navigationBarTitle = "Playola Radio"
    }
    processNewStationState(stationPlayer.state)

    stationPlayer.$state.sink { self.processNewStationState($0) }.store(in: &disposeBag)
    stationPlayer.$albumArtworkURL.sink { self.albumArtUrl = $0 }.store(in: &disposeBag)
  }

  func aboutButtonTapped() {
    self.presentedSheet = .about(AboutPageModel())
  }

  func airPlayButtonTapped() {}
  func infoButtonTapped() {}
  func shareButtonTapped() {}
  func dismissAboutSheetButtonTapped() {
    self.presentedSheet = nil
  }

  // MARK: Actions

  // MARK: Helpers
  func processNewStationState(_ state: StationPlayer.State) {
    switch state.playerStatus {
    case .loading:
      if let currentStation = stationPlayer.state.currentStation {
        self.nowPlayingArtist = "Station Loading..."
        self.nowPlayingTitle = "\(currentStation.name) \(currentStation.desc)"
      }
    case .readyToPlay:
      self.nowPlayingTitle = state.nowPlaying?.trackName ?? "-------"
      self.nowPlayingArtist = state.nowPlaying?.artistName ?? "-------"

    default:
      print("default")
    }
  }
}

struct NowPlayingView: View {
  @Bindable var model: NowPlayingPageModel

//  @State private var sliderValue: Double = .zero

  @MainActor
  init(model: NowPlayingPageModel? = nil) {
    self.model = model ?? NowPlayingPageModel()
    UINavigationBar.appearance().barStyle = .black
    UINavigationBar.appearance().tintColor = .white
    UINavigationBar.appearance().prefersLargeTitles = false
  }

  var body: some View {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      VStack {
//        AsyncImage(url: model.albumArtworkURL ??
//                   store.stationsManagerState.currentStation?.processedImageURL() ??
//                   Bundle.main.url(forResource: "AppIcon", withExtension: "PNG")
//        )
        AsyncImage(url: Bundle.main.url(forResource: "AppIcon", withExtension: "PNG"))
                   { result in
              result.image?
                  .resizable()
                  .scaledToFill()
                  .frame(width: 274, height: 274)
                  .padding(.top, 35)
          }

        HStack(spacing: 12) {
//              Image("btn-previous")
//                  .resizable()
//                  .frame(width: 45, height: 45)
//                  .onTapGesture {
//                      print("Back")
//                  }
//              Image("btn-play")
//                  .resizable()
//                  .frame(width: 45, height: 45)
//                  .onTapGesture {
//                      print("Back")
//                  }
//          Image(store.stationsManagerState.playbackState == .playing ? "btn-stop" : "btn-play")
          Image("btn-play")
                  .resizable()
                  .frame(width: 45, height: 45)
                  .onTapGesture {
                      print("Back")
                  }
//              Image("btn-next")
//                  .resizable()
//                  .frame(width: 45, height: 45)
//                  .onTapGesture {
//                      print("Back")
//                  }
          }
        .padding(.top, 30)

//        HStack {
//          Image("vol-min")
//            .frame(width: 18, height: 16)
//
//          Slider(value: $sliderValue)
//
//          Image("vol-max")
//            .frame(width: 18, height: 16)
//        }

        Text(model.nowPlayingTitle)
          .font(.title)

        Text(model.nowPlayingArtist)

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
    .edgesIgnoringSafeArea(.bottom)
    .onAppear {
      model.viewAppeared()
    }
    .foregroundColor(.white)
    .accentColor(.white)
    .navigationTitle(model.navigationBarTitle)
    .navigationBarTitleDisplayMode(.inline)

  }

}

#Preview {
  NavigationStack {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      NowPlayingView(model: NowPlayingPageModel(stationPlayer: .mock))
    }
  }
  .accentColor(.white)
}
