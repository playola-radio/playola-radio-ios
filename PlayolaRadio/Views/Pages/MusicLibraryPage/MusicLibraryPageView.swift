//
//  MusicLibraryPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct MusicLibraryPageView: View {
  @Bindable var model: MusicLibraryPageModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        rowList
        emptyState
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
    }
    .background(Color.black)
    .overlay { loadingSpinner }
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await model.viewAppeared()
    }
    .playolaAlert($model.presentedAlert)
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

  private var rowList: some View {
    VStack(spacing: 0) {
      ForEach(model.rows) { row in
        rowView(row)
        Divider()
          .background(Color(hex: "#333333"))
      }
    }
  }

  private func rowView(_ row: MusicLibraryRow) -> some View {
    Button {
      model.rowTapped(row)
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(row.title)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
            .foregroundColor(model.titleColor(for: row))
          Text(model.songCountLabel(for: row))
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(.playolaGray)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 14))
          .foregroundColor(.playolaGray)
      }
      .padding(.vertical, 16)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "music.note")
        .font(.system(size: 32))
        .foregroundColor(.playolaGray)
      Text(model.emptyStateMessage)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaGray)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 60)
    .opacity(model.emptyStateOpacity)
  }
}

#Preview {
  NavigationStack {
    MusicLibraryPageView(model: MusicLibraryPageModel(stationId: "station-preview"))
  }
  .preferredColorScheme(.dark)
}
