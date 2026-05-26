//
//  StationListStationRowView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 9/26/25.
//

import SwiftUI

struct StationListStationRowView: View {
  let model: StationListStationRowModel
  let action: () -> Void
  let isPreset: Bool
  let presetAccessibilityLabel: String
  let onTogglePreset: () async -> Void

  var body: some View {
    HStack(spacing: 0) {
      Button(action: action) {
        HStack(spacing: 16) {
          AsyncImage(url: model.imageUrl) { image in
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          } placeholder: {
            Color(hex: "#333333")
          }
          .frame(width: 64, height: 64)
          .clipped()
          .cornerRadius(6)

          VStack(alignment: .leading, spacing: 2) {
            Text(model.titleText)
              .font(.custom(FontNames.Inter_500_Medium, size: 22))
              .foregroundColor(.white)
              .multilineTextAlignment(.leading)

            Text(model.subtitleText)
              .font(.custom(FontNames.Inter_400_Regular, size: 14))
              .foregroundColor(model.subtitleColor)
              .multilineTextAlignment(.leading)
          }

          Spacer()

          if let liveStatus = model.liveStatus {
            LiveBadge(status: liveStatus)
              .padding(.trailing, 8)
              .transition(.opacity.combined(with: .scale))
          }
        }
        .padding(.leading)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.5), value: model.liveStatus)
      }
      .buttonStyle(.plain)

      PresetStarButton(
        isPreset: isPreset,
        accessibilityLabel: presetAccessibilityLabel,
        onToggle: onTogglePreset
      )
      .padding(.trailing, 4)
    }
  }
}

#Preview("Station Row") {
  let sampleList = StationList.mocks.first!
  let sampleItem = sampleList.visibleStationItems.first!
  return StationListStationRowView(
    model: StationListStationRowModel(item: sampleItem),
    action: {},
    isPreset: false,
    presetAccessibilityLabel: "Add station to presets",
    onTogglePreset: {}
  )
  .preferredColorScheme(.dark)
}
