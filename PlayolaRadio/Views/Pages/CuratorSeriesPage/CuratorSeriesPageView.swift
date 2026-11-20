//
//  CuratorSeriesPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct CuratorSeriesPageView: View {
  @Bindable var model: CuratorSeriesPageModel

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(model.scheduleBadges, id: \.self) { badge in
            ScheduleBadge(text: badge)
              .padding(.bottom, 12)
          }
          ForEach(model.slotsNotes, id: \.self) { note in
            Text(note)
              .font(.custom(FontNames.Inter_400_Regular, size: 14))
              .foregroundColor(.playolaGray)
              .padding(.bottom, 8)
          }

          sectionHeader(model.draftsHeader)
          ForEach(model.draftRows) { row in
            draftRow(row)
          }
          ForEach(model.draftsEmptyMessages, id: \.self) { message in
            emptyMessage(message)
          }

          sectionHeader(model.upcomingHeader)
          ForEach(model.upcomingRows) { row in
            ForEach(row.shows) { show in
              showRow(show)
            }
            ForEach(row.slots) { slot in
              slotRow(slot)
            }
          }
          ForEach(model.upcomingEmptyMessages, id: \.self) { message in
            emptyMessage(message)
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .overlay { loadingSpinner }
      addShowButton
    }
    .background(Color.black)
    .playolaAlert($model.presentedAlert)
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(model.editButtonTitle) { model.editButtonTapped() }
          .font(.custom(FontNames.Inter_400_Regular, size: 17))
          .foregroundColor(.playolaRed)
      }
    }
    .task {
      await model.viewAppeared()
    }
    .task {
      await model.observeRecordedShowsChanges()
    }
  }

  private var addShowButton: some View {
    Button {
      Task { await model.addAShowButtonTapped() }
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "plus")
        Text(model.addShowButtonTitle)
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

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
      .foregroundColor(.playolaGray)
      .kerning(0.5)
      .padding(.top, 24)
      .padding(.bottom, 4)
  }

  private func emptyMessage(_ message: String) -> some View {
    Text(message)
      .font(.custom(FontNames.Inter_400_Regular, size: 16))
      .foregroundColor(.playolaGray)
      .padding(.vertical, 8)
  }

  private func draftRow(_ row: CuratorSeriesDraftRow) -> some View {
    rowContainer {
      Button {
        model.showTapped(row.id)
      } label: {
        HStack(spacing: 16) {
          DraftDateBadge()
          titleAndSubtitle(row.title, row.subtitle, subtitleColor: .playolaWarningAmber)
          Spacer(minLength: 0)
          chevron
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }

  private func showRow(_ show: CuratorSeriesUpcomingRow.ShowContent) -> some View {
    rowContainer {
      Button {
        model.showTapped(show.episodeId)
      } label: {
        HStack(spacing: 16) {
          CalendarDateBadge(date: show.tile.date, timeZone: show.tile.timeZone)
          titleAndSubtitle(show.title, show.subtitle, subtitleColor: .playolaGray)
          Spacer(minLength: 0)
          chevron
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }

  private func slotRow(_ slot: CuratorSeriesUpcomingRow.SlotContent) -> some View {
    rowContainer {
      HStack(spacing: 16) {
        CalendarDateBadge(
          date: slot.tile.date, timeZone: slot.tile.timeZone, headerColor: Color(hex: "#444444"),
          dayColor: .playolaGray)
        VStack(alignment: .leading, spacing: 4) {
          Text(slot.title)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
            .foregroundColor(.playolaGray)
          Text(slot.subtitle)
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(.playolaGray)
        }
        Spacer(minLength: 0)
        Button {
          model.addShowTapped(slot: slot.tile.date)
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "plus")
            Text(slot.addButtonTitle)
          }
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.playolaRed)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.playolaRed, lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func titleAndSubtitle(_ title: String, _ subtitle: String, subtitleColor: Color)
    -> some View
  {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
        .foregroundColor(.white)
        .lineLimit(1)
      Text(subtitle)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(subtitleColor)
    }
  }

  private var chevron: some View {
    Image(systemName: "chevron.right")
      .font(.system(size: 14))
      .foregroundColor(.playolaGray)
  }

  private func rowContainer(@ViewBuilder _ content: () -> some View) -> some View {
    VStack(spacing: 0) {
      content()
        .padding(.vertical, 12)
      Divider()
        .background(Color(hex: "#333333"))
    }
  }
}

#Preview {
  NavigationStack {
    CuratorSeriesPageView(
      model: CuratorSeriesPageModel(
        stationId: "station-preview",
        series: CuratorSeries(
          id: "series-preview", stationId: "station-preview", title: "This One\u{2019}s For You",
          isOneTime: false, rrule: "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0")))
  }
  .preferredColorScheme(.dark)
}
