//
//  MyAiringsPage.swift
//  PlayolaRadio
//

import SDWebImageSwiftUI
import SwiftUI

struct MyAiringsPage: View {
  @Bindable var model: MyAiringsPageModel

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(model.navigationTitle)
          .font(.custom(FontNames.Inter_700_Bold, size: 24))
          .foregroundColor(.white)
        Spacer()
      }
      .padding(.horizontal, 24)
      .padding(.top, 20)
      .padding(.bottom, 12)

      if model.isLoading {
        Spacer()
        ProgressView()
          .tint(.white)
          .accessibilityLabel("Loading airings")
        Spacer()
      } else if model.showEmptyState {
        Spacer()
        VStack(spacing: 16) {
          Image(systemName: "mic.badge.plus")
            .font(.system(size: 48))
            .foregroundColor(.playolaGray)
          Text(model.emptyStateMessage)
            .font(.custom(FontNames.Inter_400_Regular, size: 16))
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
          Button {
            model.browseStationsTapped()
          } label: {
            Text(model.emptyStateButtonText)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
              .foregroundColor(.white)
              .padding(.horizontal, 20)
              .padding(.vertical, 10)
              .background(Color.playolaRed)
              .cornerRadius(4)
          }
        }
        Spacer()
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            if !model.upcomingAirings.isEmpty {
              sectionHeader("Upcoming")
              ForEach(model.upcomingAirings) { airing in
                airingRow(airing)
              }
            }

            if !model.pastAirings.isEmpty {
              sectionHeader("Past Airings")
              ForEach(model.pastAirings) { airing in
                airingRow(airing)
              }
            }
          }
          .padding(.horizontal, 24)
          .padding(.bottom, 24)
        }
      }
    }
    .background(Color.black)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .onAppear { Task { await model.viewAppeared() } }
    .onDisappear { model.viewDisappeared() }
    .playolaAlert($model.presentedAlert)
  }

  @ViewBuilder
  private func sectionHeader(_ title: String) -> some View {
    HStack {
      Text(title)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .foregroundColor(.white.opacity(0.7))
      Spacer()
    }
    .padding(.top, 20)
    .padding(.bottom, 8)
    .accessibilityAddTraits(.isHeader)
  }

  @ViewBuilder
  private func airingRow(_ airing: ListenerQuestionAiring) -> some View {
    HStack(spacing: 12) {
      stationImage(for: airing)

      VStack(alignment: .leading, spacing: 4) {
        Text(model.stationName(for: airing))
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)

        Text(model.formattedAirtime(airing.airtime))
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaGray)

        clipActionButtons(for: airing)
      }

      Spacer()
    }
    .padding(.vertical, 12)
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private func stationImage(for airing: ListenerQuestionAiring) -> some View {
    if let imageUrl = model.stationImageUrl(for: airing) {
      WebImage(url: imageUrl)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: 45, height: 45)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    } else {
      RoundedRectangle(cornerRadius: 4)
        .fill(Color(hex: "#666666"))
        .frame(width: 45, height: 45)
        .overlay(
          Image(systemName: "radio")
            .foregroundColor(Color(hex: "#999999"))
        )
    }
  }

  @ViewBuilder
  private func clipActionButtons(for airing: ListenerQuestionAiring) -> some View {
    switch model.clipState(for: airing) {
    case .upcoming:
      EmptyView()

    case .noClip:
      Button {
        Task { await model.createClipTapped(airing) }
      } label: {
        Label("Create Clip", systemImage: "waveform")
          .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
          .foregroundColor(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.playolaRed)
          .cornerRadius(4)
      }

    case .creating:
      HStack(spacing: 8) {
        ProgressView()
          .tint(.white)
          .scaleEffect(0.8)
        Text("Creating clip...")
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaGray)
      }
      .accessibilityLabel("Creating clip in progress")

    case .ready:
      readyClipButtons(for: airing)

    case .failed:
      Button {
        Task { await model.retryTapped(airing) }
      } label: {
        Label("Retry", systemImage: "arrow.clockwise")
          .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
          .foregroundColor(.error)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.error.opacity(0.15))
          .cornerRadius(4)
      }
    }
  }

  @ViewBuilder
  private func readyClipButtons(for airing: ListenerQuestionAiring) -> some View {
    HStack(spacing: 12) {
      Button {
        model.downloadTapped(airing)
      } label: {
        Label("Download", systemImage: "arrow.down.circle")
          .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
          .foregroundColor(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color(hex: "#444444"))
          .cornerRadius(4)
      }

      Button {
        model.shareTapped(airing)
      } label: {
        Label("Share", systemImage: "square.and.arrow.up")
          .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
          .foregroundColor(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.playolaRed)
          .cornerRadius(4)
      }
    }
  }
}

#Preview {
  NavigationStack {
    MyAiringsPage(model: MyAiringsPageModel())
  }
  .preferredColorScheme(.dark)
}
