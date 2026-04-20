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

  // MARK: - View
  var body: some View {
    VStack(spacing: 0) {
      // ---------------------------------------------------------
      // Sticky Header
      // ---------------------------------------------------------
      VStack(spacing: 0) {
        // Page Title
        HStack {
          Text(model.navigationTitle)
            .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 32))
            .foregroundColor(.white)
          Spacer()
          Button {
            model.suggestArtistTapped()
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
              Text(model.suggestArtistButtonText)
                .font(.custom(FontNames.Inter_500_Medium, size: 12))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.playolaRed)
            .cornerRadius(16)
          }
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
      }
      .background(Color.black)

      // ---------------------------------------------------------
      // Station Lists
      // ---------------------------------------------------------
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
          }
          .frame(maxWidth: .infinity)
          .padding(.top, 64)
        } else {
          VStack(alignment: .leading, spacing: 20) {
            ForEach(model.stationListsForDisplay) { list in
              stationSection(list: list)
            }
          }
          .padding(.top, 8)
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      searchBar
    }
    .toolbarBackground(.hidden, for: .navigationBar)
    .navigationBarTitleDisplayMode(.inline)
    .background(Color.black)
    .onAppear { Task { await model.viewAppeared() } }
    .playolaAlert($model.presentedAlert)
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
  private func stationSection(list: StationList) -> some View {
    let items = model.sortedStationItems(for: list)
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: 1) {
        Text(list.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)
          .padding(.horizontal)
          .padding(.bottom, 8)

        VStack(spacing: 1) {
          ForEach(items, id: \.anyStation.id) { item in
            let liveStatus = model.liveStatusForStation(item.anyStation.id)
            let rowModel = StationListStationRowModel(item: item, liveStatus: liveStatus)
            StationListStationRowView(
              model: rowModel,
              action: {
                Task { await model.stationSelected(item) }
              })
          }
        }
      }
    }
  }
}
// ------------------------------------------------------------------
// MARK: - Preview
// ------------------------------------------------------------------
#Preview {
  NavigationStack {
    StationListPage(model: StationListModel())
  }
  .preferredColorScheme(.dark)
}
