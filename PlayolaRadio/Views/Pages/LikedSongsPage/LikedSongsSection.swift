//
//  LikedSongsSection.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SDWebImageSwiftUI
import SwiftUI

/// A vertical "Liked Songs" section: a large title header followed by a flat,
/// newest-first list of liked-song rows. Renders nothing when there are no songs.
struct LikedSongsSection: View {
  let title: String
  let songs: [(AudioBlock, Date)]
  let dateText: (Date) -> String
  let onMenuTapped: (AudioBlock, Date) -> Void

  var body: some View {
    ForEach(songs.isEmpty ? [] : [0], id: \.self) { _ in
      VStack(alignment: .leading, spacing: 0) {
        Text(title)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 28))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 20)
          .padding(.top, 24)
          .padding(.bottom, 8)

        ForEach(songs, id: \.0.id) { audioBlock, likedDate in
          LikedSongRow(
            audioBlock: audioBlock,
            dateText: dateText(likedDate),
            horizontalPadding: 20,
            onMenuTapped: { onMenuTapped(audioBlock, likedDate) }
          )
          .transition(
            .asymmetric(
              insertion: .opacity.combined(with: .move(edge: .trailing)),
              removal: .opacity.combined(with: .scale(scale: 0.95))
            ))
        }
      }
      .animation(.easeInOut(duration: 0.3), value: songs.map(\.0.id))
    }
  }
}

/// A single liked-song row: artwork, title, artist, liked-date, and a "…" menu button.
/// Reused by the full Liked Songs page and the Your Library section.
struct LikedSongRow: View {
  @Environment(\.displayScale) private var displayScale
  let audioBlock: AudioBlock
  let dateText: String
  var horizontalPadding: CGFloat = 24
  let onMenuTapped: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      WebImage(
        url: audioBlock.imageUrl,
        context: RemoteArtwork.downsampleContext(CGSize(width: 56, height: 56), scale: displayScale)
      ) { image in
        image
          .resizable()
          .scaledToFill()
      } placeholder: {
        RoundedRectangle(cornerRadius: 6)
          .fill(Color(hex: "#666666"))
          .overlay(
            Image(systemName: "music.note")
              .foregroundColor(Color(hex: "#999999"))
              .font(.system(size: 24))
          )
      }
      .frame(width: 56, height: 56)
      .cornerRadius(6)

      VStack(alignment: .leading, spacing: 2) {
        Text(audioBlock.title)
          .font(.custom(FontNames.Inter_500_Medium, size: 16))
          .foregroundColor(.white)
          .lineLimit(1)

        Text(audioBlock.artist)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(Color(hex: "#C7C7C7"))
          .lineLimit(1)

        Text(dateText)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(Color(hex: "#888888"))
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Spacer()

      Button(
        action: onMenuTapped,
        label: {
          Image(systemName: "ellipsis")
            .foregroundColor(Color(hex: "#C7C7C7"))
            .font(.system(size: 16))
        }
      )
    }
    .padding(.horizontal, horizontalPadding)
    .padding(.vertical, 8)
  }
}
