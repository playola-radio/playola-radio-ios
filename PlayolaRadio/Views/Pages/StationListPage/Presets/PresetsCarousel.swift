//
//  PresetsCarousel.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

struct PresetsCarousel: View {
  let displays: [PresetDisplayItem]
  let sectionTitle: String
  let emptyStateText: String
  let onTilePlay: (PresetDisplayItem) async -> Void
  let onTileLongPress: (PresetDisplayItem) -> Void
  let onMove: (Int, Int) async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(sectionTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
        .foregroundColor(.white)
        .padding(.horizontal, 16)

      if displays.isEmpty {
        emptyState
      } else {
        tiles
      }
    }
  }

  private var emptyState: some View {
    HStack(spacing: 16) {
      Image(systemName: "star.fill")
        .font(.system(size: 24))
        .foregroundColor(Color(hex: "#FFD24A"))
      Text(emptyStateText)
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .foregroundColor(Color(hex: "#AAAAAA"))
        .lineLimit(2)
      Spacer(minLength: 0)
    }
    .padding(16)
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(
          Color(hex: "#333333"),
          style: StrokeStyle(lineWidth: 1, dash: [4])
        )
    )
    .padding(.horizontal, 16)
  }

  private var tiles: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(displays) { display in
          PresetTile(
            display: display,
            onTap: { await onTilePlay(display) },
            onLongPress: { onTileLongPress(display) }
          )
        }
      }
      .padding(.horizontal, 16)
    }
    .overlay(alignment: .trailing) {
      LinearGradient(
        colors: [Color.black.opacity(0), Color.black],
        startPoint: .leading,
        endPoint: .trailing
      )
      .frame(width: 24)
      .allowsHitTesting(false)
    }
  }
}

#Preview("With Presets") {
  let stations = (0..<5).map { i in
    Station.mockWith(id: "s\(i)", name: "Station \(i)", curatorName: "Curator \(i)")
  }
  let items = stations.enumerated().map { idx, station in
    APIStationItem(sortOrder: idx, visibility: .visible, station: station, urlStation: nil)
  }
  let displays = items.enumerated().map { idx, item in
    PresetDisplayItem(id: "p\(idx)", stationItem: item, isPending: false)
  }
  return PresetsCarousel(
    displays: displays,
    sectionTitle: "Presets",
    emptyStateText: "Tap the ★ on any station to save it here.",
    onTilePlay: { _ in },
    onTileLongPress: { _ in },
    onMove: { _, _ in }
  )
  .padding(.vertical)
  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Empty") {
  PresetsCarousel(
    displays: [],
    sectionTitle: "Presets",
    emptyStateText: "Tap the ★ on any station to save it here.",
    onTilePlay: { _ in },
    onTileLongPress: { _ in },
    onMove: { _, _ in }
  )
  .padding(.vertical)
  .background(Color.black)
  .preferredColorScheme(.dark)
}
