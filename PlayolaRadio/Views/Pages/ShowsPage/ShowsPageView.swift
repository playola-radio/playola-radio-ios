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
    .background(Color.black)
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var intro: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(model.introTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 28))
        .foregroundColor(.white)
      Text(model.introBody)
        .font(.custom(FontNames.Inter_400_Regular, size: 15))
        .foregroundColor(.playolaGray)
    }
  }

  private var showTypeList: some View {
    VStack(spacing: 0) {
      ForEach(model.showTypes) { row in
        rowView(row)
        Divider()
          .background(Color(hex: "#333333"))
      }
    }
  }

  private func rowView(_ row: ShowTypeRow) -> some View {
    Button {
      model.showTypeRowTapped(row)
    } label: {
      HStack(spacing: 14) {
        ZStack {
          Circle()
            .fill(Color.playolaRed.opacity(0.15))
            .frame(width: 52, height: 52)
          Image(systemName: row.iconSystemName)
            .font(.system(size: 20))
            .foregroundColor(.playolaRed)
        }
        VStack(alignment: .leading, spacing: 4) {
          Text(row.title)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
            .foregroundColor(.white)
          Text(row.description)
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(.playolaGray)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 14))
          .foregroundColor(.playolaGray)
      }
      .padding(.vertical, 16)
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
