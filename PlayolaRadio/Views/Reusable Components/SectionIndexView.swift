//
//  SectionIndexView.swift
//  PlayolaRadio
//

import SwiftUI

struct SectionIndexView: View {
  let letters: [String]
  let onSelectLetter: (String) -> Void

  @GestureState private var isDragging = false
  @State private var selectedLetter: String?
  @State private var accessibilityIndex = 0

  // Layout constants the drag math is derived from, so the hit-testing can't drift from the
  // rendered geometry. Each letter cell is `letterHeight` tall with `letterSpacing` between cells
  // (row pitch), and the whole strip is inset by `verticalPadding` at the top and bottom.
  private enum Layout {
    static let letterHeight: CGFloat = 14
    static let letterSpacing: CGFloat = 2
    static let verticalPadding: CGFloat = 4
    static var rowPitch: CGFloat { letterHeight + letterSpacing }
  }

  var body: some View {
    VStack(spacing: Layout.letterSpacing) {
      ForEach(letters, id: \.self) { letter in
        Text(letter)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(selectedLetter == letter ? .playolaRed : .playolaGray)
          .frame(width: 16, height: Layout.letterHeight)
      }
    }
    .padding(.vertical, Layout.verticalPadding)
    .background(Color.black.opacity(0.3))
    .cornerRadius(8)
    .gesture(
      DragGesture(minimumDistance: 0)
        .updating($isDragging) { _, state, _ in
          state = true
        }
        .onChanged { value in
          // Subtract the top inset before mapping to a row so a touch lands on the letter under
          // the finger; without it every row is shifted down by `verticalPadding`.
          let index = Int((value.location.y - Layout.verticalPadding) / Layout.rowPitch)
          if index >= 0 && index < letters.count {
            let letter = letters[index]
            if selectedLetter != letter {
              selectedLetter = letter
              onSelectLetter(letter)
            }
          }
        }
        .onEnded { _ in
          selectedLetter = nil
        }
    )
    // Touch users scrub with the drag gesture above; expose the strip as a single adjustable
    // element so VoiceOver / Switch Control / Voice Control users can step through the sections too.
    .accessibilityElement()
    .accessibilityLabel("Section index")
    .accessibilityValue(accessibilityValue)
    .accessibilityAdjustableAction { direction in
      accessibilityAdjust(direction)
    }
  }

  private var accessibilityValue: String {
    guard letters.indices.contains(accessibilityIndex) else { return "" }
    return letters[accessibilityIndex]
  }

  private func accessibilityAdjust(_ direction: AccessibilityAdjustmentDirection) {
    guard !letters.isEmpty else { return }
    // `letters` can shrink (e.g. search narrows the index) while this view's identity — and so its
    // persisted `accessibilityIndex` — stays put. Re-clamp the stale index into the current range
    // before adjusting so the subscript below can never go out of bounds.
    let current = min(accessibilityIndex, letters.count - 1)
    switch direction {
    case .increment:
      accessibilityIndex = min(letters.count - 1, current + 1)
    case .decrement:
      accessibilityIndex = max(0, current - 1)
    @unknown default:
      return
    }
    onSelectLetter(letters[accessibilityIndex])
  }
}
