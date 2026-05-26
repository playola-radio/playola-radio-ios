//
//  PresetTile.swift
//  PlayolaRadio
//

import PlayolaPlayer
import SDWebImageSwiftUI
import SwiftUI

struct PresetTile: View {
  let display: PresetDisplayItem
  let isEditing: Bool
  let onTap: () async -> Void
  let onLongPress: () -> Void
  let onRemoveTapped: () async -> Void

  @State private var wiggleAngle: Double = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      WebImage(url: display.imageUrl) { image in
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
          .accessibilityLabel(display.removeAccessibilityLabel)
        }
      }

      Text(display.title)
        .font(.custom(FontNames.Inter_500_Medium, size: 13))
        .foregroundColor(.white)
        .lineLimit(2)
        .multilineTextAlignment(.leading)

      if let subtitleText = display.subtitleText {
        Text(subtitleText)
          .font(.custom(FontNames.Inter_500_Medium, size: 11))
          .foregroundColor(display.subtitleColor ?? .white)
          .lineLimit(1)
      }
    }
    .frame(width: 92, alignment: .leading)
    .contentShape(Rectangle())
    .opacity(display.isPending ? 0.6 : 1.0)
    .rotationEffect(.degrees(wiggleAngle))
    .onChange(of: isEditing) { _, newValue in
      startOrStopWiggle(active: newValue)
    }
    .onAppear {
      startOrStopWiggle(active: isEditing)
    }
    .onLongPressGesture(minimumDuration: 0.5) {
      onLongPress()
    }
    .onTapGesture {
      Task { await onTap() }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(display.accessibilityLabel)
    .accessibilityAddTraits(.isButton)
  }

  private func startOrStopWiggle(active: Bool) {
    if active {
      wiggleAngle = -2.5
      withAnimation(.linear(duration: 0.13).repeatForever(autoreverses: true)) {
        wiggleAngle = 2.5
      }
    } else {
      withAnimation(.linear(duration: 0.1)) {
        wiggleAngle = 0
      }
    }
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
