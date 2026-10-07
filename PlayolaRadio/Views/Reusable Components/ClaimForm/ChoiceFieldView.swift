//
//  ChoiceFieldView.swift
//  PlayolaRadio
//

import SwiftUI

struct ChoiceFieldView: View {
  @Bindable var field: ClaimFieldModel
  let presentation: ChoicePresentation

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ClaimFieldLabel(text: field.label)
      switch presentation {
      case .chips:
        HStack(spacing: 8) {
          ForEach(field.field.options, id: \.self) { option in
            chip(option)
          }
        }
      case .inlineList:
        VStack(spacing: 8) {
          ForEach(field.field.options, id: \.self) { option in
            listRow(option)
          }
        }
      case .picker:
        pickerRow
      }
    }
  }

  private func chip(_ option: String) -> some View {
    let isSelected = field.isOptionSelected(option)
    return Button {
      field.optionTapped(option)
    } label: {
      Text(option)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
        .foregroundColor(isSelected ? .black : .playolaTextPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.playolaRed : Color.playolaSurfaceSection)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.playolaGlassHairline, lineWidth: isSelected ? 0 : 1)
        )
    }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func listRow(_ option: String) -> some View {
    let isSelected = field.isOptionSelected(option)
    return Button {
      field.optionTapped(option)
    } label: {
      HStack(spacing: 12) {
        Text(option)
          .font(
            .custom(
              isSelected ? FontNames.Inter_600_SemiBold : FontNames.Inter_400_Regular, size: 16)
          )
          .foregroundColor(.playolaTextPrimary)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: isSelected ? "checkmark.circle" : "circle")
          .font(.system(size: 22, weight: .regular))
          .foregroundColor(isSelected ? .playolaRed : .playolaTextTertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(isSelected ? Color.playolaRed.opacity(0.13) : Color.playolaSurfaceSection)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(isSelected ? Color.playolaRed : Color.playolaGlassHairline, lineWidth: 1)
      )
    }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var pickerRow: some View {
    Button {
      field.pickerRowTapped()
    } label: {
      HStack(spacing: 8) {
        Text(field.pickerValueText)
          .font(.custom(FontNames.Inter_400_Regular, size: 16))
          .foregroundColor(
            field.isPickerValuePlaceholder ? .playolaTextTertiary : .playolaTextPrimary
          )
          .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.playolaTextTertiary)
      }
      .padding(.leading, 16)
      .padding(.trailing, 12)
      .frame(height: 48)
      .background(RoundedRectangle(cornerRadius: 8).fill(Color.playolaSurfaceSection))
    }
    .accessibilityLabel(field.label)
    .accessibilityValue(field.pickerValueText)
    .sheet(isPresented: $field.isPickerPresented) {
      ChoicePickerView(
        title: field.label,
        searchPlaceholder: field.pickerSearchPlaceholder,
        showsSearch: field.pickerShowsSearch,
        noneTitle: field.pickerShowsNone ? field.pickerNoneTitle : nil,
        options: field.field.options,
        selected: field.selectedOption,
        onSelect: { field.pickerOptionTapped($0) },
        onNone: { field.pickerNoneTapped() },
        onClose: { field.pickerCloseTapped() })
    }
  }
}
