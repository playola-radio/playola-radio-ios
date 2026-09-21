//
//  ShowsPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct ShowsPageView: View {
  @Bindable var model: ShowsPageModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        intro
        Text(model.sectionLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 11))
          .tracking(1.2)
          .foregroundColor(.playolaGray)
          .padding(.top, 28)
        showTypeList
          .padding(.top, 16)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.top, 20)
    }
    .opacity(model.chooserOpacity)
    .allowsHitTesting(model.canChooseShow)
    .accessibilityHidden(model.isStatusVisible)
    .overlay { checkStatus }
    .background(Color.playolaSurfaceBase)
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .task(id: model.isCurrentPage) { await model.viewAppeared() }
    .onDisappear { model.viewDisappeared() }
  }

  private var checkStatus: some View {
    VStack(spacing: 16) {
      ProgressView()
        .tint(.white)
        .opacity(model.loadingOpacity)
      Text(model.checkStatusMessage)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaTextSecondary)
        .multilineTextAlignment(.center)
      ForEach(model.retryTitles, id: \.self) { title in
        Button(title) { Task { await model.viewAppeared() } }
          .buttonStyle(.borderedProminent)
          .tint(.playolaRed)
      }
    }
    .padding(24)
    .opacity(model.statusOpacity)
    .allowsHitTesting(model.isStatusVisible)
    .accessibilityHidden(model.canChooseShow)
  }

  private var intro: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(model.introTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 26))
        .foregroundColor(.playolaTextPrimary)
      Text(model.introBody)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaTextSecondary)
    }
  }

  private var showTypeList: some View {
    VStack(spacing: 0) {
      ForEach(model.showTypes) { row in
        rowView(row)
        Rectangle()
          .fill(Color.playolaDividerSubtle)
          .frame(height: 1)
      }
    }
  }

  private func rowView(_ row: ShowTypeRow) -> some View {
    Button {
      model.showTypeRowTapped(row)
    } label: {
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(Color.playolaAMASoft)
            .frame(width: 42, height: 42)
          Image(systemName: row.iconSystemName)
            .font(.system(size: 20))
            .foregroundColor(.playolaRed)
        }
        VStack(alignment: .leading, spacing: 4) {
          Text(row.title)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.playolaTextPrimary)
          Text(row.description)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(.playolaTextTertiary)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 15))
          .foregroundColor(.playolaGray)
      }
      .frame(height: 78)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  NavigationStack {
    ShowsPageView(model: ShowsPageModel(stationId: "station-preview"))
  }
  .preferredColorScheme(.dark)
}
