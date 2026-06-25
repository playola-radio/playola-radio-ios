import Sharing
import SwiftUI

struct GiveawayPlayerOverlayView: View {
  let model: GiveawayOverlayModel

  var body: some View {
    ZStack {
      GiveawayOverlayPromptView(model: model)
        .opacity(model.promptOpacity)
        .allowsHitTesting(model.promptInteractive)

      GiveawayOverlayLoserRevealView(model: model)
        .opacity(model.loserRevealOpacity)
        .allowsHitTesting(model.loserRevealInteractive)
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

private struct GiveawayOverlayLoserRevealView: View {
  let model: GiveawayOverlayModel

  var body: some View {
    VStack(spacing: 0) {
      Image(systemName: "gift")
        .font(.system(size: 56, weight: .regular))
        .foregroundColor(.white)
        .opacity(0.4)

      Text(model.loserRevealHeadline)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 20))
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
        .lineSpacing(3)
        .padding(.top, 16)
    }
    .frame(maxWidth: .infinity)
  }
}

#if DEBUG
  @MainActor private func previewModel(lost: Bool) -> GiveawayOverlayModel {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying.mockWith(
      station: AnyStation.mockPlayola(id: "preview-station"))
    @Shared(.activeGiveaway) var activeGiveaway = GiveawayEvent(
      id: "preview-giveaway", stationId: "preview-station",
      prizeName: "Two tickets to Reckless Kelly at the Heights", winningNumber: 9, status: .open)
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] =
      lost
      ? [
        "preview-giveaway": GiveawayParticipation(
          id: "preview-giveaway", stationId: "preview-station",
          prizeName: "Two tickets", winningNumber: 9, tapNumber: 7,
          status: .resolvedLost(toastShown: false), tappedAt: Date())
      ] : [:]
    return GiveawayOverlayModel()
  }

  #Preview("Overlay — Prompt") {
    ZStack {
      Color.black.ignoresSafeArea()
      GiveawayPlayerOverlayView(model: previewModel(lost: false))
    }
  }

  #Preview("Overlay — Loser reveal") {
    ZStack {
      Color.black.ignoresSafeArea()
      GiveawayPlayerOverlayView(model: previewModel(lost: true))
    }
  }
#endif
