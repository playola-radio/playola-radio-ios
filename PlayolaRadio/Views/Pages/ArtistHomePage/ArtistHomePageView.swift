//
//  ArtistHomePageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import SwiftUI

struct ArtistHomePageView: View {
  @Bindable var model: ArtistHomePageModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        header
        broadcastCard
          .padding(.top, 24)
        improveSection
          .padding(.top, 28)
        links
          .padding(.top, 20)
      }
      .padding(.horizontal, 20)
      .padding(.top, 28)
    }
    .background(Color.black)
  }

  private var header: some View {
    Text(model.stationName)
      .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 28))
      .foregroundColor(.white)
  }

  private var broadcastCard: some View {
    VStack(spacing: 10) {
      HStack {
        Text(model.onAirLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
          .tracking(1.2)
          .foregroundColor(.playolaGray)
        Spacer()
        HStack(spacing: 5) {
          Circle()
            .fill(model.broadcastStatusColor)
            .frame(width: 6, height: 6)
          Text(model.broadcastStatusLabel)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
            .foregroundColor(model.broadcastStatusColor)
        }
      }

      HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color(hex: "#4D4D4D"))
          .frame(width: 45, height: 45)
          .overlay(
            Image(systemName: "music.note")
              .font(.system(size: 20))
              .foregroundColor(Color(hex: "#999999"))
          )
        VStack(alignment: .leading, spacing: 2) {
          Text(model.nowPlayingTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
            .foregroundColor(.white)
          Text(model.nowPlayingSubtitle)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(.playolaGray)
        }
        Spacer(minLength: 0)
      }

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 2)
            .fill(Color(hex: "#5E5F5F"))
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.playolaRed)
            .frame(width: proxy.size.width * model.nowPlayingProgress)
        }
      }
      .frame(height: 4)

      HStack {
        HStack(spacing: 6) {
          Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.system(size: 13))
            .foregroundColor(Color(hex: "#999999"))
          Text(model.lastWentLiveLabel)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(Color(hex: "#999999"))
        }
        Spacer()
        Button {
          model.manageBroadcastTapped()
        } label: {
          HStack(spacing: 4) {
            Text(model.manageBroadcastLabel)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
              .foregroundColor(.playolaRed)
            Image(systemName: "chevron.right")
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(.playolaRed)
          }
        }
      }
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 14)
    .background(Color(hex: "#1A1A1A"))
    .cornerRadius(12)
  }

  private var improveSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Text(model.improveSectionTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
          .tracking(1.4)
          .foregroundColor(.playolaGray)
        Text(model.improvementCountLabel)
          .font(.custom(FontNames.Inter_700_Bold, size: 11))
          .foregroundColor(.playolaRed)
      }
      .padding(.bottom, 6)

      ForEach(model.improvementItems) { item in
        Button {
          model.improvementItemTapped(item)
        } label: {
          improvementRow(item)
        }
        Rectangle()
          .fill(Color(hex: "#1A1A1A"))
          .frame(height: 1)
      }
    }
  }

  private func improvementRow(_ item: ArtistHomePageModel.ImprovementItem) -> some View {
    HStack(spacing: 14) {
      Circle()
        .fill(Color(hex: "#1A1A1A"))
        .frame(width: 36, height: 36)
        .overlay(
          Image(systemName: item.icon)
            .font(.system(size: 16))
            .foregroundColor(item.iconTint)
        )
      VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
          .font(.custom(FontNames.Inter_500_Medium, size: 14))
          .foregroundColor(.white)
        Text(item.subtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(Color(hex: "#999999"))
      }
      Spacer(minLength: 0)
      Image(systemName: "chevron.right")
        .font(.system(size: 14))
        .foregroundColor(.playolaGray)
    }
    .padding(.vertical, 14)
  }

  private var links: some View {
    VStack(spacing: 0) {
      Button {
        model.showsRowTapped()
      } label: {
        linkRow(title: model.showsLinkTitle)
      }
      Button {
        model.musicLibraryRowTapped()
      } label: {
        linkRow(title: model.musicLibraryLinkTitle)
      }
    }
  }

  private func linkRow(title: String) -> some View {
    HStack {
      Text(title)
        .font(.custom(FontNames.Inter_500_Medium, size: 14))
        .foregroundColor(Color(hex: "#C7C7C7"))
      Spacer()
      Image(systemName: "chevron.right")
        .font(.system(size: 14))
        .foregroundColor(.playolaGray)
    }
    .padding(.vertical, 13)
  }
}

#Preview {
  ArtistHomePageView(model: ArtistHomePageModel())
    .preferredColorScheme(.dark)
}
