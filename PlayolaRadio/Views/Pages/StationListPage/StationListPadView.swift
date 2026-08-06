//
//  StationListPadView.swift
//  PlayolaRadio
//
//  iPad-only (regular horizontal size class) layout for the Radio Stations screen.
//
//  QUARANTINED ON PURPOSE. iPad is not a maintained priority. This view is a dumb
//  layout over `StationListModel` — it holds zero business logic and reuses only the
//  shared `StationListStationRowView`. It deliberately duplicates the small chip / search
//  styling rather than sharing components with the iPhone layout, so that future iPhone
//  changes never have to account for iPad. Design drift is acceptable; this whole file can
//  be deleted without touching the iPhone path. See
//  docs/superpowers/specs/2026-08-05-ipad-radio-stations-design.md.
//

import SwiftUI

struct StationListPadView: View {
  @Bindable var model: StationListModel

  private let contentMaxWidth: CGFloat = 1100
  private let columns = [
    GridItem(.flexible(), spacing: 24),
    GridItem(.flexible(), spacing: 24),
  ]

  var body: some View {
    VStack(spacing: 0) {
      header
      stationsScroll
    }
    .background(Color.black)
  }

  // MARK: - Header (title + search, then filter row)

  private var header: some View {
    VStack(spacing: 20) {
      HStack(alignment: .center) {
        Text(model.navigationTitle)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 32))
          .foregroundColor(.white)
        Spacer(minLength: 24)
        searchField
          .frame(width: 320)
      }

      HStack(spacing: 12) {
        segmentControl
        Spacer(minLength: 16)
        suggestButton
      }
    }
    .frame(maxWidth: contentMaxWidth)
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.horizontal, 32)
    .padding(.top, 20)
    .padding(.bottom, 16)
  }

  private var searchField: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 16))
        .foregroundColor(.playolaGray)

      TextField(model.searchBarPlaceholder, text: $model.searchText)
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.white)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)

      Button {
        model.searchText = ""
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 16))
          .foregroundColor(.playolaGray)
      }
      .opacity(model.searchText.isEmpty ? 0 : 1)
      .disabled(model.searchText.isEmpty)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color(hex: "#333333"))
    .clipShape(.rect(cornerRadius: 8))
  }

  private var segmentControl: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(model.segmentTitles, id: \.self) { segment in
          Button {
            Task { await model.segmentSelected(segment) }
          } label: {
            Text(segment)
              .font(.custom(FontNames.Inter_500_Medium, size: 16))
              .foregroundColor(.white)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(
                model.selectedSegment == segment
                  ? Color.playolaRed
                  : Color(hex: "#333333")
              )
              .cornerRadius(20)
          }
        }
      }
    }
  }

  private var suggestButton: some View {
    Button {
      model.suggestArtistTapped()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "plus")
          .font(.system(size: 14, weight: .bold))
        Text(model.suggestStationShortText)
          .font(.custom(FontNames.Inter_700_Bold, size: 15))
          .lineLimit(1)
          .fixedSize()
      }
      .foregroundColor(.playolaRed)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .strokeBorder(Color.playolaRed.opacity(0.6), lineWidth: 1)
      )
    }
  }

  // MARK: - Stations

  private var stationsScroll: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        noResults
        ForEach(model.displayedSections) { section in
          gridSection(section)
        }
      }
      .frame(maxWidth: contentMaxWidth, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.horizontal, 32)
      .padding(.top, 8)
      .padding(.bottom, 24)
    }
  }

  @ViewBuilder
  private func gridSection(_ section: DisplayedStationSection) -> some View {
    let rows = model.displayedRows(for: section)
    if !rows.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        Text(section.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)

        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
          ForEach(rows) { row in
            stationRow(row)
          }
        }
      }
    }
  }

  private func stationRow(_ row: DisplayedStationSection.Row) -> some View {
    let item = row.item
    let rowModel = StationListStationRowModel(
      item: item,
      liveStatus: row.liveStatus,
      hasUpcomingGiveaway: row.hasUpcomingGiveaway)
    let isPreset = model.presetsModel.isPreset(stationId: item.anyStation.id)
    return StationListStationRowView(
      model: rowModel,
      action: { Task { await model.stationSelected(item) } },
      isPreset: isPreset,
      presetAccessibilityLabel: model.presetsModel.presetStarAccessibilityLabel(
        isPreset: isPreset, stationName: rowModel.titleText),
      onTogglePreset: { await model.presetsModel.starTapped(for: item) }
    )
  }

  @ViewBuilder
  private var noResults: some View {
    if model.isShowingNoResults {
      VStack(spacing: 12) {
        Image(systemName: model.noResultsIconName)
          .font(.system(size: 40, weight: .light))
          .foregroundColor(.playolaGray)
        Text(model.noResultsMessage)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 18))
          .foregroundColor(.white)
        Text(model.noResultsHint)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.playolaGray)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 64)
    }
  }
}

#Preview {
  NavigationStack {
    StationListPadView(model: StationListModel())
  }
  .preferredColorScheme(.dark)
}
