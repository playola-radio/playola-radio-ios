//
//  PresetsCarousel.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI
import UniformTypeIdentifiers

struct PresetsCarousel: View {
  let displays: [PresetDisplayItem]
  let sectionTitle: String
  let emptyStateText: String
  let onTilePlay: (PresetDisplayItem) async -> Void
  let onTileLongPress: (PresetDisplayItem) -> Void
  let onMove: (Int, Int) async -> Void

  @State private var draggingId: String?

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
          .opacity(draggingId == display.id ? 0.4 : 1.0)
          .onDrag {
            guard !display.isPending else { return NSItemProvider() }
            draggingId = display.id
            return NSItemProvider(object: display.id as NSString)
          }
          .onDrop(
            of: [.text],
            delegate: PresetDropDelegate(
              item: display,
              displays: displays,
              draggingId: $draggingId,
              onMove: onMove
            ))
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

private struct PresetDropDelegate: DropDelegate {
  let item: PresetDisplayItem
  let displays: [PresetDisplayItem]
  @Binding var draggingId: String?
  let onMove: (Int, Int) async -> Void

  func dropEntered(info: DropInfo) {
    guard let draggingId,
      draggingId != item.id,
      let fromIndex = displays.firstIndex(where: { $0.id == draggingId }),
      let toIndex = displays.firstIndex(where: { $0.id == item.id })
    else { return }

    Task { await onMove(fromIndex, toIndex) }
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    draggingId = nil
    return true
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
