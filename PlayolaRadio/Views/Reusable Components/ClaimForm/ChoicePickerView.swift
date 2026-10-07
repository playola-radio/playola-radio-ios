//
//  ChoicePickerView.swift
//  PlayolaRadio
//

import SwiftUI

struct ChoicePickerView: View {
  let title: String
  let searchPlaceholder: String
  let showsSearch: Bool
  let noneTitle: String?
  let options: [String]
  let selected: String?
  let onSelect: (String) -> Void
  let onNone: () -> Void
  let onClose: () -> Void

  @State private var searchText = ""

  private var visibleOptions: [String] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard showsSearch, !query.isEmpty else { return options }
    return options.filter { $0.localizedCaseInsensitiveContains(query) }
  }

  var body: some View {
    VStack(spacing: 0) {
      navigationBar
      if showsSearch { searchField }
      ScrollView {
        LazyVStack(spacing: 0) {
          if let noneTitle {
            row(title: noneTitle, isSelected: selected == nil, action: onNone)
          }
          ForEach(visibleOptions, id: \.self) { option in
            row(title: option, isSelected: option == selected) { onSelect(option) }
          }
        }
        .padding(.horizontal, 16)
      }
      .scrollDismissesKeyboard(.interactively)
    }
    .background(Color.playolaSurfaceBase.ignoresSafeArea())
    .presentationDragIndicator(.visible)
    .presentationBackground(Color.playolaSurfaceBase)
  }

  private var navigationBar: some View {
    HStack {
      Button(action: onClose) {
        Image(systemName: "xmark")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.playolaTextPrimary)
          .frame(width: 44, height: 44)
          .background(Circle().fill(Color.playolaSurfaceRaised))
      }
      .accessibilityLabel("Close")
      Spacer()
      Text(title)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
        .foregroundColor(.playolaTextPrimary)
        .lineLimit(1)
      Spacer()
      Color.clear.frame(width: 44, height: 44)
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .frame(height: 64)
  }

  private var searchField: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 16))
        .foregroundColor(.playolaTextTertiary)
      TextField(
        "", text: $searchText,
        prompt: Text(searchPlaceholder).foregroundColor(.playolaTextTertiary)
      )
      .font(.custom(FontNames.Inter_400_Regular, size: 16))
      .foregroundColor(.playolaTextPrimary)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
    }
    .padding(.horizontal, 12)
    .frame(height: 44)
    .background(RoundedRectangle(cornerRadius: 10).fill(Color.playolaSurfaceSection))
    .padding(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
  }

  private func row(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Text(title)
          .font(
            .custom(
              isSelected ? FontNames.Inter_600_SemiBold : FontNames.Inter_400_Regular, size: 16)
          )
          .foregroundColor(.playolaTextPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "checkmark")
          .font(.system(size: 17, weight: .semibold))
          .foregroundColor(.playolaRed)
          .opacity(isSelected ? 1 : 0)
      }
      .frame(height: 52)
      .contentShape(Rectangle())
    }
    .overlay(alignment: .bottom) {
      Rectangle().fill(Color.playolaGlassHairline).frame(height: 1)
    }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
