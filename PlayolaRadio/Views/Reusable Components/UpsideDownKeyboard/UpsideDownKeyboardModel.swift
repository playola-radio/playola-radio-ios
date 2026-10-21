//
//  UpsideDownKeyboardModel.swift
//  PlayolaRadio
//

import IdentifiedCollections
import Observation

/// The in-app keyboard shown while the app is flipped upside down, where the system
/// keyboard would appear right-side up.
@MainActor
@Observable
final class UpsideDownKeyboardModel: ViewModel {
  enum Command: Equatable {
    case insertText(String)
    case deleteBackward
    case returnKey
  }

  enum Action: Hashable {
    case character(String)
    case space
    case delete
    case shift
    case layoutToggle
    case returnKey
  }

  enum Layout: Equatable {
    case letters
    case numbers
  }

  struct Key: Identifiable {
    let action: Action
    let label: String
    let accessibilityLabel: String
    /// A letter key is one slot; the keyboard is ten slots wide.
    var widthInSlots = 1.0
    var id: Action { action }
  }

  /// Leading keys hug the left edge, trailing keys the right edge, and center keys are centered.
  struct Row: Identifiable {
    let id: Int
    var leading: IdentifiedArrayOf<Key> = []
    let center: IdentifiedArrayOf<Key>
    var trailing: IdentifiedArrayOf<Key> = []
  }

  // MARK: - Properties

  var layout = Layout.letters
  var isShifted = true
  @ObservationIgnored var onCommand: (Command) -> Void = { _ in }

  // MARK: - User Actions

  func keyTapped(_ action: Action) {
    switch action {
    case .character(let character):
      onCommand(.insertText(displayed(character)))
      isShifted = false
    case .space:
      onCommand(.insertText(" "))
    case .delete:
      onCommand(.deleteBackward)
    case .shift:
      isShifted.toggle()
    case .layoutToggle:
      layout = layout == .letters ? .numbers : .letters
    case .returnKey:
      onCommand(.returnKey)
    }
  }

  func editingBegan() {
    layout = .letters
    isShifted = true
  }

  // MARK: - View Helpers

  var rows: IdentifiedArrayOf<Row> {
    switch layout {
    case .letters:
      return [
        Row(id: 0, center: characterKeys("qwertyuiop")),
        Row(id: 1, center: characterKeys("asdfghjkl")),
        Row(id: 2, leading: [shiftKey], center: characterKeys("zxcvbnm"), trailing: [deleteKey]),
        bottomRow(layoutToggleLabel: "123", accessibilityLabel: "Numbers"),
      ]
    case .numbers:
      return [
        Row(id: 0, center: characterKeys("1234567890")),
        Row(id: 1, center: characterKeys("-/:;()$&@\"")),
        Row(id: 2, center: characterKeys(".,?!'", widthInSlots: 1.4), trailing: [deleteKey]),
        bottomRow(layoutToggleLabel: "ABC", accessibilityLabel: "Letters"),
      ]
    }
  }

  // MARK: - Private Helpers

  private var shiftKey: Key {
    Key(action: .shift, label: "⇧", accessibilityLabel: "Shift", widthInSlots: 1.3)
  }
  private var deleteKey: Key {
    Key(action: .delete, label: "⌫", accessibilityLabel: "Delete", widthInSlots: 1.3)
  }

  private func displayed(_ character: String) -> String {
    layout == .letters && isShifted ? character.uppercased() : character
  }

  private func characterKeys(
    _ characters: String,
    widthInSlots: Double = 1
  ) -> IdentifiedArrayOf<Key> {
    IdentifiedArrayOf(
      uniqueElements: characters.map { character in
        let label = displayed(String(character))
        return Key(
          action: .character(String(character)),
          label: label,
          accessibilityLabel: label,
          widthInSlots: widthInSlots
        )
      })
  }

  private func bottomRow(layoutToggleLabel: String, accessibilityLabel: String) -> Row {
    Row(
      id: 3,
      leading: [
        Key(
          action: .layoutToggle,
          label: layoutToggleLabel,
          accessibilityLabel: accessibilityLabel,
          widthInSlots: 2.5
        )
      ],
      center: [Key(action: .space, label: "space", accessibilityLabel: "Space", widthInSlots: 5)],
      trailing: [
        Key(action: .returnKey, label: "return", accessibilityLabel: "Return", widthInSlots: 2.5)
      ]
    )
  }
}
