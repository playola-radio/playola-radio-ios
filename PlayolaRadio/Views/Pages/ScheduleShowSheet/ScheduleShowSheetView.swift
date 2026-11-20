//
//  ScheduleShowSheetView.swift
//  PlayolaRadio
//

import SwiftUI

struct ScheduleShowSheetView: View {
  @Bindable var model: ScheduleShowSheetModel

  var body: some View {
    FittedSheet {
      VStack(alignment: .leading, spacing: 0) {
        sheetBar
        ForEach(model.slotsSubtitleLines, id: \.self) { line in
          Text(line)
            .font(.custom(FontNames.Inter_400_Regular, size: 13))
            .foregroundColor(.playolaTextSecondary)
            .padding(.top, 4)
            .padding(.bottom, 18)
        }
        ScrollView {
          VStack(spacing: 0) {
            ForEach(model.slotRows) { row in
              slotRow(row)
            }
          }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: model.slotListHeight)
        Text(model.whenLabel)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
          .tracking(0.6)
          .foregroundColor(.playolaTextTertiary)
          .padding(.top, 20)
          .padding(.bottom, 8)
        pickerRow(
          label: model.dayRowLabel, pillText: model.dayPillLabel, components: .date)
        Spacer().frame(height: 8)
        pickerRow(
          label: model.timeRowLabel, pillText: model.timePillLabel, components: .hourAndMinute)
        ForEach(model.airsAtLines, id: \.self) { line in
          infoLine(icon: "RecordedShows-radio", text: line, color: .playolaTextSecondary)
        }
        ForEach(model.errorLines, id: \.self) { line in
          infoLine(icon: "RecordedShows-circle-alert", text: line, color: .playolaRed)
        }
        ForEach(model.lockNotes) { note in
          lockNote(note)
        }
      }
      .padding(.horizontal, 20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .interactiveDismissDisabled(model.isSwipeDismissDisabled)
  }

  private var sheetBar: some View {
    ZStack {
      Text(model.navigationTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
        .foregroundColor(.playolaTextPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 76)
      HStack {
        Button(model.cancelButtonTitle) { model.cancelButtonTapped() }
          .font(.custom(FontNames.Inter_400_Regular, size: 16))
          .foregroundColor(.playolaTextSecondary)
          .disabled(!model.isCancelEnabled)
        Spacer()
        Button(model.saveButtonTitle) { Task { await model.scheduleButtonTapped() } }
          .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
          .foregroundColor(model.saveButtonColor)
          .disabled(!model.isScheduleEnabled)
      }
    }
    .frame(height: 56)
  }

  private func slotRow(_ row: ScheduleSlotRow) -> some View {
    Button {
      model.slotTapped(row)
    } label: {
      HStack(spacing: 12) {
        SlotTile(monthText: row.monthText, dayText: row.dayText)
        VStack(alignment: .leading, spacing: 3) {
          Text(row.title)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
            .foregroundColor(.playolaTextTertiary)
          Text(row.subtitle)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(.playolaTextSecondary)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.playolaTextFaint)
      }
      .frame(height: model.slotRowHeight)
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
      .overlay(alignment: .bottom) {
        Rectangle().fill(Color.playolaDividerSubtle).frame(height: 1)
      }
    }
    .buttonStyle(.plain)
  }

  private func pickerRow(label: String, pillText: String, components: DatePickerComponents)
    -> some View
  {
    HStack {
      Text(label)
        .font(.custom(FontNames.Inter_400_Regular, size: 15))
        .foregroundColor(.playolaTextPrimary)
      Spacer()
      Text(pillText)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        .foregroundColor(.playolaTextPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.playolaSurfacePill)
        .cornerRadius(8)
        .overlay {
          DatePicker("", selection: $model.pickedTime, displayedComponents: components)
            .labelsHidden()
            .datePickerStyle(.compact)
            .environment(\.timeZone, model.stationTimeZone)
            .environment(\.calendar, model.stationCalendar)
            .colorScheme(.dark)
            .scaleEffect(x: 1.5, y: 1.5)
            .opacity(0.011)
            .blendMode(.destinationOver)
        }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity)
    .background(Color.playolaSurfaceControl)
    .cornerRadius(10)
  }

  private func infoLine(icon: String, text: String, color: Color) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(icon)
        .resizable()
        .scaledToFit()
        .frame(width: 15, height: 15)
        .padding(.top, 2)
      Text(text)
        .font(.custom(FontNames.Inter_500_Medium, size: 14))
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .foregroundColor(color)
    .padding(.top, 16)
  }

  private func lockNote(_ note: ScheduleLockNote) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image("RecordedShows-lock")
        .resizable()
        .scaledToFit()
        .frame(width: 16, height: 16)
        .foregroundColor(.playolaWarningAmber)
      VStack(alignment: .leading, spacing: 3) {
        Text(note.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.playolaWarningAmber)
        Text(note.body)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaTextSecondary)
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(12)
    .background(Color.playolaWarningAmber.opacity(0.1))
    .cornerRadius(10)
    .padding(.top, 14)
  }
}

private struct SlotTile: View {
  let monthText: String
  let dayText: String

  var body: some View {
    VStack(spacing: 0) {
      Text(monthText)
        .font(.custom(FontNames.Inter_700_Bold, size: 8))
        .tracking(1.2)
        .foregroundColor(.playolaTextPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .background(Color.playolaSurfaceControl)
      Text(dayText)
        .font(.custom(FontNames.Inter_700_Bold, size: 13))
        .foregroundColor(.playolaTextTertiary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
          LinearGradient(
            colors: [.playolaSurfaceRaised, .playolaSurfaceSection], startPoint: .top,
            endPoint: .bottom))
    }
    .frame(width: 36, height: 44)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay(
      RoundedRectangle(cornerRadius: 6).stroke(Color.playolaSurfaceArtPlaceholder, lineWidth: 1))
  }
}
