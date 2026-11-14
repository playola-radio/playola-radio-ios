//
//  UpcomingShowsPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct UpcomingShowsPageView: View {
  @Bindable var model: UpcomingShowsPageModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        row(title: model.seriesRowTitle, countLabel: model.seriesCountLabel) {
          model.seriesRowTapped()
        }
        row(title: model.individualShowsRowTitle, countLabel: model.individualShowsCountLabel) {
          model.individualShowsRowTapped()
        }
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
    .task {
      await model.observeRecordedShowsChanges()
    }
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

  private func row(title: String, countLabel: String, action: @escaping () -> Void)
    -> some View
  {
    VStack(spacing: 0) {
      Button(action: action) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(title)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
              .foregroundColor(.white)
            Text(countLabel)
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
      Divider()
        .background(Color(hex: "#333333"))
    }
  }
}

#Preview {
  NavigationStack {
    UpcomingShowsPageView(model: UpcomingShowsPageModel(stationId: "station-preview"))
  }
  .preferredColorScheme(.dark)
}
