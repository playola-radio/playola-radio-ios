//
//  SeriesDetailsSheetView.swift
//  PlayolaRadio
//

import SwiftUI

struct SeriesDetailsSheetView: View {
  @Bindable var model: SeriesDetailsSheetModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        header

        sectionHeader(model.nameHeader)
          .padding(.top, 36)
        TextField(
          "", text: $model.name,
          prompt: Text(model.namePlaceholder).foregroundColor(.playolaTextTertiary)
        )
        .font(.custom(FontNames.Inter_400_Regular, size: 17))
        .foregroundColor(.playolaTextPrimary)
        .padding(.horizontal, 14)
        .frame(height: 47)
        .background(Color.playolaSurfaceControl)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(model.isSaving)

        ForEach(model.repeatsSections, id: \.self) { _ in
          repeatsSection
        }

        ForEach(model.customScheduleRows, id: \.self) { row in
          customScheduleSection(row)
        }

        ForEach(model.scheduleSections, id: \.self) { _ in
          scheduleSection
        }

        ForEach(model.notes, id: \.self) { note in
          Text(note)
            .font(.custom(FontNames.Inter_400_Regular, size: 13))
            .foregroundColor(.playolaTextTertiary)
            .padding(.top, 20)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 24)
      .padding(.bottom, 24)
    }
    .background(Color.playolaSurfaceTile.ignoresSafeArea())
    .presentationDetents([.large])
    .interactiveDismissDisabled(model.isInteractiveDismissDisabled)
    .playolaAlert($model.presentedAlert)
  }

  private var header: some View {
    ZStack {
      Text(model.navigationTitle)
        .font(.custom(FontNames.Inter_700_Bold, size: 17))
        .foregroundColor(.playolaTextPrimary)
      HStack {
        Button(model.cancelButtonTitle) { model.cancelButtonTapped() }
          .font(.custom(FontNames.Inter_400_Regular, size: 17))
          .foregroundColor(.playolaTextPrimary)
          .disabled(model.isSaving)
        Spacer()
        Button {
          Task { await model.saveButtonTapped() }
        } label: {
          ZStack {
            Text(model.saveButtonTitle)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
              .foregroundColor(model.saveButtonColor)
              .opacity(model.saveTitleOpacity)
            ProgressView()
              .tint(.playolaTextSecondary)
              .opacity(model.savingSpinnerOpacity)
          }
        }
        .disabled(!model.isSaveEnabled)
      }
    }
  }

  private var repeatsSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      sectionHeader(model.repeatsHeader)
        .padding(.top, 24)
      HStack(spacing: 0) {
        ForEach(model.repeatOptions) { option in
          Button {
            model.repeatOptionTapped(option)
          } label: {
            Text(option.title)
              .font(.custom(FontNames.Inter_500_Medium, size: 15))
              .foregroundColor(.playolaTextPrimary)
              .frame(maxWidth: .infinity)
              .frame(height: 34)
              .background(model.repeatOptionFill(option))
              .clipShape(RoundedRectangle(cornerRadius: 8))
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(3)
      .background(Color.playolaSurfaceControl)
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
  }

  private func customScheduleSection(_ text: String) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      sectionHeader(model.scheduleHeader)
        .padding(.top, 24)
      Text(text)
        .font(.custom(FontNames.Inter_400_Regular, size: 17))
        .foregroundColor(.playolaTextSecondary)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 47)
        .background(Color.playolaSurfaceControl)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private var scheduleSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      sectionHeader(model.daysHeader)
        .padding(.top, 24)
      HStack(spacing: 0) {
        ForEach(model.dayOptions) { day in
          Button {
            model.dayTapped(day.id)
          } label: {
            Text(day.letter)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
              .foregroundColor(.playolaTextPrimary)
              .frame(width: 40, height: 40)
              .background(day.fillColor)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(day.accessibilityLabel)
          .accessibilityAddTraits(day.accessibilityTraits)
          .frame(maxWidth: .infinity)
        }
      }

      sectionHeader(model.timeHeader)
        .padding(.top, 24)
      HStack {
        Text(model.startsAtLabel)
          .font(.custom(FontNames.Inter_400_Regular, size: 17))
          .foregroundColor(.playolaTextPrimary)
        Spacer()
        DatePicker("", selection: $model.startTime, displayedComponents: .hourAndMinute)
          .labelsHidden()
          .environment(\.timeZone, model.timeZone)
          .colorScheme(.dark)
          .disabled(model.isSaving)
      }
      .padding(.horizontal, 14)
      .frame(height: 54)
      .background(Color.playolaSurfaceControl)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
      .foregroundColor(.playolaTextSecondary)
      .kerning(0.5)
      .padding(.bottom, 8)
  }
}
