//
//  BreakersLibraryPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct BreakersLibraryPageView: View {
  @Bindable var model: BreakersLibraryPageModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        categoryList
        emptyState
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
    }
    .background(Color.black)
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await model.viewAppeared()
    }
    .playolaAlert($model.presentedAlert)
  }

  private var categoryList: some View {
    VStack(spacing: 0) {
      ForEach(model.categories) { category in
        categoryRow(category)
        Divider()
          .background(Color(hex: "#333333"))
      }
    }
  }

  private func categoryRow(_ category: StationCategory) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(category.name)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
          .foregroundColor(.white)
        Text(model.blockCountLabel(for: category))
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.playolaGray)
      }
      Spacer()
    }
    .padding(.vertical, 16)
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "square.stack")
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
    BreakersLibraryPageView(model: BreakersLibraryPageModel(stationId: "station-preview"))
  }
  .preferredColorScheme(.dark)
}
