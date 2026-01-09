//
//  AiringTile.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//
import SwiftUI

struct AiringTile: View {
  @Bindable var model: AiringTileModel
  var presentAlert: (PlayolaAlert) -> Void = { _ in }

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        if model.isLive {
          LiveNowBadge()
        } else {
          UpcomingBadge(text: model.scheduleDisplayString)
        }
      }
      .padding(.top, 2)

      VStack(alignment: .leading, spacing: 5) {
        Text(model.showTitle)
          .font(.custom(FontNames.Inter_700_Bold, size: 20))
          .foregroundColor(.white)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)

        if !model.episodeTitle.isEmpty {
          Text(model.episodeTitle)
            .font(.custom(FontNames.Inter_700_Bold, size: 13))
            .foregroundColor(Color(hex: "#F3F0EF"))
            .lineLimit(2)
        }

        if !model.stationSubtitle.isEmpty {
          Text(model.stationSubtitle)
            .font(.custom(FontNames.Inter_500_Medium, size: 13))
            .foregroundColor(Color(hex: "#DDD7D5"))
            .lineLimit(2)
        }
      }
      .padding(.bottom, 16)

      switch model.buttonType {
      case .notifyMe:
        NotifyMeButton(onTap: { Task { await model.notifyMeButtonTapped() } })
      case .subscribed:
        SubscribedButton(onTap: { model.subscribedButtonTapped() })
      case .listenIn:
        ListenInButton(onTap: { model.listenInButtonTapped() })
      }
    }
    .padding(.vertical, 16)
    .padding(.horizontal, 20)
    .background(Color(white: 0.15))
    .cornerRadius(8)
    .alert(item: $model.presentedAlert) { alert in
      presentAlert(alert)
      return alert.alert
    }
    .task {
      await model.viewAppeared()
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

private struct SubscribedButton: View {
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 10) {
        Image(systemName: "checkmark.circle.fill")
          .resizable()
          .foregroundColor(Color(hex: "#4CAF50"))
          .frame(width: 22, height: 22)

        Text("Subscribed")
          .font(.custom(FontNames.Inter_500_Medium, size: 18))
          .foregroundColor(Color(hex: "#4CAF50"))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(Color.clear)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(hex: "#4CAF50"), lineWidth: 1.5)
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
