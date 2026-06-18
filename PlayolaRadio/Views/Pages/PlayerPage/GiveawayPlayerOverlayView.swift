import Sharing
import SwiftUI

struct GiveawayPlayerOverlayView: View {
  let model: GiveawayOverlayModel

  var body: some View {
    ZStack {
      GiveawayOverlayPromptView(model: model)
        .opacity(model.promptOpacity)
        .allowsHitTesting(model.promptInteractive)

      GiveawayOverlayStandbyView(model: model)
        .opacity(model.standbyOpacity)
        .allowsHitTesting(model.standbyInteractive)
    }
    .padding(.horizontal, 24)
    .padding(.top, 24)
    .frame(height: model.isVisible ? nil : 0)
    .opacity(model.overlayOpacity)
    .allowsHitTesting(model.isVisible)
    .clipped()
  }
}

private struct GiveawayOverlayPromptView: View {
  let model: GiveawayOverlayModel

  var body: some View {
    VStack(spacing: 12) {
      Text(model.headline)
        .font(.custom(FontNames.Inter_700_Bold, size: 20))
        .foregroundColor(.white)

      Text(model.promptText)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(Color(hex: "#C7C7C7"))
        .multilineTextAlignment(.center)

      Text(model.prizeName)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
        .foregroundColor(.white)
        .multilineTextAlignment(.center)

      Button(
        action: { Task { await model.tapButtonTapped() } },
        label: {
          Text(model.buttonTitle)
            .font(.custom(FontNames.Inter_700_Bold, size: 18))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.playolaRed))
        }
      )
      .padding(.top, 8)
    }
    .frame(maxWidth: .infinity)
    .padding(20)
    .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#1A1A1A")))
  }
}

private struct GiveawayOverlayStandbyView: View {
  let model: GiveawayOverlayModel

  var body: some View {
    VStack(spacing: 12) {
      Text(model.standbyText)
        .font(.custom(FontNames.Inter_700_Bold, size: 20))
        .foregroundColor(.white)

      Text(model.standbySubtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(Color(hex: "#C7C7C7"))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(20)
    .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#1A1A1A")))
  }
}

#if DEBUG
  @MainActor private func previewModel(tapped: Bool) -> GiveawayOverlayModel {
    @Shared(.activeGiveaway) var activeGiveaway = Giveaway(
      id: "preview-giveaway", stationId: "preview-station",
      prizeName: "Two tickets to Reckless Kelly at the Heights", winningNumber: 9, status: .open)
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] =
      tapped
      ? [
        "preview-giveaway": GiveawayParticipation(
          id: "preview-giveaway", stationId: "preview-station",
          prizeName: "Two tickets", winningNumber: 9, tapNumber: 7,
          status: .tappedStandby, tappedAt: Date())
      ] : [:]
    let model = GiveawayOverlayModel()
    model.debugForceVisible = true
    return model
  }

  #Preview("Overlay — Prompt") {
    ZStack {
      Color.black.ignoresSafeArea()
      GiveawayPlayerOverlayView(model: previewModel(tapped: false))
    }
  }

  #Preview("Overlay — Standby") {
    ZStack {
      Color.black.ignoresSafeArea()
      GiveawayPlayerOverlayView(model: previewModel(tapped: true))
    }
  }
#endif
