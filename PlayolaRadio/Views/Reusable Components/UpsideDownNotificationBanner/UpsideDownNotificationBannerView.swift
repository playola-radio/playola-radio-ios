//
//  UpsideDownNotificationBannerView.swift
//  PlayolaRadio
//

import SwiftUI

struct UpsideDownNotificationBannerView: View {
  let model: UpsideDownNotificationBannerModel

  var body: some View {
    VStack(spacing: 0) {
      ForEach(model.visibleBanners) { banner in
        bannerCard(banner)
          .transition(.move(edge: .top).combined(with: .opacity))
          .task { await model.bannerAppeared() }
      }
    }
    .padding(.horizontal, 8)
    .animation(.easeInOut(duration: 0.3), value: model.banner)
  }

  private func bannerCard(_ banner: UpsideDownNotificationBannerModel.Banner) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image("LogoMark")
        .resizable()
        .scaledToFit()
        .frame(width: 32, height: 32)

      VStack(alignment: .leading, spacing: 2) {
        Text(banner.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
          .foregroundStyle(.white)
        Text(banner.body)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundStyle(Color.playolaGray)
          .lineLimit(4)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .background(Color.playolaSurfaceRaised, in: RoundedRectangle(cornerRadius: 18))
    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    .contentShape(RoundedRectangle(cornerRadius: 18))
    .onTapGesture { model.bannerTapped() }
    .gesture(
      DragGesture(minimumDistance: 10).onEnded {
        model.bannerDragEnded(verticalTranslation: $0.translation.height)
      }
    )
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
  }
}
