//
//  AddShowToSeriesSheetView.swift
//  PlayolaRadio
//

import SwiftUI

struct AddShowToSeriesSheetView: View {
  @Bindable var model: AddShowToSeriesSheetModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text(model.title)
          .font(.custom(FontNames.Inter_700_Bold, size: 30))
          .foregroundColor(.playolaTextPrimary)
        Text(model.subtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 16))
          .foregroundColor(.playolaTextSecondary)
          .padding(.top, 8)

        recordNewShowButton
          .padding(.top, 24)

        ForEach(model.listHeaders, id: \.self) { header in
          Text(header)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
            .tracking(0.6)
            .foregroundColor(.playolaTextTertiary)
            .padding(.top, 32)
            .padding(.bottom, 4)
        }

        ForEach(model.loadingSpinners, id: \.self) { _ in
          ProgressView()
            .tint(.playolaTextSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }

        ForEach(model.rows) { row in
          showRow(row)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 28)
      .padding(.bottom, 24)
    }
    .background(Color.playolaSurfaceTile.ignoresSafeArea())
    .presentationDetents([.fraction(0.7), .large])
    .presentationDragIndicator(.visible)
    .interactiveDismissDisabled(model.isSwipeDismissDisabled)
    .task { await model.viewAppeared() }
  }

  private var recordNewShowButton: some View {
    Button {
      model.recordNewShowTapped()
    } label: {
      HStack(spacing: 14) {
        Image(systemName: "mic")
          .font(.system(size: 20, weight: .medium))
          .foregroundColor(.white)
          .frame(width: 36, height: 36)
          .background(Color.playolaRed)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        VStack(alignment: .leading, spacing: 2) {
          Text(model.recordNewShowTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.playolaTextPrimary)
          Text(model.recordNewShowSubtitle)
            .font(.custom(FontNames.Inter_400_Regular, size: 13))
            .foregroundColor(.playolaTextSecondary)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.playolaTextTertiary)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 14)
      .background(Color.playolaSurfaceControl)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!model.isRecordNewShowEnabled)
    .opacity(model.recordNewShowOpacity)
  }

  private func showRow(_ row: AddShowToSeriesRow) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        ForEach(row.drafts) { _ in
          DraftDateBadge()
        }
        ForEach(row.scheduled) { scheduled in
          CalendarDateBadge(date: scheduled.tile.date, timeZone: scheduled.tile.timeZone)
        }
        VStack(alignment: .leading, spacing: 4) {
          Text(row.title)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.playolaTextPrimary)
            .lineLimit(1)
          ForEach(row.drafts) { _ in
            subtitle(row.subtitle, color: .playolaWarningAmber)
          }
          ForEach(row.scheduled) { _ in
            subtitle(row.subtitle, color: .playolaTextSecondary)
          }
        }
        Spacer(minLength: 8)
        ForEach(row.addButtonTitles, id: \.self) { title in
          Button {
            Task { await model.addButtonTapped(row.id) }
          } label: {
            Text(title)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
              .foregroundColor(.playolaRed)
              .frame(width: 64, height: 32)
              .overlay(
                RoundedRectangle(cornerRadius: 10).stroke(Color.playolaRed, lineWidth: 1))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(row.addButtonAccessibilityLabel)
          .disabled(!row.isAddEnabled)
          .opacity(row.addButtonOpacity)
        }
        ForEach(row.busySpinners, id: \.self) { _ in
          ProgressView()
            .tint(.playolaRed)
            .frame(width: 64, height: 32)
        }
      }
      .padding(.vertical, 12)
      Rectangle()
        .fill(Color.playolaDividerSubtle)
        .frame(height: 1)
    }
  }

  private func subtitle(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.custom(FontNames.Inter_400_Regular, size: 13))
      .foregroundColor(color)
      .lineLimit(1)
      .minimumScaleFactor(0.85)
  }
}
