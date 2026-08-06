//
//  StationListPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import IdentifiedCollections
import SwiftUI

struct StationListPage: View {
  // MARK: - Model
  @Bindable var model: StationListModel

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  // MARK: - View
  var body: some View {
    Group {
      if horizontalSizeClass == .regular {
        StationListPadView(model: model)
      } else {
        compactBody
      }
    }
    .toolbarBackground(.hidden, for: .navigationBar)
    .navigationBarTitleDisplayMode(.inline)
    .background(Color.black)
    .onAppear { Task { await model.viewAppeared() } }
    .playolaAlert($model.presentedAlert)
    .playolaAlert(Bindable(model.presetsModel).presentedAlert)
  }

  // MARK: - Compact (iPhone) layout — unchanged
  private var compactBody: some View {
    VStack(spacing: 0) {
      // Header
      VStack(spacing: 0) {
        // Page Title
        HStack {
          Text(model.navigationTitle)
            .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 32))
            .foregroundColor(.white)
          Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)

        // Segment Control
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
          .padding(.horizontal)
          .padding(.top, 24)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .trailing) {
          LinearGradient(
            colors: [Color.black.opacity(0), Color.black],
            startPoint: .leading,
            endPoint: .trailing
          )
          .frame(width: 24)
          .allowsHitTesting(false)
        }
      }
      .background(Color.black)

      // Station Lists
      ScrollView {
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
              .padding(.horizontal, 32)

            SuggestStationRow(
              isVisible: true,
              text: model.suggestArtistButtonText,
              action: { model.suggestArtistTapped() }
            )
            .padding(.top, 4)
          }
          .frame(maxWidth: .infinity)
          .padding(.top, 64)
        } else {
          VStack(alignment: .leading, spacing: 20) {
            ForEach(model.displayedSections) { section in
              stationSection(section: section)
            }
          }
          .padding(.top, 8)
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      searchBar
    }
  }

  private var searchBar: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 16))
        .foregroundColor(.playolaGray)

      TextField(model.searchBarPlaceholder, text: $model.searchText)
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.white)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)

      if !model.searchText.isEmpty {
        Button {
          model.searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 16))
            .foregroundColor(.playolaGray)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color(hex: "#333333"))
    .clipShape(.rect(cornerRadius: 8))
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.black)
  }

  // MARK: - Helpers
  @ViewBuilder
  private func stationSection(section: DisplayedStationSection) -> some View {
    let rows = model.displayedRows(for: section)
    if !rows.isEmpty {
      VStack(alignment: .leading, spacing: 1) {
        Text(section.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)
          .padding(.horizontal)
          .padding(.bottom, 8)

        SuggestStationRow(
          isVisible: section.isArtistList,
          text: model.suggestArtistButtonText,
          action: { model.suggestArtistTapped() }
        )

        VStack(spacing: 1) {
          ForEach(rows) { row in
            let item = row.item
            let rowModel = StationListStationRowModel(
              item: item, liveStatus: row.liveStatus,
              hasUpcomingGiveaway: row.hasUpcomingGiveaway)
            let isPreset = model.presetsModel.isPreset(stationId: item.anyStation.id)
            StationListStationRowView(
              model: rowModel,
              action: {
                Task { await model.stationSelected(item) }
              },
              isPreset: isPreset,
              presetAccessibilityLabel: model.presetsModel.presetStarAccessibilityLabel(
                isPreset: isPreset, stationName: rowModel.titleText),
              onTogglePreset: { await model.presetsModel.starTapped(for: item) }
            )
          }
        }
      }
    }
  }
}

// MARK: - Suggest Station Row

private struct SuggestStationRow: View {
  let isVisible: Bool
  let text: String
  let action: () -> Void

  var body: some View {
    if isVisible {
      Button(action: action) {
        HStack(spacing: 12) {
          Image(systemName: "plus")
            .font(.system(size: 15, weight: .bold))
          Text(text)
            .font(.custom(FontNames.Inter_700_Bold, size: 15))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
          Spacer(minLength: 0)
        }
        .foregroundColor(.playolaRed)
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
              Color(hex: "#4D4D4D"),
              style: StrokeStyle(lineWidth: 1, dash: [4])
            )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
      }
    }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    StationListPage(model: StationListModel())
  }
  .preferredColorScheme(.dark)
}
