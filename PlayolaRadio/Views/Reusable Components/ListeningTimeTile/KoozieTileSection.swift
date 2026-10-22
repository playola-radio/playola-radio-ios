//
//  KoozieTileSection.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/10/26.
//

import SwiftUI

/// The koozie bottom-section of the Listening Time tile. Renders one of the three koozie
/// states off `model.mode`; all copy/behavior lives on the model. A reusable component
/// (not a page view), so the `switch` on `model.mode` is allowed.
struct KoozieTileSection: View {
  @Bindable var model: KoozieTileModel

  var body: some View {
    switch model.mode {
    case .inProgress: progressView
    case .claimable: claimableView
    case .earned: earnedView
    }
  }

  // MARK: - In progress

  private var progressView: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        koozieIcon(background: Color.gray900)
        VStack(alignment: .leading, spacing: 4) {
          Text(model.progressTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
            .foregroundColor(Color.textPrimary)
          Text(model.hoursToGoLabel)
            .font(.custom(FontNames.Inter_400_Regular, size: 13))
            .foregroundColor(Color.textSecondary)
        }
        Spacer()
        Text(model.progressPercentLabel)
          .font(.custom(FontNames.Inter_500_Medium, size: 13))
          .foregroundColor(Color.textSecondary)
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.gray900)
          Capsule().fill(Color.playolaRed)
            .frame(width: geo.size.width * model.progressFraction)
        }
      }
      .frame(height: 6)
    }
  }

  // MARK: - Claimable

  private var claimableView: some View {
    HStack(spacing: 12) {
      koozieIcon(background: Color.playolaRed)
      VStack(alignment: .leading, spacing: 4) {
        Text(model.claimableTitle)
          .font(.custom(FontNames.Inter_700_Bold, size: 16))
          .foregroundColor(.white)
        Text(model.claimableSubtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(Color.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer()
    }
    .padding(16)
    .background(Color.elevatedSurface)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Earned

  private var earnedView: some View {
    HStack(spacing: 12) {
      koozieIcon(background: Color.playolaRed, size: 28)
      Text(model.earnedText)
        .font(.custom(FontNames.Inter_500_Medium, size: 14))
        .foregroundColor(Color.textSecondary)
      Spacer()
    }
    .padding(12)
    .background(Color.cardSurface)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  // MARK: - Shared icon

  private func koozieIcon(background: Color, size: CGFloat = 40) -> some View {
    Image("koozie-icon")
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .foregroundColor(.white)
      .frame(width: size * 0.5, height: size * 0.5)
      .frame(width: size, height: size)
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
