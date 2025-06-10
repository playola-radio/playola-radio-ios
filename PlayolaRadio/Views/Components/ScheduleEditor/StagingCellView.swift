//
//  StagingCellView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/26/25.
//
import SwiftUI
import PlayolaPlayer

struct StagingCellView: View {
  var audioBlock: AudioBlock

    var body: some View {
        HStack {
          switch audioBlock.type {
            case "clientOnlyVoicetrack", "voicetrack":
                Image("voicetrackAlbumArtwork")
                    .resizable()
                    .frame(width: 45.0, height: 45.0)
                    .padding(.zero)

            default:
              AsyncImage(url: audioBlock.imageUrl) { image in
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
                  Text(audioBlock.title)
                        .foregroundColor(.white)
                        .font(.custom("OpenSans-Bold", size: 12.0))
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                HStack {
                  Text(audioBlock.artist)
                        .foregroundColor(.playolaGray)
                        .font(.custom("OpenSans-Semibold", size: 10.0))
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
            }

            Spacer()

          switch audioBlock.type {
            case "clientOnlyVoicetrack":
                Text("Uploading...")
                    .font(.custom("Lato-Regular", size: 14.0))
                    .foregroundColor(.playolaGray)
                    .padding(.trailing, 10)
            case "clientOnlySong":
                Text("Finding Song...")
                    .font(.custom("Lato-Regular", size: 14.0))
                    .foregroundColor(.playolaGray)
                    .padding(.trailing, 10)
            default:
                EmptyView()
            }

            ZStack {
              switch audioBlock.type {
                case "song", "voicetrack":
                    Image("songAcquisitionCheckMark")
                        .resizable()
                        .frame(width: 23, height: 23)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))
                default:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .foregroundColor(.white)
                        .frame(width: 23, height: 23)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10))
                }
            }

        }.frame(maxWidth: .infinity)
            .edgesIgnoringSafeArea(.all)
            .background(Color(hex: "333333"))
            .padding(.zero)
            .listRowInsets(EdgeInsets())
    }
}

struct StagingCellView_Previews: PreviewProvider {
    static var previews: some View {
      StagingCellView(audioBlock: .mock)
    }
}
