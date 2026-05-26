//
//  PresetTile.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SwiftUI

struct PresetTile: View {
  let display: PresetDisplayItem
  let isEditing: Bool
  let onTap: () async -> Void
  let onLongPress: () -> Void
  let onRemoveTapped: () async -> Void

  @State private var wigglePhase = false

  private var station: AnyStation { display.stationItem.anyStation }
  private var title: String { station.name }

  private var subtitle: (text: String, color: Color)? {
    let item = display.stationItem
    let isComingSoon = item.visibility == .comingSoon || !station.active
    guard isComingSoon else { return nil }
    return ("Coming Soon", Color.playolaRed)
  }

  var body: some View {
    Button {
      Task { await onTap() }
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        AsyncImage(url: station.imageUrl) { image in
          image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
          Color(hex: "#333333")
        }
        .frame(width: 92, height: 92)
        .clipped()
        .cornerRadius(8)
        .overlay(alignment: .topLeading) {
          if isEditing && !display.isPending {
            Button {
              Task { await onRemoveTapped() }
            } label: {
              Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color(hex: "#EF6962")))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: -10, y: -10)
            .accessibilityLabel("Remove \(title) from presets")
          }
        }

        Text(title)
          .font(.custom(FontNames.Inter_500_Medium, size: 13))
          .foregroundColor(.white)
          .lineLimit(2)
          .multilineTextAlignment(.leading)

        if let sub = subtitle {
          Text(sub.text)
            .font(.custom(FontNames.Inter_500_Medium, size: 11))
            .foregroundColor(sub.color)
            .lineLimit(1)
        }
      }
      .frame(width: 92, alignment: .leading)
    }
    .buttonStyle(.plain)
    .opacity(display.isPending ? 0.6 : 1.0)
    .rotationEffect(.degrees(isEditing ? (wigglePhase ? -1.5 : 1.5) : 0))
    .animation(
      isEditing
        ? .linear(duration: 0.14).repeatForever(autoreverses: true)
        : .default,
      value: wigglePhase
    )
    .onChange(of: isEditing) { _, newValue in
      wigglePhase = newValue
    }
    .onAppear {
      if isEditing { wigglePhase = true }
    }
    .onLongPressGesture(minimumDuration: 0.5) {
      guard !display.isPending else { return }
      onLongPress()
    }
    .accessibilityLabel("Preset: \(title)")
  }
}

#Preview {
  let station = Station.mockWith(id: "s1", name: "Spark Radio", curatorName: "Bri Bagwell")
  let item = APIStationItem(
    sortOrder: 0, visibility: .visible, station: station, urlStation: nil
  )
  let display = PresetDisplayItem(id: "p1", stationItem: item, isPending: false)
  return PresetTile(
    display: display, isEditing: false, onTap: {}, onLongPress: {}, onRemoveTapped: {}
  )
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
