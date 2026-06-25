import SwiftUI

struct GiveawayCongratsSheetView: View {
  @Bindable var model: GiveawayCongratsSheetModel

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      VStack(spacing: 16) {
        Text(model.headline)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
          .foregroundColor(.white)
          .multilineTextAlignment(.center)

        Text(model.subtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(Color(hex: "#C7C7C7"))
          .multilineTextAlignment(.center)

        ZStack {
          LiveWaveformView(samples: model.waveformSamples)
            .opacity(model.recordingControlsOpacity)
          WaveformView(samples: model.waveformSamples)
            .opacity(model.reviewControlsOpacity)
        }
        .frame(height: 90)
        .padding(.top, 8)

        Text(model.durationText)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundColor(.white)

        Text(model.uploadStatusText)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(Color(hex: "#C7C7C7"))
          .opacity(model.uploadStatusOpacity)

        ZStack {
          GiveawayCongratsPrimaryButton(
            title: model.recordButtonTitle, action: { Task { await model.onRecordTapped() } }
          )
          .opacity(model.recordButtonOpacity)
          .allowsHitTesting(model.showsRecordButton)

          GiveawayCongratsPrimaryButton(
            title: model.stopButtonTitle, action: { Task { await model.onStopTapped() } }
          )
          .opacity(model.recordingControlsOpacity)
          .allowsHitTesting(model.showsRecordingControls)

          GiveawayCongratsReviewControls(model: model)
            .opacity(model.reviewControlsOpacity)
            .allowsHitTesting(model.showsReview)
        }
        .frame(height: 120)

        Button(
          action: { Task { await model.skipButtonTapped() } },
          label: {
            Text(model.skipButtonTitle)
              .font(.custom(FontNames.Inter_400_Regular, size: 14))
              .foregroundColor(Color(hex: "#868686"))
          }
        )
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 32)
    }
    .playolaAlert($model.presentedAlert)
    .task { await model.viewAppeared() }
  }
}

private struct GiveawayCongratsReviewControls: View {
  let model: GiveawayCongratsSheetModel

  var body: some View {
    VStack(spacing: 12) {
      Button(
        action: { Task { await model.onPlayPauseTapped() } },
        label: {
          Text("Play")
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
              RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#3A3A3A"), lineWidth: 2))
        }
      )
      Button(
        action: { Task { await model.sendButtonTapped() } },
        label: {
          Text(model.sendButtonTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.playolaRed))
        }
      )
      .disabled(model.sendButtonDisabled)
      .opacity(model.sendButtonOpacity)
    }
  }
}

private struct GiveawayCongratsPrimaryButton: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(
      action: action,
      label: {
        Text(title)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 18))
          .tracking(1)
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(RoundedRectangle(cornerRadius: 28).fill(Color.playolaRed))
      }
    )
  }
}

#if DEBUG
  #Preview("Congrats — record") {
    GiveawayCongratsSheetView(
      model: GiveawayCongratsSheetModel(action: .mock, onClose: {}))
  }
#endif
