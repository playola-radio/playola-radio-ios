//
//  SectionIndexView.swift
//  PlayolaRadio
//

import SwiftUI

@MainActor
@Observable
final class SectionIndexModel {
  static let accessibilityLabel = "Section index"

  var letters: [String]
  private(set) var selectedLetter: String?
  private var accessibilityIndex = 0
  private let onSelectLetter: (String) -> Void

  init(letters: [String], onSelectLetter: @escaping (String) -> Void) {
    self.letters = letters
    self.onSelectLetter = onSelectLetter
  }

  var accessibilityValue: String {
    guard letters.indices.contains(accessibilityIndex) else { return "" }
    return letters[accessibilityIndex]
  }

  func lettersChanged(_ letters: [String]) {
    self.letters = letters
  }

  func dragChanged(locationY: CGFloat) {
    let index = Int(
      (locationY - SectionIndexView.Layout.verticalPadding) / SectionIndexView.Layout.rowPitch)
    guard letters.indices.contains(index) else { return }
    select(letters[index])
  }

  func dragEnded() {
    selectedLetter = nil
  }

  func accessibilityAdjusted(_ direction: AccessibilityAdjustmentDirection) {
    guard !letters.isEmpty else { return }
    let current = min(accessibilityIndex, letters.count - 1)
    switch direction {
    case .increment:
      accessibilityIndex = min(letters.count - 1, current + 1)
    case .decrement:
      accessibilityIndex = max(0, current - 1)
    @unknown default:
      return
    }
    select(letters[accessibilityIndex])
  }

  private func select(_ letter: String) {
    guard selectedLetter != letter else { return }
    selectedLetter = letter
    onSelectLetter(letter)
  }
}

struct SectionIndexView: View {
  let letters: [String]

  @GestureState private var isDragging = false
  @State private var model: SectionIndexModel

  init(letters: [String], onSelectLetter: @escaping (String) -> Void) {
    self.letters = letters
    _model = State(
      initialValue: SectionIndexModel(letters: letters, onSelectLetter: onSelectLetter))
  }

  // Layout constants the drag math is derived from, so the hit-testing can't drift from the
  // rendered geometry. Each letter cell is `letterHeight` tall with `letterSpacing` between cells
  // (row pitch), and the whole strip is inset by `verticalPadding` at the top and bottom.
  fileprivate enum Layout {
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
          .foregroundColor(model.selectedLetter == letter ? .playolaRed : .playolaGray)
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
          model.dragChanged(locationY: value.location.y)
        }
        .onEnded { _ in
          model.dragEnded()
        }
    )
    .onChange(of: letters) { _, letters in model.lettersChanged(letters) }
    // Touch users scrub with the drag gesture above; expose the strip as a single adjustable
    // element so VoiceOver / Switch Control / Voice Control users can step through the sections too.
    .accessibilityElement()
    .accessibilityLabel(SectionIndexModel.accessibilityLabel)
    .accessibilityValue(model.accessibilityValue)
    .accessibilityAdjustableAction { direction in
      model.accessibilityAdjusted(direction)
    }
  }
}
