//
//  FlipToRecordOverlay.swift
//  PlayolaRadio
//

import SwiftUI

extension View {
  func flipToRecordOverlay(_ model: FlipToRecordModel) -> some View {
    accessibilityHidden(model.blocksUnderlyingAccessibility)
      .overlay { FlipToRecordOverlay(model: model) }
  }
}

struct FlipToRecordOverlay: View {
  @Environment(\.scenePhase) private var scenePhase
  let model: FlipToRecordModel

  var body: some View {
    ZStack {
      uprightHint
      countdown
      prompt
    }
    .animation(.easeInOut(duration: 0.25), value: model.phase)
    .onChange(of: scenePhase) { _, newPhase in
      Task { await model.scenePhaseChanged(newPhase: newPhase) }
    }
  }

  private var prompt: some View {
    ZStack(alignment: .bottom) {
      Color.black.opacity(0.6)
        .ignoresSafeArea()
        .onTapGesture { Task { await model.cancelTapped() } }

      VStack(spacing: 0) {
        Capsule()
          .fill(Color.textSecondary)
          .frame(width: 36, height: 5)
          .padding(.top, 10)
          .padding(.bottom, 18)

        Image("FlipToRecordIllustration")
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity)
          .frame(height: 220)
          .background(Color.playolaSurfaceRaised.opacity(0.6))
          .clipShape(RoundedRectangle(cornerRadius: 20))
          .accessibilityHidden(true)

        Text(model.promptTitle)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
          .foregroundStyle(Color.textPrimary)
          .multilineTextAlignment(.center)
          .padding(.top, 24)

        Text(model.promptBody)
          .font(.custom(FontNames.Inter_400_Regular, size: 15))
          .foregroundStyle(Color.textSecondary)
          .multilineTextAlignment(.center)
          .padding(.top, 12)

        HStack(spacing: 10) {
          Image(systemName: "arrow.clockwise")
            .foregroundStyle(Color.playolaRed)
          Text(model.waitingLabel)
        }
        .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        .foregroundStyle(Color.textPrimary)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Color.elevatedSurface, in: Capsule())
        .padding(.top, 20)

        Button(model.recordWithoutFlippingTitle) {
          Task { await model.recordWithoutFlippingTapped() }
        }
        .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
        .foregroundStyle(Color.playolaRed)
        .padding(.top, 22)

        Button(model.cancelTitle) {
          Task { await model.cancelTapped() }
        }
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundStyle(Color.textSecondary)
        .padding(.top, 18)
        .padding(.bottom, 12)
      }
      .padding(.horizontal, 24)
      .frame(maxWidth: .infinity)
      .background(
        UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
          .fill(Color.cardSurface)
          .ignoresSafeArea(edges: .bottom)
      )
    }
    .opacity(model.promptOpacity)
    .allowsHitTesting(model.isPromptVisible)
    .accessibilityHidden(!model.isPromptVisible)
  }

  private var countdown: some View {
    ZStack {
      Color.background.opacity(0.88)
        .ignoresSafeArea()
        .contentShape(Rectangle())

      VStack(spacing: 0) {
        Text(model.countdownLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundStyle(Color.textSecondary)

        Text(model.countdownNumber)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 80))
          .foregroundStyle(Color.textPrimary)
          .contentTransition(.numericText(countsDown: true))
          .frame(width: 180, height: 180)
          .overlay(Circle().stroke(Color.playolaRed, lineWidth: 4))
          .padding(.top, 20)

        Text(model.countdownCancelHint)
          .font(.custom(FontNames.Inter_400_Regular, size: 15))
          .foregroundStyle(Color.textPrimary)
          .multilineTextAlignment(.center)
          .padding(.top, 24)

        Button(model.cancelTitle) {
          Task { await model.cancelTapped() }
        }
        .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
        .foregroundStyle(Color.textSecondary)
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(Color.elevatedSurface, in: Capsule())
        .padding(.top, 28)
      }
      .padding(.horizontal, 24)
    }
    .opacity(model.countdownOpacity)
    .allowsHitTesting(model.isCountdownVisible)
    .accessibilityHidden(!model.isCountdownVisible)
  }

  private var uprightHint: some View {
    Label(model.uprightHint, systemImage: "arrow.counterclockwise")
      .font(.custom(FontNames.Inter_400_Regular, size: 16))
      .foregroundStyle(Color.textSecondary)
      .padding(.horizontal, 18)
      .padding(.vertical, 11)
      .background(Color.elevatedSurface, in: Capsule())
      .frame(maxHeight: .infinity, alignment: .bottom)
      .padding(.bottom, 16)
      .opacity(model.uprightHintOpacity)
      .allowsHitTesting(false)
      .accessibilityHidden(!model.isUprightHintVisible)
  }
}
