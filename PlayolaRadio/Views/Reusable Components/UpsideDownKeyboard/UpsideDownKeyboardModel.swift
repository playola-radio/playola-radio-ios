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
    var id: Action { action }
  }

  struct Row: Identifiable {
    let id: Int
    let keys: IdentifiedArrayOf<Key>
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
        Row(id: 0, keys: characterKeys("qwertyuiop")),
        Row(id: 1, keys: characterKeys("asdfghjkl")),
        Row(
          id: 2,
          keys: IdentifiedArrayOf(
            uniqueElements: [shiftKey] + Array(characterKeys("zxcvbnm")) + [deleteKey])),
        Row(id: 3, keys: bottomRow(layoutToggleLabel: "123", accessibilityLabel: "Numbers")),
      ]
    case .numbers:
      return [
        Row(id: 0, keys: characterKeys("1234567890")),
        Row(id: 1, keys: characterKeys("-/:;()$&@\"")),
        Row(id: 2, keys: characterKeys(".,?!'") + [deleteKey]),
        Row(id: 3, keys: bottomRow(layoutToggleLabel: "ABC", accessibilityLabel: "Letters")),
      ]
    }
  }

  // MARK: - Private Helpers

  private var shiftKey: Key { Key(action: .shift, label: "⇧", accessibilityLabel: "Shift") }
  private var deleteKey: Key { Key(action: .delete, label: "⌫", accessibilityLabel: "Delete") }

  private func displayed(_ character: String) -> String {
    layout == .letters && isShifted ? character.uppercased() : character
  }

  private func characterKeys(_ characters: String) -> IdentifiedArrayOf<Key> {
    IdentifiedArrayOf(
      uniqueElements: characters.map { character in
        let label = displayed(String(character))
        return Key(action: .character(String(character)), label: label, accessibilityLabel: label)
      })
  }

  private func bottomRow(
    layoutToggleLabel: String,
    accessibilityLabel: String
  ) -> IdentifiedArrayOf<Key> {
    IdentifiedArrayOf(
      uniqueElements: [
        Key(
          action: .layoutToggle, label: layoutToggleLabel, accessibilityLabel: accessibilityLabel),
        Key(action: .space, label: "space", accessibilityLabel: "Space"),
        Key(action: .returnKey, label: "return", accessibilityLabel: "Return"),
      ])
  }
}
