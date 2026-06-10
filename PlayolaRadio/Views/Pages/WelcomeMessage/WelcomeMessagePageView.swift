//
//  WelcomeMessagePageView.swift
//  PlayolaRadio
//

import SDWebImageSwiftUI
import SwiftUI

private enum WelcomePalette {
  static let background = Color(hex: "#130000")
  static let cardSurface = Color(hex: "#3A1212")
  static let textSecondary = Color(hex: "#D7BFBF")
}

struct WelcomeMessagePageView: View {
  let model: WelcomeMessagePageModel

  var body: some View {
    GeometryReader { geo in
      VStack(spacing: 0) {
        ZStack(alignment: .bottom) {
          WebImage(url: model.imageURL) { image in
            image.resizable()
          } placeholder: {
            WelcomePalette.cardSurface
          }
          .aspectRatio(contentMode: .fill)
          .frame(width: geo.size.width, height: geo.size.height * 0.44)
          .clipped()

          LinearGradient(
            colors: [WelcomePalette.background.opacity(0), WelcomePalette.background],
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: 112)

          WelcomeEqualizerView()
            .opacity(model.equalizerOpacity)
            .animation(.easeInOut, value: model.equalizerOpacity)
            .padding(.bottom, 12)
        }
        .frame(height: geo.size.height * 0.44)

        VStack(spacing: 4) {
          Text(model.curatorName)
            .font(.custom(FontNames.Inter_700_Bold, size: 30))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
          Text(model.personalDJLabel.uppercased())
            .font(.custom(FontNames.Inter_500_Medium, size: 14))
            .kerning(1.7)
            .foregroundColor(.playolaRed)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)

        ZStack {
          VStack(spacing: 12) {
            ForEach(model.chips) { chip in
              WelcomeMessageChipView(chip: chip)
                .opacity(model.chipOpacity(chip))
                .offset(y: model.chipOffset(chip))
                .animation(
                  .timingCurve(0.32, 0.72, 0, 1, duration: 0.45),
                  value: model.chipOpacity(chip))
            }
          }
          .opacity(model.chipStackOpacity)

          TimelineView(.periodic(from: .now, by: 1)) { _ in
            WelcomeNowPlayingCardView(
              label: model.nowPlayingCardLabel,
              title: model.nowPlayingCardTitle,
              subtitle: model.nowPlayingCardSubtitle
            )
          }
          .opacity(model.nowPlayingCardOpacity)
        }
        .animation(.easeInOut(duration: 0.45), value: model.nowPlayingCardOpacity)
        .frame(maxWidth: 320)
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 24)

        VStack(spacing: 16) {
          GeometryReader { barGeo in
            ZStack(alignment: .leading) {
              Capsule().fill(Color.white.opacity(0.14))
              Capsule()
                .fill(Color.playolaRed)
                .frame(width: barGeo.size.width * model.progress)
            }
          }
          .frame(height: 3)
          .animation(.linear(duration: 0.12), value: model.progress)

          Button {
            Task { await model.primaryButtonTapped() }
          } label: {
            Text(model.primaryButtonTitle)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
              .foregroundColor(model.primaryButtonForeground)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 15)
              .background(
                RoundedRectangle(cornerRadius: 14).fill(model.primaryButtonBackground)
              )
              .shadow(
                color: Color.playolaRed.opacity(model.primaryButtonGlowOpacity),
                radius: 13
              )
          }
          .disabled(!model.isPrimaryButtonEnabled)
          .animation(.easeInOut(duration: 0.3), value: model.isPrimaryButtonEnabled)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 20)
      }
      .frame(width: geo.size.width, height: geo.size.height)
      .background(WelcomePalette.background.ignoresSafeArea())
      .overlay(alignment: .top) {
        Capsule()
          .fill(Color.white.opacity(0.5))
          .frame(width: 36, height: 5)
          .padding(.top, 10)
      }
      .overlay(alignment: .topTrailing) {
        Button {
          Task { await model.skipButtonTapped() }
        } label: {
          Text(model.skipButtonTitle)
            .font(.custom(FontNames.Inter_500_Medium, size: 14))
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .opacity(model.skipButtonOpacity)
        .animation(.easeInOut(duration: 0.4), value: model.skipButtonOpacity)
      }
    }
    .interactiveDismissDisabled()
    .task { await model.task() }
    .onDisappear { model.viewDisappeared() }
  }
}

struct WelcomeMessageChipView: View {
  let chip: WelcomeMessageChip

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(Color.playolaRed.opacity(0.18))
          .frame(width: 36, height: 36)
        Image(systemName: chip.systemImageName)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.playolaRed)
      }
      Text(chip.text)
        .font(.custom(FontNames.Inter_500_Medium, size: 16))
        .foregroundColor(.white)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(RoundedRectangle(cornerRadius: 14).fill(WelcomePalette.cardSurface))
  }
}

struct WelcomeNowPlayingCardView: View {
  let label: String
  let title: String
  let subtitle: String

  var body: some View {
    VStack(spacing: 8) {
      Text(label.uppercased())
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .kerning(1.7)
        .foregroundColor(WelcomePalette.textSecondary)
      Text(title)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 19))
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
      Text(subtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 15))
        .foregroundColor(WelcomePalette.textSecondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 20)
    .padding(.vertical, 20)
    .background(RoundedRectangle(cornerRadius: 16).fill(WelcomePalette.cardSurface))
  }
}

// Thin "audio is live" equalizer over the photo — staggered delays so the bars
// ripple rather than pulse in unison, reading as a real recording.
struct WelcomeEqualizerView: View {
  @State private var animating = false
  private let barDelays: [Double] = [0, 0.18, 0.36, 0.12, 0.3, 0.06, 0.24]

  var body: some View {
    HStack(spacing: 3) {
      Circle()
        .fill(Color.playolaRed)
        .frame(width: 7, height: 7)
        .opacity(animating ? 0.6 : 1)
        .animation(
          .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animating
        )
        .padding(.trailing, 4)
      ForEach(Array(barDelays.enumerated()), id: \.offset) { _, delay in
        Capsule()
          .fill(Color.white)
          .frame(width: 3, height: 16)
          .scaleEffect(y: animating ? 1 : 0.35, anchor: .center)
          .animation(
            .easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(delay),
            value: animating
          )
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 7)
    .background(Capsule().fill(Color.black.opacity(0.45)))
    .onAppear { animating = true }
  }
}
