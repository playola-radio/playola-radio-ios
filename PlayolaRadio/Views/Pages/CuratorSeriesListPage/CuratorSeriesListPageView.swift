//
//  CuratorSeriesListPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct CuratorSeriesListPageView: View {
  @Bindable var model: CuratorSeriesListPageModel

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        LazyVStack(spacing: 16) {
          ForEach(model.cards) { card in
            cardView(card)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      }
      .overlay { loadingSpinner }
      createButton
    }
    .background(Color.black)
    .playolaAlert($model.presentedAlert)
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await model.viewAppeared()
    }
    .task {
      await model.observeRecordedShowsChanges()
    }
  }

  private var createButton: some View {
    Button {
      model.createSeriesButtonTapped()
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "plus")
        Text(model.createButtonTitle)
      }
      .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 18)
      .background(Color.playolaRed)
      .cornerRadius(16)
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private var loadingSpinner: some View {
    ProgressView()
      .progressViewStyle(.circular)
      .tint(.white)
      .scaleEffect(1.5)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black)
      .opacity(model.loadingOpacity)
      .allowsHitTesting(model.isProgressVisible)
      .accessibilityHidden(!model.isProgressVisible)
  }

  private func cardView(_ card: CuratorSeriesCard) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        model.seriesNameTapped(card)
      } label: {
        HStack {
          Text(card.title)
            .font(.custom(FontNames.Inter_700_Bold, size: 21))
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 14))
            .foregroundColor(.playolaGray)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .padding(.bottom, 12)

      ForEach(card.badges, id: \.self) { badge in
        ScheduleBadge(text: badge)
          .padding(.bottom, 8)
      }

      upcomingSection(card)
    }
    .padding(20)
    .background(
      LinearGradient(
        colors: [Color(hex: "#1c1a19"), Color(hex: "#2e2a28")],
        startPoint: UnitPoint(x: 0.87, y: 0.02),
        endPoint: UnitPoint(x: 0.13, y: 0.98)
      )
    )
    .cornerRadius(8)
  }

  private func upcomingSection(_ card: CuratorSeriesCard) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(card.upcomingHeader)
          .font(.custom(FontNames.Inter_500_Medium, size: 12))
          .tracking(0.06)
          .foregroundColor(Color(hex: "#c7c7c7"))
        Spacer()
        ForEach(card.countLabels, id: \.self) { count in
          Text(count)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(Color(hex: "#c7c7c7"))
        }
      }
      .padding(.top, 12)
      .padding(.bottom, 8)

      VStack(spacing: 8) {
        ForEach(card.items) { item in
          ForEach(item.shows) { show in
            showRow(show)
          }
          ForEach(item.slots) { slot in
            slotRow(slot, in: card)
          }
        }
      }

      ForEach(card.emptyMessages, id: \.self) { message in
        Text(message)
          .font(.custom(FontNames.Inter_400_Regular, size: 15))
          .foregroundColor(.playolaGray)
          .padding(.top, 4)
      }
    }
  }

  private func showRow(_ show: CuratorSeriesCardItem.ShowContent) -> some View {
    Button {
      model.showTapped(show.episodeId)
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        Text(show.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity, alignment: .leading)
        HStack(spacing: 12) {
          CalendarDateBadge(date: show.tile.date, timeZone: show.tile.timeZone)
          Text(show.subtitle)
            .font(.custom(FontNames.Inter_400_Regular, size: 13))
            .foregroundColor(Color(hex: "#c7c7c7"))
          Spacer()
        }
      }
      .padding(12)
      .background(Color(hex: "#130000").opacity(0.4))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(hex: "#333333"), lineWidth: 1)
      )
      .cornerRadius(8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func slotRow(_ slot: CuratorSeriesCardItem.SlotContent, in card: CuratorSeriesCard)
    -> some View
  {
    HStack(spacing: 12) {
      CalendarDateBadge(
        date: slot.tile.date, timeZone: slot.tile.timeZone, headerColor: Color(hex: "#444444"),
        dayColor: .playolaGray)
      Text(slot.subtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundColor(.playolaGray)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      Spacer(minLength: 8)
      Button {
        model.addShowTapped(card, slot: slot.tile.date)
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "plus")
          Text(slot.addButtonTitle)
        }
        .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
        .foregroundColor(.playolaRed)
        .fixedSize()
      }
      .buttonStyle(.plain)
    }
    .padding(12)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(hex: "#444444"), lineWidth: 1)
    )
  }
}

#Preview {
  NavigationStack {
    CuratorSeriesListPageView(model: CuratorSeriesListPageModel(stationId: "station-preview"))
  }
  .preferredColorScheme(.dark)
}
