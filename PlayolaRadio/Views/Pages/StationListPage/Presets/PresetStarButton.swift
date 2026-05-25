//
//  PresetStarButton.swift
//  PlayolaRadio
//

import SwiftUI

struct PresetStarButton: View {
  let isPreset: Bool
  let label: String
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
    .accessibilityLabel(
      isPreset ? "Remove \(label) from presets" : "Add \(label) to presets"
    )
    .accessibilityAddTraits(isPreset ? [.isSelected] : [])
  }
}

#Preview {
  HStack(spacing: 20) {
    PresetStarButton(isPreset: false, label: "Test") {}
    PresetStarButton(isPreset: true, label: "Test") {}
  }
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
