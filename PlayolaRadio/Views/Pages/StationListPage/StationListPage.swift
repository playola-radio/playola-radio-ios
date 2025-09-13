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
            stationSection(title: list.title, stations: list.stations)
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
  private func stationSection(title: String, stations: [AnyStation]) -> some View {
    if !stations.isEmpty {
      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.custom("Inter-Regular", size: 16))
          .foregroundColor(.white)
          .padding(.horizontal)
          .padding(.bottom, 8)

        VStack(spacing: 1) {
          ForEach(stations) { station in
            StationRowView(
              station: station,
              action: {
                Task { await model.stationSelected(station) }
              })
          }
        }
      }
    }
  }
}

// ------------------------------------------------------------------
// MARK: - Station Row
// ------------------------------------------------------------------
private struct StationRowView: View {
  let station: AnyStation
  let action: (() -> Void)

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        if let url = station.imageUrl {
          AsyncImage(url: url) { image in
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          } placeholder: {
            Color(white: 0.2)
          }
          .frame(width: 64, height: 64)
          .clipped()
          .cornerRadius(6)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(station.stationName)
            .font(.custom(FontNames.Inter_500_Medium, size: 22))
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)

          Text(station.name)
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)
        }

        Spacer()
      }
      .padding(.horizontal)
      .padding(.vertical, 12)
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
