//
//  UnscheduleShowSheetView.swift
//  PlayolaRadio
//

import SwiftUI

struct UnscheduleShowSheetView: View {
  @Bindable var model: UnscheduleShowSheetModel

  var body: some View {
    FittedSheet {
      VStack(alignment: .leading, spacing: 0) {
        RoundedRectangle(cornerRadius: 3)
          .fill(Color.white.opacity(0.2))
          .frame(width: 36, height: 5)
          .frame(maxWidth: .infinity)
          .padding(.bottom, 14)
        Text(model.title)
          .font(.custom(FontNames.Inter_700_Bold, size: 20))
          .foregroundColor(.playolaTextPrimary)
        Text(model.subtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .lineSpacing(3)
          .foregroundColor(.playolaTextSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 6)
          .padding(.bottom, 20)
        ForEach(model.errorLines, id: \.self) { line in
          errorLine(line)
        }
        Button {
          Task { await model.unscheduleConfirmed() }
        } label: {
          Text(model.unscheduleButtonTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.playolaRed)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(model.isSaving)
        Button {
          model.keepScheduledTapped()
        } label: {
          Text(model.keepScheduledButtonTitle)
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .foregroundColor(.playolaTextSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func errorLine(_ line: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image("RecordedShows-circle-alert")
        .resizable()
        .scaledToFit()
        .frame(width: 15, height: 15)
        .padding(.top, 2)
      Text(line)
        .font(.custom(FontNames.Inter_500_Medium, size: 14))
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .foregroundColor(.playolaRed)
    .padding(.bottom, 14)
  }
}
