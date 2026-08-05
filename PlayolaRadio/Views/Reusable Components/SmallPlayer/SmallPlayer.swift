//
//  SmallPlayer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/16/25.
//

import Dependencies
import Foundation
import PlayolaPlayer
import SDWebImageSwiftUI
import Sharing
import SwiftUI

struct SmallPlayer: View {
  @Environment(\.displayScale) private var displayScale
  @Shared(.nowPlaying) var nowPlaying: NowPlaying?
  @Dependency(\.likesManager) var likesManager
  @Dependency(\.stationPlayer) var stationPlayer

  /// `true` when hosted in the iOS 26.1+ Liquid Glass `tabViewBottomAccessory`:
  /// the player draws no background (system glass shows through), and shows the
  /// station artwork inset and smaller, Apple-Music style. `false` keeps the
  /// legacy opaque-black bar embedded above the tab bar (full-bleed art).
  var isGlassAccessory = false

  /// `true` once the glass subtitle has wrapped past a single line. When it has,
  /// the title/subtitle gap tightens so the extra line doesn't push the block
  /// apart; a single-line subtitle keeps the roomier default spacing.
  @State private var subtitleIsMultiline = false

  private var artworkSize: CGFloat { isGlassAccessory ? 40 : 64 }

  /// Gap between the title and subtitle. Tightens for a wrapped glass subtitle.
  private var titleSubtitleSpacing: CGFloat {
    guard isGlassAccessory else { return 4 }
    return subtitleIsMultiline ? 1 : 4
  }

  // Glass content uses vibrant hierarchical styles so it stays legible on the
  // system glass surface — a hardcoded white vanishes on light glass.
  private var titleStyle: AnyShapeStyle {
    isGlassAccessory ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.white)
  }
  private var subtitleStyle: AnyShapeStyle {
    isGlassAccessory ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color(hex: "#C7C7C7"))
  }
  private var heartStyle: AnyShapeStyle {
    if isCurrentSongLiked { return AnyShapeStyle(Color(hex: "#EF6962")) }
    return isGlassAccessory ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color(hex: "#BABABA"))
  }

  // Computed properties from nowPlaying data
  var mainTitle: String {
    nowPlaying?.currentStation?.name ?? ""
  }

  var secondaryTitle: String {
    if nowPlaying?.playbackStatus.isLoading == true {
      return "Loading..."
    }
    if let artistPlaying = nowPlaying?.artistPlaying,
      let titlePlaying = nowPlaying?.titlePlaying
    {
      return "\(artistPlaying) - \(titlePlaying)"
    } else {
      return nowPlaying?.currentStation?.description ?? ""
    }
  }

  var artworkURL: URL {
    if isGlassAccessory {
      // Glass mini player represents the station, so lead with the station art.
      return nowPlaying?.currentStation?.processedImageURL()
        ?? nowPlaying?.albumArtworkUrl
        ?? URL(string: "https://example.com")!
    }
    return nowPlaying?.albumArtworkUrl
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

  // Glass: a small plain glyph like Apple Music. Legacy: black icon on a white circle.
  @ViewBuilder
  private var stopButtonLabel: some View {
    if isGlassAccessory {
      Image(systemName: "stop.fill")
        .font(.system(size: 22))
        .foregroundStyle(.primary)
        .frame(width: 28, height: 28)
    } else {
      Image(systemName: "stop.fill")
        .foregroundColor(.black)
        .frame(width: 34, height: 34)
        .background(.white)
        .clipShape(Circle())
    }
  }

  // MARK: - Body
  var body: some View {
    VStack(spacing: 0) {
      // Player bar
      HStack(spacing: isGlassAccessory ? 12 : 16) {
        // Artwork
        WebImage(
          url: artworkURL,
          context: RemoteArtwork.downsampleContext(
            CGSize(width: artworkSize, height: artworkSize), scale: displayScale)
        ) { image in
          image
            .resizable()
            .scaledToFill()
        } placeholder: {
          Color.gray.opacity(0.3)
        }
        .frame(width: artworkSize, height: artworkSize)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: isGlassAccessory ? 8 : 6))
        .padding(.leading, isGlassAccessory ? 6 : 0)

        // Title & subtitle
        VStack(alignment: .leading, spacing: titleSubtitleSpacing) {
          Text(mainTitle)
            .font(.custom(FontNames.Inter_500_Medium, size: isGlassAccessory ? 13 : 16))
            .foregroundStyle(titleStyle)
            .lineLimit(isGlassAccessory ? 1 : nil)
          Text(secondaryTitle)
            .font(.custom(FontNames.Inter_400_Regular, size: isGlassAccessory ? 11 : 14))
            .foregroundStyle(subtitleStyle)
            .lineLimit(isGlassAccessory ? 2 : nil)
            .fixedSize(horizontal: false, vertical: isGlassAccessory)
            .onGeometryChange(for: CGFloat.self) {
              $0.size.height
            } action: { height in
              // A single 11pt line is ~15pt tall; two lines clear 20pt.
              subtitleIsMultiline = height > 20
            }
        }
        .padding(.vertical, isGlassAccessory ? 0 : 12)

        Spacer()

        // Heart button (only for songs)
        if let audioBlock = currentAudioBlock, audioBlock.type == "song" {
          Button(
            action: {
              likesManager.toggleLike(audioBlock)
            },
            label: {
              Image(systemName: isCurrentSongLiked ? "heart.fill" : "heart")
                .foregroundStyle(heartStyle)
                .font(.system(size: 20))
                .frame(width: 20, height: 20)
            }
          )
          .padding(.trailing, 12)
        }

        Button(
          action: { stationPlayer.stop() },
          label: { stopButtonLabel }
        )
        .padding(.trailing, isGlassAccessory ? 16 : 24)
      }
      .padding(.horizontal)
      .padding(.vertical, isGlassAccessory ? 12 : 8)
      .background(isGlassAccessory ? Color.clear : Color.black.opacity(0.85))

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
    .background(isGlassAccessory ? Color.clear : Color.black)
  }
}

struct SmallPlayer_Previews: PreviewProvider {
  static var previews: some View {
    SmallPlayer()
  }
}
