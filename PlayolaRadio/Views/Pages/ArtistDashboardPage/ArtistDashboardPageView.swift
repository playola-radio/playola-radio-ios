//
//  ArtistDashboardPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import SwiftUI

struct ArtistDashboardPageView: View {
  @Bindable var model: ArtistDashboardPageModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        header
        healthHero
          .padding(.top, 28)
          .frame(maxWidth: .infinity)
        statsRow
          .padding(.top, 22)
        reportSection
          .padding(.top, 40)
      }
      .padding(.horizontal, 20)
      .padding(.top, 28)
    }
    .background(Color.black)
  }

  private var header: some View {
    Text(model.navigationTitle)
      .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 28))
      .foregroundColor(.white)
  }

  private var healthHero: some View {
    VStack(spacing: 14) {
      ZStack {
        Circle()
          .stroke(Color(hex: "#444444"), lineWidth: 8)
        Circle()
          .trim(from: 0, to: model.healthRingProgress)
          .stroke(
            model.healthRingColor,
            style: StrokeStyle(lineWidth: 8, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
        Text(model.healthScoreLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 36))
          .foregroundColor(.white)
      }
      .frame(width: 116, height: 116)

      VStack(spacing: 4) {
        Text(model.healthStatusLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundColor(.white)
        Text(model.healthWeakestLabel)
          .font(.custom(FontNames.Inter_500_Medium, size: 12))
          .foregroundColor(.warning)
      }
    }
  }

  private var statsRow: some View {
    HStack(spacing: 0) {
      ForEach(model.stats) { stat in
        VStack(spacing: 4) {
          Text(stat.value)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 24))
            .foregroundColor(.white)
          Text(stat.label)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 10))
            .tracking(1.1)
            .foregroundColor(.playolaGray)
        }
        .frame(maxWidth: .infinity)
      }
    }
  }

  private var reportSection: some View {
    VStack(spacing: 0) {
      divider
      Button {
        model.thisWeekReportTapped()
      } label: {
        HStack(spacing: 10) {
          Text(model.reportRowTitle)
            .font(.custom(FontNames.Inter_500_Medium, size: 14))
            .foregroundColor(.white)
          Spacer()
          Text(model.reportTrendLabel)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
            .foregroundColor(model.reportTrendColor)
          Image(systemName: "chevron.right")
            .font(.system(size: 14))
            .foregroundColor(.playolaGray)
        }
        .padding(.vertical, 16)
      }
      divider
    }
  }

  private var divider: some View {
    Rectangle()
      .fill(Color(hex: "#1A1A1A"))
      .frame(height: 1)
  }
}

#Preview {
  ArtistDashboardPageView(model: ArtistDashboardPageModel())
    .preferredColorScheme(.dark)
}
