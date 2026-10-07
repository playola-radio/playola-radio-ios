//
//  ClaimFieldView.swift
//  PlayolaRadio
//

import SwiftUI

extension View {
  func claimInputStyle() -> some View {
    padding(.horizontal, 16)
      .frame(minHeight: 48)
      .background(RoundedRectangle(cornerRadius: 8).fill(Color.playolaSurfaceSection))
  }
}

struct ClaimFieldLabel: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
      .foregroundColor(.playolaTextQuaternary)
  }
}

struct ClaimTextInput: View {
  let placeholder: String
  @Binding var text: String
  var multiLine = false
  var contentType: UITextContentType?
  var keyboardType: UIKeyboardType = .default
  var capitalization: TextInputAutocapitalization = .sentences

  var body: some View {
    TextField(
      "", text: $text,
      prompt: Text(placeholder).foregroundColor(.playolaTextTertiary),
      axis: multiLine ? .vertical : .horizontal
    )
    .lineLimit(multiLine ? 3...8 : 1...1)
    .font(.custom(FontNames.Inter_400_Regular, size: 16))
    .foregroundColor(.playolaTextPrimary)
    .textContentType(contentType)
    .keyboardType(keyboardType)
    .textInputAutocapitalization(capitalization)
    .padding(.vertical, multiLine ? 14 : 0)
    .claimInputStyle()
  }
}

struct ClaimFieldView: View {
  @Bindable var field: ClaimFieldModel

  var body: some View {
    switch field.kind {
    case .text(let multiLine):
      VStack(alignment: .leading, spacing: 8) {
        ClaimFieldLabel(text: field.label)
        ClaimTextInput(placeholder: "", text: $field.text, multiLine: multiLine)
          .accessibilityLabel(field.label)
      }
    case .choice(let presentation):
      ChoiceFieldView(field: field, presentation: presentation)
    case .address:
      AddressFieldView(address: field.address, label: field.label)
    }
  }
}
