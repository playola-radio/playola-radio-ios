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
  let isEditing: Bool
  let onTilePlay: (PresetDisplayItem) async -> Void
  let onTileLongPress: (PresetDisplayItem) -> Void
  let onTileRemove: (PresetDisplayItem) async -> Void
  let onMove: (Int, Int) async -> Void
  let onEditDoneTapped: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(sectionTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)
        Spacer()
        if isEditing {
          Button {
            onEditDoneTapped()
          } label: {
            Text("Done")
              .font(.custom(FontNames.Inter_500_Medium, size: 14))
              .foregroundColor(.playolaRed)
          }
          .buttonStyle(.plain)
        }
      }
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
          let tile = PresetTile(
            display: display,
            isEditing: isEditing,
            onTap: { await onTilePlay(display) },
            onLongPress: { onTileLongPress(display) },
            onRemoveTapped: { await onTileRemove(display) }
          )

          if isEditing && !display.isPending {
            tile
              .onDrag { NSItemProvider(object: display.id as NSString) }
              .onDrop(
                of: [.text],
                delegate: PresetDropDelegate(
                  item: display,
                  displays: displays,
                  isEditing: isEditing,
                  onMove: onMove
                ))
          } else {
            tile
          }
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
  let isEditing: Bool
  let onMove: (Int, Int) async -> Void

  func dropEntered(info: DropInfo) {
    guard isEditing else { return }
    guard let draggingId = info.itemProviders(for: [.text]).first,
      let fromIndex = displays.firstIndex(where: { $0.id != item.id }),
      let toIndex = displays.firstIndex(where: { $0.id == item.id })
    else { return }
    _ = draggingId
    Task { await onMove(fromIndex, toIndex) }
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    true
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
    isEditing: false,
    onTilePlay: { _ in },
    onTileLongPress: { _ in },
    onTileRemove: { _ in },
    onMove: { _, _ in },
    onEditDoneTapped: {}
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
    isEditing: false,
    onTilePlay: { _ in },
    onTileLongPress: { _ in },
    onTileRemove: { _ in },
    onMove: { _, _ in },
    onEditDoneTapped: {}
  )
  .padding(.vertical)
  .background(Color.black)
  .preferredColorScheme(.dark)
}
