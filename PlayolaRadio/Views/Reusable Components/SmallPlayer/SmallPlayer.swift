//
//  SmallPlayer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/16/25.
//

import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import SwiftUI

struct SmallPlayer: View {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    @Dependency(\.likesManager) var likesManager

    // Computed properties from nowPlaying data
    var mainTitle: String {
        nowPlaying?.currentStation?.name ?? ""
    }

    var secondaryTitle: String {
        if let artistPlaying = nowPlaying?.artistPlaying,
           let titlePlaying = nowPlaying?.titlePlaying
        {
            return "\(artistPlaying) - \(titlePlaying)"
        } else {
            return nowPlaying?.currentStation?.description ?? ""
        }
    }

    var artworkURL: URL {
        nowPlaying?.albumArtworkUrl
            ?? nowPlaying?.currentStation?.processedImageURL()
            ?? URL(string: "https://example.com")!
    }

    var currentAudioBlock: AudioBlock? {
        nowPlaying?.playolaSpinPlaying?.audioBlock
    }

    var isCurrentSongLiked: Bool {
        guard let audioBlock = currentAudioBlock else { return false }
        return likesManager.isLiked(audioBlock.id)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Player bar
            HStack(spacing: 16) {
                // Artwork
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 64, height: 64)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Title & subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(mainTitle)
                        .font(.custom(FontNames.Inter_500_Medium, size: 16))
                        .foregroundColor(.white)
                    Text(secondaryTitle)
                        .font(.custom(FontNames.Inter_400_Regular, size: 14))
                        .foregroundColor(Color(hex: "#C7C7C7"))
                }
                .padding(.vertical, 12)

                Spacer()

                // Heart button (only for songs)
                if let audioBlock = currentAudioBlock, audioBlock.type == "song" {
                    Button(
                        action: {
                            likesManager.toggleLike(audioBlock)
                        },
                        label: {
                            Image(systemName: isCurrentSongLiked ? "heart.fill" : "heart")
                                .foregroundColor(isCurrentSongLiked ? Color(hex: "#EF6962") : Color(hex: "#BABABA"))
                                .font(.system(size: 20))
                                .frame(width: 20, height: 20)
                        }
                    )
                    .padding(.trailing, 12)
                }

                Button(
                    action: { StationPlayer.shared.stop() },
                    label: {
                        Image(systemName: "stop.fill")
                            .foregroundColor(.black)
                            .frame(width: 34, height: 34)
                            .background(.white)
                            .clipShape(Circle())
                    }
                )
                .padding(.trailing, 24)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.85))

            // Progress bar
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.red)
                    .frame(width: geo.size.width)
                    .frame(maxHeight: 2, alignment: .leading)
                    .allowsHitTesting(false)
            }
            .frame(height: 2)
        }
    }
}

struct SmallPlayer_Previews: PreviewProvider {
    static var previews: some View {
        SmallPlayer()
    }
}
