//
//  PlayerPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/12/25.
//

import PlayolaPlayer
import SDWebImageSwiftUI
import SwiftUI

struct PlayerPage: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) var scenePhase
  @Environment(\.displayScale) private var displayScale
  @Bindable var model: PlayerPageModel

  var body: some View {
    VStack(spacing: 0) {
      // Header with back button and station info
      HStack {
        Button(
          action: { dismiss() },
          label: {
            Image(systemName: "chevron.down")
              .foregroundColor(.white)
              .font(.system(size: 24))
          }
        )

        Spacer()

        VStack(spacing: 4) {
          Text(model.primaryNavBarTitle)
            .font(.custom(FontNames.Inter_500_Medium, size: 20))
            .foregroundColor(.white)
          Text(model.secondaryNavBarTitle)
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(Color(hex: "#C7C7C7"))
        }

        Spacer()

        Button(
          action: {},
          label: {
            Image(systemName: "ellipsis")
              .foregroundColor(.white)
              .font(.system(size: 24))
          }
        )
      }
      .padding(.horizontal)
      .padding(.top, 8)

      ScrollView {

        // Main Image
        HeroArtwork(url: model.stationArtUrl, displayScale: displayScale)
          .cornerRadius(14)
          .padding(.top, 32)
          .padding(.horizontal, 74)

        // Now Playing Section
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
              Text(model.nowPlayingLabel)
                .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
                .foregroundColor(Color(hex: "#C7C7C7"))

              Text(model.nowPlayingText)
                .font(.custom(FontNames.Inter_500_Medium, size: 20))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            }
            .layoutPriority(1)

            Spacer()

            HeartButton(state: model.heartState, onTap: { model.heartButtonTapped() })
              .layoutPriority(0)
          }

          ProgressView(value: model.loadingPercentage)
            .progressViewStyle(LinearProgressViewStyle(tint: Color.playolaRed))
            .cornerRadius(8)
            .scaleEffect(y: 2, anchor: .center)
            .padding(.top, 32)

          // Live indicator
          HStack(spacing: 8) {
            Text(model.onAirLabel)
              .font(.custom(FontNames.Inter_400_Regular, size: 12))
              .foregroundColor(.gray)

            Spacer()

            Text(model.liveLabel)
              .font(.custom(FontNames.Inter_400_Regular, size: 12))
              .foregroundColor(.gray)

            Image("LiveIcon")
              .resizable()
              .foregroundColor(Color.playolaRed)
              .frame(width: 8, height: 8)
          }
          .padding(.top, 8)

        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
        .padding(.top, 32)

        // Upcoming-giveaway banner (hidden until a giveaway is coming up for this station)
        UpcomingGiveawayBanner(model: model.upcomingGiveawayBannerModel)

        // Giveaway overlay (hidden until an open giveaway is live for this station)
        GiveawayPlayerOverlayView(model: model.giveawayOverlayModel)
          .padding(.top, 8)

        // Play Button
        Button(
          action: { model.playPauseButtonTapped() },
          label: {
            Circle()
              .fill(Color.white)
              .frame(width: 80, height: 80)
              .overlay(
                Image(systemName: model.playerButtonImageName.rawValue)
                  .foregroundColor(.black)
                  .font(.system(size: 40))
              )
          }
        )
        .padding(.top, 32)

        // Ask Question Button (hidden unless the now-playing station is a Playola station)
        AskArtistButton(
          isVisible: model.canAskQuestion,
          label: model.askArtistLabel,
          onTap: { model.askQuestionButtonTapped() })

        // Related-text card (hidden when the current spin has no related text)
        RelatedTextCard(relatedText: model.relatedText)
      }
      .scrollIndicators(.hidden)

      //            Spacer()
    }
    .background(Color.black)
    .onChange(of: scenePhase) { _, newValue in
      model.scenePhaseChanged(newPhase: newValue)
    }
  }
}

// The square station-art hero. A zero-intrinsic-size `Color` establishes the
// square slot: `.aspectRatio(1, contentMode: .fit)` sizes *the Color* to a square
// of the proposed (container) width synchronously on first layout, so the slot
// never collapses to zero and content doesn't jump. The `WebImage` is layered on
// top via `.overlay` so its own (possibly non-square) decoded intrinsic size can
// never drive layout — it is bounded by the square and `.clipped()` crops the
// `.fill` overflow. The rendered width is captured into `side` and used to size the
// downsample target; the URL is withheld until `side` is known so the image is
// never decoded at a zero (i.e. unbounded, full-resolution) size.
//
// Anchoring the square on the Color (not on the WebImage) is load-bearing: a
// non-square source decodes to a non-square bitmap (`imagePreserveAspectRatio`),
// and applying `.aspectRatio(1, .fit)` directly to the WebImage let that intrinsic
// size leak into layout under the ScrollView's unspecified height proposal —
// rendering some artwork oversized.
private struct HeroArtwork: View {
  let url: URL?
  let displayScale: CGFloat

  @State private var side: CGFloat = 0

  var body: some View {
    Color(white: 0.2)
      .aspectRatio(1, contentMode: .fit)
      .overlay {
        WebImage(
          url: side > 0 ? url : nil,
          context: RemoteArtwork.downsampleContext(
            CGSize(width: side, height: side),
            scale: displayScale)
        ) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Color.clear
        }
      }
      .clipped()
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.size.width
      } action: { width in
        // Ignore transient zero-width passes so a measured size is never cleared
        // (which would drop the loaded image back to the placeholder).
        if width > 0 { side = width }
      }
  }
}

// The like/unlike heart, shown only while a Playola song is playing. Collapses to nothing
// (occupying no space after the now-playing `Spacer()`) when `state` is `.hidden`.
private struct HeartButton: View {
  let state: PlayerPageModel.HeartState
  let onTap: () -> Void

  var body: some View {
    if state != .hidden {
      Button(
        action: onTap,
        label: {
          Image(systemName: state.imageName)
            .foregroundColor(Color(hex: state.imageColorHex))
            .font(.system(size: 24))
        }
      )
    }
  }
}

// The "Ask the Artist" button, shown only when the now-playing station is a Playola station.
// Collapses to nothing (no button, no top padding) when `isVisible` is false.
private struct AskArtistButton: View {
  let isVisible: Bool
  let label: String
  let onTap: () -> Void

  var body: some View {
    if isVisible {
      Button(
        action: onTap,
        label: {
          HStack(spacing: 8) {
            Image(systemName: "mic.fill")
              .font(.system(size: 14))
            Text(label)
              .font(.custom(FontNames.Inter_500_Medium, size: 14))
          }
          .foregroundColor(.white)
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(Color(hex: "#333333"))
          .cornerRadius(20)
        }
      )
      .padding(.top, 16)
    }
  }
}

// The related-text card ("Why I chose this song" / artist notes). Collapses to nothing (no card,
// no top padding) when there's no related text for the current spin. The optional is evaluated
// once at the call site and passed in, because `PlayerPageModel.relatedText` memoizes a random
// pick per spin and must not be read repeatedly.
private struct RelatedTextCard: View {
  let relatedText: RelatedText?

  var body: some View {
    if let relatedText {
      VStack(alignment: .leading, spacing: 16) {
        Text(relatedText.title)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 18))
          .foregroundColor(.white)

        Text(relatedText.body)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.gray)
          .lineSpacing(4)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
      .background(Color(hex: "#333333"))
      .padding(.horizontal, 24)
      .padding(.top, 32)
    }
  }
}

#Preview {
  PlayerPage(model: PlayerPageModel())
    .preferredColorScheme(.dark)
}
