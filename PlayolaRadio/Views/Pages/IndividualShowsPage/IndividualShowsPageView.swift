//
//  IndividualShowsPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct IndividualShowsPageView: View {
  @Bindable var model: IndividualShowsPageModel

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(model.rows) { row in
            rowView(row)
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
      }
      .overlay { emptyState }
      .overlay { loadingSpinner }
      recordNewShowButton
    }
    .background(Color.black)
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await model.viewAppeared()
    }
    .task {
      await model.observeRecordedShowsChanges()
    }
  }

  private var recordNewShowButton: some View {
    Button {
      model.recordNewShowButtonTapped()
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "plus")
        Text(model.recordNewShowButtonTitle)
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

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "calendar.badge.clock")
        .font(.system(size: 36))
        .foregroundColor(.playolaGray)
      Text(model.emptyStateTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 19))
        .foregroundColor(.white)
      Text(model.emptyStateMessage)
        .font(.custom(FontNames.Inter_400_Regular, size: 15))
        .foregroundColor(.playolaGray)
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .opacity(model.emptyStateOpacity)
    .accessibilityHidden(!model.isEmptyStateVisible)
  }

  private var loadingSpinner: some View {
    ProgressView()
      .progressViewStyle(.circular)
      .tint(.white)
      .scaleEffect(1.5)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black)
      .opacity(model.loadingOpacity)
      .allowsHitTesting(model.isLoading)
      .accessibilityHidden(!model.isLoading)
  }

  private func subtitleText(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.custom(FontNames.Inter_400_Regular, size: 14))
      .foregroundColor(color)
  }

  private func rowView(_ row: IndividualShowRow) -> some View {
    VStack(spacing: 0) {
      Button {
        model.showRowTapped(row)
      } label: {
        HStack(spacing: 16) {
          ForEach(row.draftTileIDs, id: \.self) { _ in
            DraftDateBadge()
          }
          ForEach(row.scheduledTiles) { tile in
            CalendarDateBadge(date: tile.airtime, timeZone: tile.timeZone)
          }
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text(row.title)
                .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
                .foregroundColor(.white)
                .lineLimit(1)
              ForEach(row.seriesBadges, id: \.self) { badge in
                Text(badge)
                  .font(.custom(FontNames.Inter_500_Medium, size: 12))
                  .foregroundColor(Color(hex: "#c7c7c7"))
                  .lineLimit(1)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 3)
                  .background(Color(hex: "#444444"))
                  .cornerRadius(4)
              }
            }
            ForEach(row.draftSubtitles, id: \.self) { subtitle in
              subtitleText(subtitle, color: .playolaWarningAmber)
            }
            ForEach(row.scheduledSubtitles, id: \.self) { subtitle in
              subtitleText(subtitle, color: .playolaGray)
            }
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.system(size: 14))
            .foregroundColor(.playolaGray)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      Divider()
        .background(Color(hex: "#333333"))
    }
  }
}

#Preview {
  NavigationStack {
    IndividualShowsPageView(model: IndividualShowsPageModel(stationId: "station-preview"))
  }
  .preferredColorScheme(.dark)
}
