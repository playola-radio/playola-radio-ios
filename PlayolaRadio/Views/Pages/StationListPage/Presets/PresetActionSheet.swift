//
//  PresetActionSheet.swift
//  PlayolaRadio
//

import SwiftUI

struct PresetActionSheet: View {
  let preset: Preset
  let onRemove: () -> Void
  let onClose: () -> Void

  private var stationName: String {
    preset.station?.name ?? preset.urlStation?.name ?? "Station"
  }

  private var imageUrl: URL? {
    if let urlString = preset.station?.imageUrl ?? preset.urlStation?.imageUrl {
      return URL(string: urlString)
    }
    return nil
  }

  var body: some View {
    VStack(spacing: 0) {
      Capsule()
        .fill(Color(hex: "#5A5A5A"))
        .frame(width: 36, height: 4)
        .padding(.top, 10)

      HStack(spacing: 16) {
        AsyncImage(url: imageUrl) { image in
          image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
          Color(hex: "#666666")
        }
        .frame(width: 48, height: 48)
        .clipped()
        .cornerRadius(6)

        VStack(alignment: .leading, spacing: 2) {
          Text(stationName)
            .font(.custom(FontNames.Inter_500_Medium, size: 20))
            .foregroundColor(.white)
            .lineLimit(1)
          Text("Preset")
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(.white)
        }
        Spacer()
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 12)

      Rectangle()
        .fill(Color(hex: "#565656"))
        .frame(height: 1)

      Button {
        removeButtonTapped()
      } label: {
        HStack(spacing: 16) {
          Image(systemName: "star.fill")
            .font(.system(size: 22))
            .foregroundColor(Color(hex: "#FFD24A"))
            .frame(width: 32, height: 32)
          Text("Remove from Presets")
            .font(.custom(FontNames.Inter_400_Regular, size: 16))
            .foregroundColor(.white)
          Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity)
    .background(Color(hex: "#323232"))
  }

  private func removeButtonTapped() {
    onRemove()
    onClose()
  }
}

#Preview {
  PresetActionSheet(
    preset: Preset.mockPlayola(stationName: "Spark Radio"),
    onRemove: {},
    onClose: {}
  )
  .frame(height: 220)
  .preferredColorScheme(.dark)
}
