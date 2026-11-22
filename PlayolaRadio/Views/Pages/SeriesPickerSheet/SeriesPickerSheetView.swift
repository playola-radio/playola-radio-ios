//
//  SeriesPickerSheetView.swift
//  PlayolaRadio
//

import SwiftUI

struct SeriesPickerSheetView: View {
  @Bindable var model: SeriesPickerSheetModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text(model.title)
          .font(.custom(FontNames.Inter_700_Bold, size: 30))
          .foregroundColor(.playolaTextPrimary)
        Text(model.subtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 16))
          .foregroundColor(.playolaTextSecondary)
          .padding(.top, 10)

        VStack(spacing: 12) {
          ForEach(model.loadingSpinners, id: \.self) { _ in
            ProgressView()
              .tint(.playolaTextSecondary)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 24)
          }
          ForEach(model.rows) { row in
            Button {
              Task { await model.seriesRowTapped(row.id) }
            } label: {
              rowContent(
                tile: Color.playolaSurfaceRow, icon: Image("RecordedShows-layers"),
                title: row.title, subtitle: row.subtitle,
                accessory: Image(systemName: row.accessoryIcon).foregroundColor(row.accessoryColor))
            }
            .buttonStyle(.plain)
          }
          ForEach(model.newSeriesRows) { row in
            Button {
              model.newSeriesRowTapped()
            } label: {
              rowContent(
                tile: Color.playolaRed, icon: Image("AMA-plus"), title: row.title,
                subtitle: row.subtitle,
                accessory: Image(systemName: "chevron.right").foregroundColor(.playolaTextTertiary))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.top, 20)

        ForEach(model.removeButtons, id: \.self) { title in
          Button {
            Task { await model.removeButtonTapped() }
          } label: {
            Text(title)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
              .foregroundColor(.playolaRed)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
          }
          .buttonStyle(.plain)
          .padding(.top, 16)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 28)
      .padding(.bottom, 24)
    }
    .background(Color.playolaSurfaceTile.ignoresSafeArea())
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .task { await model.viewAppeared() }
  }

  private func rowContent(
    tile: Color, icon: Image, title: String, subtitle: String, accessory: some View
  ) -> some View {
    HStack(spacing: 12) {
      icon
        .resizable()
        .renderingMode(.template)
        .scaledToFit()
        .frame(width: 18, height: 18)
        .foregroundColor(.playolaTextPrimary)
        .frame(width: 36, height: 36)
        .background(tile)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundColor(.playolaTextPrimary)
        Text(subtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(.playolaTextSecondary)
      }
      Spacer()
      accessory
        .font(.system(size: 14, weight: .semibold))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .background(Color.playolaSurfaceControl)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .contentShape(Rectangle())
  }
}
