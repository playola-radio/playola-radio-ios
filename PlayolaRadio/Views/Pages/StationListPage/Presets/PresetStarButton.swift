//
//  PresetStarButton.swift
//  PlayolaRadio
//

import SwiftUI

struct PresetStarButton: View {
  let isPreset: Bool
  let accessibilityLabel: String
  let onToggle: () async -> Void

  var body: some View {
    Button {
      Task { await onToggle() }
    } label: {
      Image(systemName: isPreset ? "star.fill" : "star")
        .font(.system(size: 22, weight: .regular))
        .foregroundColor(isPreset ? Color(hex: "#FFD24A") : Color(hex: "#888888"))
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(isPreset ? [.isSelected] : [])
  }
}

#Preview {
  HStack(spacing: 20) {
    PresetStarButton(isPreset: false, accessibilityLabel: "Add Test to presets") {}
    PresetStarButton(isPreset: true, accessibilityLabel: "Remove Test from presets") {}
  }
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
