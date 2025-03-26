//
//  ScheduleNowPlayingView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/26/25.
//
import SwiftUI
import PlayolaPlayer

struct ScheduleNowPlayingView: View {
  var spin: Spin

    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @State var secondsComplete: TimeInterval = 0.0
    @State var bigLiveNow = false

    var body: some View {
        HStack {
          if spin.audioBlock?.type == "commercial" {
            Image("greedyFace")
              .resizable()
              .frame(width: 45.0, height: 33.0)
              .padding(.zero)
          } else {
              AsyncImage(url: spin.audioBlock?.imageUrl) { image in
                    image
                        .resizable()
                        .frame(width: 45.0, height: 45.0)
                        .padding(.zero)
                } placeholder: {
                    Image("emptyAlbumWithOverlay")
                        .resizable()
                        .frame(width: 45.0, height: 45.0)
                        .padding(.zero)
                }
            }

            Spacer()
                .frame(width: 10)

            VStack {
                HStack {
                  Text(spin.audioBlock?.title ?? "-----")
                        .foregroundColor(.white)
                        .font(.custom("OpenSans-Bold", size: 12.0))
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                HStack {
                  Text(spin.audioBlock?.artist ?? "Rachel Loy")
                        .foregroundColor(.playolaGray)
                        .font(.custom("OpenSans-Semibold", size: 10.0))
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
            }
            Spacer()

            Image("liveNowIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: bigLiveNow ? 80 : 82)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: bigLiveNow ? 21 : 20))
        }
        .edgesIgnoringSafeArea(.all)
        .background(spin.audioBlock?.type == "commercial" ? Color.black : Color(hex: "333333"))
        .padding(.zero)
        .listRowInsets(EdgeInsets())
        .frame(height: spin.audioBlock?.type == "commercial" ? 33 : 45)

      ProgressView(value: secondsComplete, total: spin.endtime.timeIntervalSince1970 - spin.airtime.timeIntervalSince1970)
            .onReceive(timer) { _ in
              secondsComplete = Date().timeIntervalSince1970 - spin.airtime.timeIntervalSince1970
                bigLiveNow.toggle()
            }
            .progressViewStyle(LinearProgressViewStyle(tint: .playolaRed))
            .background(Color(hex: "5E5F5F"))
            .padding(.zero)
    }
}


struct NowPlayingView_Previews: PreviewProvider {
    static var previews: some View {
      ScheduleNowPlayingView(spin: Spin.mock)
    }
}
