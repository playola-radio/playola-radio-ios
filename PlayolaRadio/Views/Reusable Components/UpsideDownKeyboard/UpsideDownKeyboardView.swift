//
//  UpsideDownKeyboardView.swift
//  PlayolaRadio
//

import IdentifiedCollections
import SwiftUI

/// Spacing matches the iOS system keyboard: 7pt side margins, 6pt key gaps, 12pt row gaps.
struct UpsideDownKeyboardView: View {
  let model: UpsideDownKeyboardModel

  private let sideMargin: CGFloat = 7
  private let keyGap: CGFloat = 6
  private let rowGap: CGFloat = 12
  private let keyHeight: CGFloat = 44

  var body: some View {
    GeometryReader { proxy in
      let slotWidth = (proxy.size.width - 2 * sideMargin + keyGap) / 10
      VStack(spacing: rowGap) {
        ForEach(model.rows) { row in
          HStack(spacing: 0) {
            keys(row.leading, slotWidth: slotWidth)
              .frame(maxWidth: .infinity, alignment: .leading)
            keys(row.center, slotWidth: slotWidth)
            keys(row.trailing, slotWidth: slotWidth)
              .frame(maxWidth: .infinity, alignment: .trailing)
          }
        }
      }
      .padding(.horizontal, sideMargin)
      .padding(.top, 8)
    }
    .background(Color.playolaSurfaceSection)
  }

  private func keys(
    _ keys: IdentifiedArrayOf<UpsideDownKeyboardModel.Key>,
    slotWidth: CGFloat
  ) -> some View {
    HStack(spacing: keyGap) {
      ForEach(keys) { key in
        Button {
          model.keyTapped(key.action)
        } label: {
          Text(key.label)
            .font(.custom(FontNames.Inter_500_Medium, fixedSize: 18))
            .foregroundStyle(.white)
            .frame(width: slotWidth * key.widthInSlots - keyGap, height: keyHeight)
            .background(Color.playolaSurfaceControl, in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel(key.accessibilityLabel)
        .accessibilityAddTraits(.isKeyboardKey)
      }
    }
  }
}
