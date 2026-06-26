import IdentifiedCollections
import Sharing
import SwiftUI

/// Player-page banner announcing an imminent Prize Giveaway for the now-playing station. Collapses to
/// zero height when there's nothing upcoming (mirrors `GiveawayPlayerOverlayView`), so it adds no
/// layout when hidden. Purely informational — no open time, no countdown.
struct UpcomingGiveawayBanner: View {
  let model: UpcomingGiveawayBannerModel

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "gift.fill")
        .font(.system(size: 16))
        .foregroundColor(.purple)

      Text(model.bannerText)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
        .foregroundColor(.white)
        .multilineTextAlignment(.leading)
        .lineLimit(2)
        .minimumScaleFactor(0.8)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.purple.opacity(0.18))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.purple.opacity(0.6), lineWidth: 1)
        )
    )
    .padding(.horizontal, 24)
    .frame(height: model.isVisible ? nil : 0)
    .opacity(model.bannerOpacity)
    .allowsHitTesting(false)
    .clipped()
  }
}

#if DEBUG
  @MainActor private func previewBannerModel() -> UpcomingGiveawayBannerModel {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying.mockWith(
      station: AnyStation.mockPlayola(id: "preview-station"))
    @Shared(.upcomingGiveaways) var upcomingGiveaways: IdentifiedArrayOf<UpcomingGiveawayInfo> = [
      UpcomingGiveawayInfo(
        stationId: "preview-station",
        event: GiveawayEvent(
          id: "preview-giveaway", stationId: "preview-station",
          prizeName: "Two tickets to Reckless Kelly", winningNumber: 9, status: .scheduled))
    ]
    return UpcomingGiveawayBannerModel()
  }

  #Preview("Upcoming Giveaway Banner") {
    ZStack {
      Color.black.ignoresSafeArea()
      UpcomingGiveawayBanner(model: previewBannerModel())
    }
  }
#endif
