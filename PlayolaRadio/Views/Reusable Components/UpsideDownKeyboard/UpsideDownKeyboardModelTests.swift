//
//  UpsideDownKeyboardModelTests.swift
//  PlayolaRadio
//

import CustomDump
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct UpsideDownKeyboardModelTests {
  @Test
  func testInitialLayoutShowsShiftedLetters() {
    let model = UpsideDownKeyboardModel()

    expectNoDifference(
      model.rows.map { keys(in: $0).map(\.label) },
      [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["⇧", "Z", "X", "C", "V", "B", "N", "M", "⌫"],
        ["123", "space", "return"],
      ]
    )
  }

  @Test
  func testCharacterTapInsertsShiftedLetterThenLowercase() {
    let model = UpsideDownKeyboardModel()
    var commands: [UpsideDownKeyboardModel.Command] = []
    model.onCommand = { commands.append($0) }

    model.keyTapped(.character("h"))
    model.keyTapped(.character("i"))

    expectNoDifference(commands, [.insertText("H"), .insertText("i")])
  }

  @Test
  func testShiftTapTogglesShift() {
    let model = UpsideDownKeyboardModel()

    expectDifference(model.isShifted) {
      model.keyTapped(.shift)
    } changes: {
      $0 = false
    }
  }

  @Test
  func testSpaceDeleteAndReturnEmitCommands() {
    let model = UpsideDownKeyboardModel()
    var commands: [UpsideDownKeyboardModel.Command] = []
    model.onCommand = { commands.append($0) }

    model.keyTapped(.space)
    model.keyTapped(.delete)
    model.keyTapped(.returnKey)

    expectNoDifference(commands, [.insertText(" "), .deleteBackward, .returnKey])
  }

  @Test
  func testLayoutToggleShowsNumbersAndPunctuation() {
    let model = UpsideDownKeyboardModel()

    model.keyTapped(.layoutToggle)

    expectNoDifference(
      model.rows.map { keys(in: $0).map(\.label) },
      [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [".", ",", "?", "!", "'", "⌫"],
        ["ABC", "space", "return"],
      ]
    )
  }

  @Test
  func testEveryLayoutHasUniqueRowAndKeyIDs() {
    let model = UpsideDownKeyboardModel()

    for layout in [UpsideDownKeyboardModel.Layout.letters, .numbers] {
      model.layout = layout

      expectNoDifference(Set(model.rows.ids).count, model.rows.count)
      for row in model.rows {
        let ids = keys(in: row).map(\.id)
        expectNoDifference(Set(ids).count, ids.count)
      }
    }
  }

  @Test
  func testEveryRowFitsTheKeyboardWidth() {
    let model = UpsideDownKeyboardModel()

    for layout in [UpsideDownKeyboardModel.Layout.letters, .numbers] {
      model.layout = layout

      for row in model.rows {
        #expect(keys(in: row).map(\.widthInSlots).reduce(0, +) <= 10)
      }
    }
  }

  @Test
  func testNumberTapInsertsNumberUnchanged() {
    let model = UpsideDownKeyboardModel()
    var commands: [UpsideDownKeyboardModel.Command] = []
    model.onCommand = { commands.append($0) }

    model.keyTapped(.layoutToggle)
    model.keyTapped(.character("7"))

    expectNoDifference(commands, [.insertText("7")])
  }

  @Test
  func testLayoutToggleFromNumbersRestoresLetters() {
    let model = UpsideDownKeyboardModel()
    model.keyTapped(.layoutToggle)

    expectDifference(model.layout) {
      model.keyTapped(.layoutToggle)
    } changes: {
      $0 = .letters
    }
  }

  @Test
  func testEditingBeganResetsToShiftedLetters() {
    let model = UpsideDownKeyboardModel()
    model.keyTapped(.shift)
    model.keyTapped(.layoutToggle)

    model.editingBegan()

    expectNoDifference(model.layout, .letters)
    expectNoDifference(model.isShifted, true)
  }

  @Test
  func testAccessibilityLabelsNameTheSymbolKeys() {
    let model = UpsideDownKeyboardModel()

    expectNoDifference(
      keys(in: model.rows[2]).map(\.accessibilityLabel),
      ["Shift", "Z", "X", "C", "V", "B", "N", "M", "Delete"]
    )
  }

  // MARK: - Helpers

  private func keys(in row: UpsideDownKeyboardModel.Row) -> [UpsideDownKeyboardModel.Key] {
    Array(row.leading) + Array(row.center) + Array(row.trailing)
  }
}
