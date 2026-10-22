//
//  StationSetupPageView.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

struct StationSetupPageView: View {
  @Bindable var model: StationSetupPageModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        header
        setupRingHero
          .padding(.top, 18)
        componentsSection
          .padding(.top, 28)
        categorySection
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
      Text(model.inDevelopmentBadgeLabel)
        .font(.custom(FontNames.Inter_700_Bold, size: 9))
        .tracking(0.8)
        .textCase(.uppercase)
        .foregroundColor(.playolaRed)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(Color(hex: "#3A1212"))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
  }

  private var setupRingHero: some View {
    VStack(spacing: 8) {
      Text(model.setupEyebrow)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
        .tracking(1.4)
        .foregroundColor(.playolaGray)
      ZStack {
        Circle()
          .stroke(Color(hex: "#444444"), lineWidth: 7)
        Circle()
          .trim(from: 0, to: model.ringProgress)
          .stroke(model.ringColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Text(model.ringPercentLabel)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 26))
          .foregroundColor(.white)
      }
      .frame(width: 86, height: 86)
      .padding(.vertical, 6)
      Text(model.tagline)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
        .foregroundColor(.white)
    }
    .frame(maxWidth: .infinity)
  }

  private var componentsSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(model.componentsSectionTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
          .tracking(1.4)
          .foregroundColor(.playolaGray)
        Spacer()
        Text(model.componentsCompletionLabel)
          .font(.custom(FontNames.Inter_700_Bold, size: 9))
          .tracking(0.8)
          .foregroundColor(Color(hex: "#999999"))
      }
      .padding(.bottom, 8)

      ForEach(model.componentRows) { row in
        componentRow(row)
      }
    }
  }

  private func componentRow(_ row: StationSetupPageModel.ComponentRow) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Circle()
        .fill(Color(hex: "#1A1A1A"))
        .frame(width: 28, height: 28)
        .overlay(
          Image(systemName: row.iconSystemName)
            .font(.system(size: 13))
            .foregroundColor(row.tint)
        )
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(row.label)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
            .foregroundColor(.white)
          Spacer()
          Text(row.valueText)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
            .foregroundColor(row.tint)
        }
        componentProgressBar(progress: row.progress, fill: row.tint)
        Text(row.weightCaption)
          .font(.custom(FontNames.Inter_400_Regular, size: 9))
          .foregroundColor(Color(hex: "#999999"))
      }
    }
    .padding(.vertical, 10)
  }

  private func componentProgressBar(progress: Double, fill: Color) -> some View {
    Capsule()
      .fill(Color(hex: "#5E5F5F"))
      .frame(maxWidth: .infinity)
      .frame(height: 3)
      .overlay(alignment: .leading) {
        GeometryReader { geometry in
          Capsule()
            .fill(fill)
            .frame(width: geometry.size.width * progress)
        }
      }
  }

  private var categorySection: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(model.categorySectionTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
          .tracking(1.4)
          .foregroundColor(.playolaGray)
        Spacer()
        Text(model.categoryCountLabel)
          .font(.custom(FontNames.Inter_700_Bold, size: 9))
          .tracking(0.8)
          .foregroundColor(Color(hex: "#999999"))
      }
      .padding(.bottom, 8)

      // Rows are static for now (D1: the chevron is a visual affordance only, no navigation yet),
      // so they render as plain content rather than a Button with a no-op action.
      ForEach(model.categoryRows) { row in
        categoryRow(row)
      }
    }
  }

  private func categoryRow(_ row: StationSetupPageModel.CategoryRow) -> some View {
    HStack(spacing: 10) {
      Image(systemName: row.iconSystemName)
        .font(.system(size: 15))
        .foregroundColor(row.tint)
      Text(row.name)
        .font(.custom(FontNames.Inter_500_Medium, size: 12))
        .foregroundColor(.white)
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 8)
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 2)
          .fill(Color(hex: "#333333"))
        RoundedRectangle(cornerRadius: 2)
          .fill(row.tint)
          .frame(width: 66 * row.progress)
      }
      .frame(width: 66, height: 4)
      Text(row.countText)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 10))
        .foregroundColor(row.tint)
      Image(systemName: "chevron.right")
        .font(.system(size: 12))
        .foregroundColor(.playolaGray)
    }
    .padding(.vertical, 9)
  }
}

#Preview {
  StationSetupPageView(
    model: StationSetupPageModel(
      station: PlayolaPlayer.Station(
        id: "preview-station",
        name: "Southern Lines Radio",
        curatorName: "Preview Curator",
        imageUrl: String?.none,
        description: "",
        active: true,
        createdAt: Date(),
        updatedAt: Date()
      ))
  )
  .preferredColorScheme(.dark)
}
