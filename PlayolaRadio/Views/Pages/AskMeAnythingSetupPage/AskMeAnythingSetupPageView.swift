//
//  AskMeAnythingSetupPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct AskMeAnythingSetupPageView: View {
  @Bindable var model: AskMeAnythingSetupPageModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        introCard
        Text(model.preparationReassurance)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaTextSecondary)
          .lineSpacing(4.8)
          .frame(maxWidth: .infinity)
          .multilineTextAlignment(.center)
          .padding(.top, 16)
      }
      .padding(.horizontal, 16)
      .padding(.top, 20)
    }
    .background(Color.playolaSurfaceBase)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Text(model.navigationTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
          .foregroundColor(.playolaTextPrimary)
      }
      ToolbarItem(placement: .topBarTrailing) {
        Text(model.setupLabel)
          .font(.custom(FontNames.Inter_400_Regular, size: 11))
          .foregroundColor(.playolaTextSecondary)
      }
    }
    .safeAreaInset(edge: .bottom) { bottomBar }
  }

  private var introCard: some View {
    VStack(alignment: .leading, spacing: 18) {
      ZStack {
        Circle()
          .fill(Color.playolaWarmSurface)
          .frame(width: 56, height: 56)
        Image(systemName: "mic.fill")
          .font(.system(size: 26))
          .foregroundColor(.playolaRed)
      }
      Text(model.introTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 21))
        .foregroundColor(.playolaTextPrimary)
      Text(model.introBody)
        .font(.custom(FontNames.Inter_400_Regular, size: 15))
        .foregroundColor(.playolaTextSecondary)
        .lineSpacing(6.75)
        .fixedSize(horizontal: false, vertical: true)
      recordIntroButton
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.playolaSurfaceSection)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.playolaGlassHairline, lineWidth: 1)
    )
  }

  private var recordIntroButton: some View {
    Button {
      model.recordIntroButtonTapped()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "mic.fill")
          .font(.system(size: 18))
        Text(model.recordIntroButtonTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
      }
      .foregroundColor(.playolaTextPrimary)
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(Color.playolaRed)
      .cornerRadius(12)
    }
    .buttonStyle(.plain)
  }

  private var bottomBar: some View {
    VStack(spacing: 8) {
      HStack {
        Text(model.preparedAudioLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
          .foregroundColor(.playolaTextPrimary)
        Spacer()
        Text(model.readinessHint)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaTextSecondary)
      }
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.playolaSurfaceControl)
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.playolaRed)
            .frame(width: proxy.size.width * model.readyProgress)
        }
      }
      .frame(height: 4)

      startShowButton
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.playolaSurfaceBase)
  }

  private var startShowButton: some View {
    Button {
      model.startShowButtonTapped()
    } label: {
      Text(model.startShowButtonTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        .foregroundColor(model.startShowButtonTitleColor)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Color.playolaSurfaceRaised)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.playolaGlassHairline, lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .disabled(!model.isStartShowEnabled)
  }
}

#Preview {
  NavigationStack {
    AskMeAnythingSetupPageView(model: AskMeAnythingSetupPageModel(stationId: "station-preview"))
  }
  .preferredColorScheme(.dark)
}
