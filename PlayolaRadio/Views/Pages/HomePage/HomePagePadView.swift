//
//  HomePagePadView.swift
//  PlayolaRadio
//
//  iPad-only (regular horizontal size class) layout for the Home screen.
//
//  QUARANTINED ON PURPOSE. iPad is not a maintained priority. This view is a dumb
//  layout over `HomePageModel` — it holds zero business logic and reuses only the
//  shared `StationCardView` leaf plus the existing tile models. It deliberately
//  duplicates the small tile styling rather than sharing components with the iPhone
//  layout, so future iPhone changes never have to account for iPad. Design drift is
//  acceptable; this whole file can be deleted without touching the iPhone path. See
//  docs/superpowers/specs/2026-08-06-ipad-home-design.md.
//

import SwiftUI

struct HomePagePadView: View {
  @Bindable var model: HomePageModel

  private let contentMaxWidth: CGFloat = 1100
  private let columns = [
    GridItem(.flexible(), spacing: 24),
    GridItem(.flexible(), spacing: 24),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 32) {
        header
        tilesGrid
        stationsSection
      }
      .frame(maxWidth: contentMaxWidth, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.horizontal, 32)
      .padding(.vertical, 24)
    }
    .scrollIndicators(.hidden)
    .background(Color.black)
  }

  // MARK: - Header (logo + welcome)

  private var header: some View {
    HStack(alignment: .center, spacing: 24) {
      Image("LogoMark")
        .resizable()
        .scaledToFit()
        .frame(width: 96, height: 124)
        .onTapGesture(count: 10, perform: model.playolaIconTapped10Times)

      VStack(alignment: .leading, spacing: 8) {
        Text(model.welcomeMessage)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 40))
          .foregroundColor(.white)

        Text(model.introMessage)
          .font(.custom(FontNames.Inter_400_Regular, size: 18))
          .foregroundColor(.playolaGray)
      }

      Spacer(minLength: 0)
    }
  }

  // MARK: - Feature + Listening tiles

  private var tilesGrid: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
      ForEach(model.visibleFeatureTileModels, id: \.label) { tile in
        HomePadTile(
          label: tile.label,
          value: tile.content,
          buttonText: tile.buttonText ?? "",
          action: { await tile.onButtonTapped() })
      }

      HomePadTile(
        label: model.listeningTimeTileModel.titleText,
        value: model.listeningTimeTileModel.listeningTimeDisplayString,
        buttonText: model.listeningTimeTileModel.buttonText ?? "",
        action: { await model.listeningTimeTileModel.onButtonTapped() }
      )
      .onAppear { model.listeningTimeTileModel.viewAppeared() }
      .onDisappear { model.listeningTimeTileModel.viewDisappeared() }
    }
  }

  // MARK: - Stations grid

  private var stationsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(model.stationListTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 28))
        .foregroundColor(.white)

      LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
        ForEach(model.forYouStations) { station in
          StationCardView(
            station: station,
            liveStatus: model.liveStatusForStation(station.id),
            hasUpcomingGiveaway: model.hasUpcomingGiveawayForStation(station.id),
            onRadioStationSelected: { tapped in
              Task { await model.stationTapped(tapped) }
            }
          )
        }
      }
    }
  }
}

// MARK: - Compact iPad tile (duplicated styling, quarantined)

private struct HomePadTile: View {
  let label: String
  let value: String
  let buttonText: String
  let action: () async -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(label)
          .font(.custom(FontNames.SpaceGrotesk_500_Medium, size: 15))
          .foregroundColor(.playolaGray)

        Text(value)
          .font(.custom(FontNames.Inter_700_Bold, size: 24))
          .foregroundColor(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }

      Spacer(minLength: 12)

      Button {
        Task { await action() }
      } label: {
        Text(buttonText)
          .font(.custom(FontNames.Inter_500_Medium, size: 16))
          .foregroundColor(.white)
          .lineLimit(1)
          .fixedSize()
          .padding(.horizontal, 28)
          .padding(.vertical, 12)
          .background(Color(red: 0.8, green: 0.4, blue: 0.4))
          .cornerRadius(24)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 18)
    .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
    .background(Color(white: 0.15))
    .cornerRadius(12)
  }
}

#Preview(traits: .fixedLayout(width: 1024, height: 768)) {
  NavigationStack {
    HomePagePadView(model: HomePageModel())
  }
  .preferredColorScheme(.dark)
}
