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
        header
        introCard
          .padding(.top, 24)
        Text(model.preparationReassurance)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(.playolaGray)
          .frame(maxWidth: .infinity)
          .multilineTextAlignment(.center)
          .padding(.top, 16)
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
    }
    .background(Color.black)
    .navigationBarTitleDisplayMode(.inline)
    .safeAreaInset(edge: .bottom) { bottomBar }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(model.navigationTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 26))
        .foregroundColor(.white)
      Spacer()
      Text(model.setupLabel)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .tracking(1.2)
        .foregroundColor(.playolaGray)
    }
  }

  private var introCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      ZStack {
        Circle()
          .fill(Color.playolaRed.opacity(0.15))
          .frame(width: 52, height: 52)
        Image(systemName: "mic.fill")
          .font(.system(size: 20))
          .foregroundColor(.playolaRed)
      }
      Text(model.introTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
        .foregroundColor(.white)
      Text(model.introBody)
        .font(.custom(FontNames.Inter_400_Regular, size: 15))
        .foregroundColor(Color(hex: "#B3B3B3"))
        .fixedSize(horizontal: false, vertical: true)
      recordIntroButton
        .padding(.top, 4)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(hex: "#1A1A1A"))
    .cornerRadius(16)
  }

  private var recordIntroButton: some View {
    Button {
      model.recordIntroButtonTapped()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "mic.fill")
          .font(.system(size: 15))
        Text(model.recordIntroButtonTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
      }
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 15)
      .background(Color.playolaRed)
      .cornerRadius(12)
    }
    .buttonStyle(.plain)
  }

  private var bottomBar: some View {
    VStack(spacing: 12) {
      VStack(spacing: 8) {
        HStack {
          Text(model.preparedAudioLabel)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(.white)
          Spacer()
          Text(model.readinessHint)
            .font(.custom(FontNames.Inter_400_Regular, size: 13))
            .foregroundColor(.playolaGray)
        }
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
              .fill(Color(hex: "#333333"))
            RoundedRectangle(cornerRadius: 2)
              .fill(Color.playolaRed)
              .frame(width: proxy.size.width * model.readyProgress)
          }
        }
        .frame(height: 4)
      }

      startShowButton
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .background(Color.black)
  }

  private var startShowButton: some View {
    Button {
      model.startShowButtonTapped()
    } label: {
      Text(model.startShowButtonTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
        .foregroundColor(model.startShowButtonTitleColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Color(hex: "#1A1A1A"))
        .cornerRadius(12)
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
