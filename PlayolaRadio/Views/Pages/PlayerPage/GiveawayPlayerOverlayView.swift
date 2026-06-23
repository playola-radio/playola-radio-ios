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
    .frame(height: model.isVisible ? nil : 0)
    .opacity(model.overlayOpacity)
    .allowsHitTesting(model.isVisible)
    .clipped()
  }
}

private struct GiveawayOverlayPromptView: View {
  let model: GiveawayOverlayModel

  var body: some View {
    VStack(spacing: 0) {
      Text(model.headline)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 22))
        .tracking(0.4)
        .foregroundColor(.playolaRed)

      (Text(model.promptPrefix).foregroundColor(.white)
        + Text(model.promptOrdinal).foregroundColor(.playolaRed).fontWeight(.bold)
        + Text(model.promptSuffix).foregroundColor(.white))
        .font(.custom(FontNames.Inter_400_Regular, size: 15))
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.top, 8)

      Text(model.prizeText)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
        .lineSpacing(3)
        .padding(.top, 4)

      Button(
        action: { Task { await model.tapButtonTapped() } },
        label: {
          Text(model.buttonTitle)
            .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 20))
            .tracking(2)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(RoundedRectangle(cornerRadius: 27).fill(Color.playolaRed))
            .overlay(RoundedRectangle(cornerRadius: 27).stroke(Color.white, lineWidth: 3))
        }
      )
      .padding(.top, 20)
    }
    .frame(maxWidth: .infinity)
  }
}

private struct GiveawayOverlayStandbyView: View {
  let model: GiveawayOverlayModel

  var body: some View {
    VStack(spacing: 0) {
      Text(model.standbyText)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 18))
        .tracking(2)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(RoundedRectangle(cornerRadius: 32).fill(Color(hex: "#1A1A1A")))
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(Color(hex: "#3A3A3A"), lineWidth: 3))

      Text(model.standbySubtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(Color(hex: "#C7C7C7"))
        .multilineTextAlignment(.center)
        .lineSpacing(2)
        .padding(.top, 12)
    }
    .frame(maxWidth: .infinity)
  }
}

#if DEBUG
  @MainActor private func previewModel(tapped: Bool) -> GiveawayOverlayModel {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying.mockWith(
      station: AnyStation.mockPlayola(id: "preview-station"))
    @Shared(.activeGiveaway) var activeGiveaway = GiveawayEvent(
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
    return GiveawayOverlayModel()
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
