//
//  AddressFieldView.swift
//  PlayolaRadio
//

import SwiftUI

struct AddressFieldView: View {
  @Bindable var address: AddressFieldModel
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        ClaimFieldLabel(text: label)
        Spacer()
        Text(address.captionText)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaTextTertiary)
      }
      ClaimTextInput(
        placeholder: address.fullNamePlaceholder, text: $address.fullName,
        contentType: .name, capitalization: .words)
      ClaimTextInput(
        placeholder: address.addressLine1Placeholder, text: $address.addressLine1,
        contentType: .streetAddressLine1, capitalization: .words)
      ClaimTextInput(
        placeholder: address.addressLine2Placeholder, text: $address.addressLine2,
        contentType: .streetAddressLine2, capitalization: .words)
      ClaimTextInput(
        placeholder: address.cityPlaceholder, text: $address.city,
        contentType: .addressCity, capitalization: .words)
      HStack(spacing: 8) {
        stateRow
        ClaimTextInput(
          placeholder: address.zipPlaceholder, text: $address.postalCode,
          contentType: .postalCode, keyboardType: .numberPad)
      }
    }
  }

  private var stateRow: some View {
    Button {
      address.stateRowTapped()
    } label: {
      HStack(spacing: 8) {
        Text(address.stateValueText)
          .font(.custom(FontNames.Inter_400_Regular, size: 16))
          .foregroundColor(address.isStatePlaceholder ? .playolaTextTertiary : .playolaTextPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "chevron.down")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.playolaTextTertiary)
      }
      .padding(.leading, 16)
      .padding(.trailing, 12)
      .frame(height: 48)
      .background(RoundedRectangle(cornerRadius: 8).fill(Color.playolaSurfaceSection))
    }
    .accessibilityLabel(address.statePlaceholder)
    .accessibilityValue(address.stateValueText)
    .sheet(item: $address.statePicker) { picker in
      ChoicePickerView(model: picker)
    }
  }
}
