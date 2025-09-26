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
          Text("Radio Stations")
            .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 32))
            .foregroundColor(.white)
          Spacer()
        }
        .padding(.horizontal, 20)
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
                      : Color(white: 0.2)
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
        VStack(alignment: .leading, spacing: 20) {
          ForEach(model.stationListsForDisplay) { list in
            stationSection(list: list)
          }
        }
        .padding(.top, 8)
      }
    }
    .toolbarBackground(.hidden, for: .navigationBar)
    .navigationBarTitleDisplayMode(.inline)
    .background(Color.black)
    .task { await model.viewAppeared() }
    .alert(item: $model.presentedAlert) { $0.alert }
  }

  // MARK: - Helpers
  @ViewBuilder
  private func stationSection(list: StationList) -> some View {
    let includeHiddenItems = model.showSecretStations
    let items = list.stationItems(includeHidden: includeHiddenItems)
    let stationPairs = items.compactMap { item -> (APIStationItem, AnyStation)? in
      guard let station = item.anyStation else { return nil }
      return (item, station)
    }

    if !stationPairs.isEmpty {
      VStack(alignment: .leading, spacing: 1) {
        Text(list.title)
          .font(.custom("Inter-Regular", size: 16))
          .foregroundColor(.white)
          .padding(.horizontal)
          .padding(.bottom, 8)

        VStack(spacing: 1) {
          ForEach(Array(stationPairs.enumerated()), id: \.offset) { _, pair in
            let rowModel = StationListStationRowModel(item: pair.0)
            StationListStationRowView(
              model: rowModel,
              action: {
                Task { await model.stationSelected(pair.1) }
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
