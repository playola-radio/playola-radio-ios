//
//  UpsideDownKeyboardModel.swift
//  PlayolaRadio
//

import CoreGraphics
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

  struct PlacedKey: Identifiable {
    let key: Key
    let frame: CGRect
    var id: Action { key.action }
  }

  /// Spacing matches the iOS system keyboard: 7pt side margins, 6pt key gaps, 12pt row gaps.
  private enum Metrics {
    static let sideMargin: CGFloat = 7
    static let keyGap: CGFloat = 6
    static let rowGap: CGFloat = 12
    static let keyHeight: CGFloat = 44
    static let topInset: CGFloat = 8
    static let slotsPerRow = 10.0
    static let maxTouchDistance: CGFloat = 30
  }

  // MARK: - Properties

  var layout = Layout.letters
  var isShifted = true
  var pressedKeys: Set<Action> = []
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

  /// Like the system keyboard, a touch types the key nearest to where it lifted, so the gaps
  /// between keys are never dead zones. Dragging well away from every key cancels the press.
  func keyboardTouchEnded(at point: CGPoint, keyboardWidth: CGFloat) {
    guard let key = nearestKey(to: point, keyboardWidth: keyboardWidth) else { return }
    keyTapped(key.action)
  }

  func keyboardTouchesEnded(at points: [CGPoint], keyboardWidth: CGFloat) {
    let actions = points.compactMap { nearestKey(to: $0, keyboardWidth: keyboardWidth)?.action }
    actions.forEach(keyTapped)
  }

  func keyboardTouchesChanged(at points: [CGPoint], keyboardWidth: CGFloat) {
    pressedKeys = Set(
      points.compactMap { nearestKey(to: $0, keyboardWidth: keyboardWidth)?.action })
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
        Row(id: 2, center: characterKeys(".,?!'#+=", widthInSlots: 1.05), trailing: [deleteKey]),
        bottomRow(layoutToggleLabel: "ABC", accessibilityLabel: "Letters"),
      ]
    }
  }

  func placedKeys(keyboardWidth: CGFloat) -> [PlacedKey] {
    let slotWidth = (keyboardWidth - 2 * Metrics.sideMargin + Metrics.keyGap) / Metrics.slotsPerRow
    return rows.enumerated().flatMap { index, row in
      let rowTop = Metrics.topInset + CGFloat(index) * (Metrics.keyHeight + Metrics.rowGap)
      let leadingSlots = slots(row.leading)
      let trailingSlots = slots(row.trailing)
      let centerStart =
        leadingSlots + (Metrics.slotsPerRow - leadingSlots - slots(row.center) - trailingSlots) / 2
      return place(row.leading, fromSlot: 0, rowTop: rowTop, slotWidth: slotWidth)
        + place(row.center, fromSlot: centerStart, rowTop: rowTop, slotWidth: slotWidth)
        + place(
          row.trailing, fromSlot: Metrics.slotsPerRow - trailingSlots, rowTop: rowTop,
          slotWidth: slotWidth)
    }
  }

  func keyOpacity(_ key: PlacedKey) -> Double {
    pressedKeys.contains(key.id) ? 0.5 : 1
  }

  // MARK: - Private Helpers

  private func nearestKey(to point: CGPoint, keyboardWidth: CGFloat) -> Key? {
    let distances = placedKeys(keyboardWidth: keyboardWidth).map {
      (key: $0.key, distance: squaredDistance(from: point, to: $0.frame))
    }
    guard let nearest = distances.min(by: { $0.distance < $1.distance }),
      nearest.distance <= Metrics.maxTouchDistance * Metrics.maxTouchDistance
    else { return nil }
    return nearest.key
  }

  private func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
    let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
    let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
    return dx * dx + dy * dy
  }

  private func slots(_ keys: IdentifiedArrayOf<Key>) -> Double {
    keys.map(\.widthInSlots).reduce(0, +)
  }

  private func place(
    _ keys: IdentifiedArrayOf<Key>,
    fromSlot startSlot: Double,
    rowTop: CGFloat,
    slotWidth: CGFloat
  ) -> [PlacedKey] {
    var slot = startSlot
    return keys.map { key in
      defer { slot += key.widthInSlots }
      return PlacedKey(
        key: key,
        frame: CGRect(
          x: Metrics.sideMargin + slot * slotWidth,
          y: rowTop,
          width: key.widthInSlots * slotWidth - Metrics.keyGap,
          height: Metrics.keyHeight
        )
      )
    }
  }

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
