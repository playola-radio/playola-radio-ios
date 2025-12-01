//
//  ScheduledShowTile.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/16/25.
//
import SwiftUI

struct ScheduledShowTile: View {
  @Bindable var model: ScheduledShowTileModel
  var presentAlert: (PlayolaAlert) -> Void = { _ in }

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

      VStack(alignment: .leading, spacing: 5) {
        // Show title
        Text(model.stationTitle)
          .font(.custom(FontNames.Inter_700_Bold, size: 20))
          .foregroundColor(.white)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text(model.showTitle)
          .font(.custom(FontNames.Inter_700_Bold, size: 13))
          .foregroundColor(Color(hex: "#F3F0EF"))
          .lineLimit(2)

        Text(model.timeDisplayString)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(Color(hex: "#DDD7D5"))
      }
      .padding(.bottom, 16)

      // Notify Me button
      if model.buttonType == .notifyMe {
        NotifyMeButton(onTap: { Task { await model.notifyMeButtonTapped() } })
      } else {
        ListenInButton(onTap: { model.listenInButtonTapped() })
      }

    }
    .padding(.vertical, 16)
    .padding(.horizontal, 20)
    .background(Color(white: 0.15))
    .cornerRadius(8)
    // Workaround: SwiftUI does not propagate alerts through ScrollViews
    .alert(item: $model.presentedAlert) { alert in
      presentAlert(alert)
      return alert.alert
    }
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
          .foregroundColor(.white)
          .frame(width: 22, height: 22)

        Text("Notify Me")
          .font(.custom(FontNames.Inter_500_Medium, size: 18))
          .foregroundColor(.white)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(Color.clear)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(hex: "#827876"), lineWidth: 1.5)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
}

private struct ListenInButton: View {
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 10) {
        Image("ListenInButtonIcon")
          .resizable()
          .renderingMode(.template)
          .foregroundColor(.white)
          .frame(width: 22, height: 22)

        Text("Listen In")
          .font(.custom(FontNames.Inter_500_Medium, size: 18))
          .foregroundColor(.white)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(Color.clear)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(hex: "#827876"), lineWidth: 1.5)
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
}
