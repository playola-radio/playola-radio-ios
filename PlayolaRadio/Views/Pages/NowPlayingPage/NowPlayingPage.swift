//
//  NowPlayingPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/17/25.
//

import SwiftUI

@MainActor
struct NowPlayingPage: View {
    @Bindable var model: NowPlayingPageModel

    var body: some View {
        NowPlayingView(model: model)
    }
}

@MainActor
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
                AsyncImage(url: model.albumArtUrl ??
                    Bundle.main.url(forResource: "AppIcon", withExtension: "PNG"), transaction: Transaction(animation: .bouncy()))
                { result in
                    result.image?
                        .resizable()
                        .scaledToFill()
                        .frame(width: 274, height: 274)
                        .padding(.top, 35)
                        .transition(.move(edge: .top))
                }
                .frame(width: 274, height: 274)

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
                    Image(model.stationPlayer.currentStation != nil ? "btn-stop" : "btn-play")
//          Image("btn-play")
                        .resizable()
                        .frame(width: 45, height: 45)
                        .onTapGesture {
                            model.stopButtonTapped()
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
                    .padding(.bottom, 75)
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

            NowPlayingPage(model: NowPlayingPageModel(
                stationPlayer: .shared))
        }
    }
    .accentColor(.white)
}
