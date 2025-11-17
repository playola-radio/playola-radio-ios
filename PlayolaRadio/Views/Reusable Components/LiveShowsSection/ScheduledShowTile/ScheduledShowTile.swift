//
//  ScheduledShowTile.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/16/25.
//
import SwiftUI

struct ScheduledShowTile: View {
  @Bindable var model: ScheduledShowTileModel

  var body: some View {
    VStack(alignment: .leading) {
      // Status badge
      HStack {
        if model.isLive {
          LiveNowBadge()
        } else {
          UpcomingBadge()
        }
      }
      .padding(.top, 2)

      VStack(alignment: .leading, spacing: 4) {
        // Show title
        Text(model.stationTitle)
          .font(.custom(FontNames.Inter_700_Bold, size: 20))
          .foregroundColor(.white)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text(model.showTitle)
          .font(.custom(FontNames.Inter_700_Bold, size: 14))
          .foregroundColor(Color(hex: "#F3F0EF"))
          .lineLimit(2)

        Text(model.timeDisplayString)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.white.opacity(0.7))
      }
      .padding(.bottom, 16)

      // Notify Me button
      NotifyMeButton(onTap: { Task { await model.notifyMeButtonTapped() } })
    }
    .padding(.vertical, 16)
    .padding(.horizontal, 20)
    .background(Color(white: 0.15))
    .cornerRadius(8)
    .alert(item: $model.presentedAlert) { $0.alert }
  }
}

private struct NotifyMeButton: View {
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 10) {
        Image("AlertMe")
          .resizable()
          .renderingMode(.template)
          .foregroundColor(.white.opacity(0.9))
          .frame(width: 22, height: 22)

        Text("Notify Me")
          .font(.custom(FontNames.Inter_500_Medium, size: 18))
          .foregroundColor(.white.opacity(0.9))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(Color.clear)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
}
