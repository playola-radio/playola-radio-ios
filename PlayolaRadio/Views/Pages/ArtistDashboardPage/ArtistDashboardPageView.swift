//
//  ArtistDashboardPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import SwiftUI

struct ArtistDashboardPageView: View {
  @Bindable var model: ArtistDashboardPageModel

  private let maxBarHeight: CGFloat = 39

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        header
        healthHero
          .padding(.top, 18)
          .frame(maxWidth: .infinity)
        listenersSection
          .padding(.top, 22)
        chartSection
          .padding(.top, 28)
        improveSection
          .padding(.top, 32)
      }
      .padding(.horizontal, 20)
      .padding(.top, 28)
    }
    .background(Color.black)
    .task { await model.viewAppeared() }
    .playolaAlert($model.presentedAlert)
  }

  private var header: some View {
    HStack {
      Text(model.navigationTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 28))
        .foregroundColor(.white)
      Spacer()
      Button {
        model.weeklyReportTapped()
      } label: {
        HStack(spacing: 7) {
          Text(model.weeklyReportLabel)
            .font(.custom(FontNames.Inter_500_Medium, size: 12))
            .foregroundColor(Color(hex: "#C7C7C7"))
          Text(model.weeklyReportTrendLabel)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
            .foregroundColor(model.weeklyReportTrendColor)
          Image(systemName: "chevron.right")
            .font(.system(size: 12))
            .foregroundColor(.playolaGray)
        }
      }
    }
  }

  private var healthHero: some View {
    VStack(spacing: 8) {
      Text(model.healthSectionTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
        .tracking(1.4)
        .foregroundColor(.playolaGray)
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
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 30))
          .foregroundColor(.white)
      }
      .frame(width: 96, height: 96)
      .padding(.vertical, 6)

      Text(model.healthStatusLabel)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        .foregroundColor(.white)
    }
  }

  private var listenersSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(model.listenersSectionTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
        .tracking(1.4)
        .foregroundColor(.playolaGray)
      HStack(spacing: 0) {
        ForEach(model.stats) { stat in
          VStack(spacing: 4) {
            Text(stat.value)
              .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 24))
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
  }

  private var chartSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(model.chartSectionTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 10))
          .tracking(1.1)
          .foregroundColor(.playolaGray)
        Spacer()
        Button {
          model.statsLinkTapped()
        } label: {
          Text(model.chartLinkLabel)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
            .foregroundColor(.playolaRed)
        }
      }
      HStack(alignment: .bottom, spacing: 8) {
        ForEach(model.weekBars) { bar in
          VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
              .fill(bar.barColor)
              .frame(maxWidth: 32)
              .frame(height: maxBarHeight * bar.heightFraction)
            Text(bar.label)
              .font(.custom(bar.labelFontName, size: bar.labelFontSize))
              .foregroundColor(bar.labelColor)
          }
          .frame(maxWidth: .infinity)
        }
      }
    }
  }

  private var improveSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(model.improveSectionTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
          .tracking(1.4)
          .foregroundColor(.playolaGray)
        Spacer()
        Text(model.improveCountLabel)
          .font(.custom(FontNames.Inter_700_Bold, size: 10))
          .tracking(0.8)
          .foregroundColor(model.improveCountColor)
      }
      .padding(.bottom, 8)

      ForEach(model.improvementItems) { item in
        Button {
          model.improvementItemTapped(item)
        } label: {
          improvementRow(item)
        }
        divider
      }
    }
  }

  private func improvementRow(_ item: ArtistDashboardPageModel.ImprovementItem) -> some View {
    HStack(spacing: 12) {
      Circle()
        .fill(item.iconBackgroundColor)
        .frame(width: 28, height: 28)
        .overlay(
          Circle()
            .stroke(item.iconBorderColor, lineWidth: 1.5)
        )
        .overlay(
          Image(systemName: item.icon)
            .font(.system(size: 13))
            .foregroundColor(item.iconColor)
        )
      VStack(alignment: .leading, spacing: 3) {
        Text(item.title)
          .font(.custom(item.titleFontName, size: 14))
          .foregroundColor(item.titleColor)
        Text(item.subtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(item.subtitleColor)
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 2)
            .fill(item.progressTrackColor)
          RoundedRectangle(cornerRadius: 2)
            .fill(item.progressColor)
            .frame(width: 84 * item.progress)
        }
        .frame(width: 84, height: 3)
      }
      Spacer(minLength: 0)
      Image(systemName: "chevron.right")
        .font(.system(size: 14))
        .foregroundColor(.playolaGray)
    }
    .padding(.vertical, 9)
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
