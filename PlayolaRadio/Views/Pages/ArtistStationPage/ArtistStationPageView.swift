//
//  ArtistStationPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import SwiftUI

struct ArtistStationPageView: View {
  @Bindable var model: ArtistStationPageModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        header
        broadcastCard
          .padding(.top, 24)
        links
          .padding(.top, 20)
      }
      .padding(.horizontal, 20)
      .padding(.top, 28)
    }
    .background(Color.black)
    .task {
      await model.viewAppeared()
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(model.navigationTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 28))
        .foregroundColor(.white)
      Text(model.stationName)
        .font(.custom(FontNames.Inter_500_Medium, size: 13))
        .foregroundColor(Color(hex: "#999999"))
    }
  }

  private var broadcastCard: some View {
    Button {
      model.broadcastCardTapped()
    } label: {
      broadcastCardContent
    }
    .buttonStyle(.plain)
  }

  private var broadcastCardContent: some View {
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

      TimelineView(.periodic(from: .now, by: 0.5)) { _ in
        VStack(spacing: 10) {
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
        }
      }

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
        HStack(spacing: 4) {
          Text(model.viewFullScheduleLabel)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
            .foregroundColor(.playolaRed)
          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.playolaRed)
        }
      }
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 14)
    .background(Color(hex: "#1A1A1A"))
    .cornerRadius(12)
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
      Button {
        model.breakersLibraryRowTapped()
      } label: {
        linkRow(title: model.breakersLibraryLinkTitle)
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
  ArtistStationPageView(model: ArtistStationPageModel())
    .preferredColorScheme(.dark)
}
