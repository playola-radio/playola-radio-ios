//
//  UpsideDownKeyboardModelTests.swift
//  PlayolaRadio
//

import CoreGraphics
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
        [".", ",", "?", "!", "'", "#", "+", "=", "⌫"],
        ["ABC", "space", "return"],
      ]
    )
  }

  @Test
  func testNumbersLayoutIncludesCommonSymbols() {
    let model = UpsideDownKeyboardModel()

    model.keyTapped(.layoutToggle)

    expectNoDifference(
      keys(in: model.rows[2]).map(\.label),
      [".", ",", "?", "!", "'", "#", "+", "=", "⌫"]
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

  @Test
  func testPlacedKeysUseSystemKeyboardSpacing() {
    let model = UpsideDownKeyboardModel()

    let frames = model.placedKeys(keyboardWidth: 388).map(\.frame)

    expectNoDifference(frames[0], CGRect(x: 7, y: 8, width: 32, height: 44))
    expectNoDifference(frames[9].maxX, 381)
    expectNoDifference(frames[10], CGRect(x: 26, y: 64, width: 32, height: 44))
  }

  @Test
  func testNumbersThirdRowKeysStaySeparateAndEmitDistinctCommands() {
    let model = UpsideDownKeyboardModel()
    var commands: [UpsideDownKeyboardModel.Command] = []
    model.onCommand = { commands.append($0) }

    model.keyTapped(.layoutToggle)
    let thirdRow = model.placedKeys(keyboardWidth: 388).filter { $0.frame.minY == 120 }
    let equals = thirdRow.first { $0.key.action == .character("=") }!
    let delete = thirdRow.first { $0.key.action == .delete }!

    #expect(equals.frame.maxX < delete.frame.minX)
    #expect(equals.frame.minX >= 0)
    #expect(delete.frame.maxX <= 388)
    model.keyboardTouchEnded(
      at: CGPoint(x: equals.frame.midX, y: equals.frame.midY), keyboardWidth: 388)
    model.keyboardTouchEnded(
      at: CGPoint(x: delete.frame.midX, y: delete.frame.midY), keyboardWidth: 388)

    expectNoDifference(commands, [.insertText("="), .deleteBackward])
  }

  @Test
  func testTouchInsideKeyTypesThatKey() {
    let model = UpsideDownKeyboardModel()
    var commands: [UpsideDownKeyboardModel.Command] = []
    model.onCommand = { commands.append($0) }

    model.keyboardTouchEnded(at: CGPoint(x: 99, y: 30), keyboardWidth: 388)

    expectNoDifference(commands, [.insertText("E")])
  }

  @Test
  func testTouchInGapBetweenKeysTypesTheNearerKey() {
    let model = UpsideDownKeyboardModel()
    var commands: [UpsideDownKeyboardModel.Command] = []
    model.onCommand = { commands.append($0) }

    model.keyboardTouchEnded(at: CGPoint(x: 116, y: 30), keyboardWidth: 388)
    model.keyboardTouchEnded(at: CGPoint(x: 120, y: 30), keyboardWidth: 388)

    expectNoDifference(commands, [.insertText("E"), .insertText("r")])
  }

  @Test
  func testTouchBetweenRowsTypesTheNearerRow() {
    let model = UpsideDownKeyboardModel()
    var commands: [UpsideDownKeyboardModel.Command] = []
    model.onCommand = { commands.append($0) }

    model.keyboardTouchEnded(at: CGPoint(x: 30, y: 55), keyboardWidth: 388)
    model.keyboardTouchEnded(at: CGPoint(x: 30, y: 62), keyboardWidth: 388)

    expectNoDifference(commands, [.insertText("Q"), .insertText("a")])
  }

  @Test
  func testTouchInSecondRowMarginTypesTheEdgeKey() {
    let model = UpsideDownKeyboardModel()
    var commands: [UpsideDownKeyboardModel.Command] = []
    model.onCommand = { commands.append($0) }

    model.keyboardTouchEnded(at: CGPoint(x: 10, y: 86), keyboardWidth: 388)

    expectNoDifference(commands, [.insertText("A")])
  }

  @Test
  func testSimultaneousTouchEndsUseTheLayoutFromBeforeEitherAction() {
    let model = UpsideDownKeyboardModel()
    var commands: [UpsideDownKeyboardModel.Command] = []
    model.onCommand = { commands.append($0) }

    model.keyboardTouchesEnded(
      at: [CGPoint(x: 23, y: 198), CGPoint(x: 137, y: 30)],
      keyboardWidth: 388
    )

    expectNoDifference(commands, [.insertText("r")])
  }

  @Test
  func testTouchesChangedPressesTheTouchedKeys() {
    let model = UpsideDownKeyboardModel()

    model.keyboardTouchesChanged(
      at: [CGPoint(x: 23, y: 30), CGPoint(x: 365, y: 30)],
      keyboardWidth: 388
    )

    expectNoDifference(model.pressedKeys, [.character("q"), .character("p")])
  }

  @Test
  func testTouchesChangedWithNoTouchesReleasesKeys() {
    let model = UpsideDownKeyboardModel()
    model.keyboardTouchesChanged(at: [CGPoint(x: 23, y: 30)], keyboardWidth: 388)

    expectDifference(model.pressedKeys) {
      model.keyboardTouchesChanged(at: [], keyboardWidth: 388)
    } changes: {
      $0 = []
    }
  }

  @Test
  func testTouchFarFromEveryKeyTypesNothing() {
    let model = UpsideDownKeyboardModel()
    var commands: [UpsideDownKeyboardModel.Command] = []
    model.onCommand = { commands.append($0) }

    model.keyboardTouchEnded(at: CGPoint(x: 194, y: 300), keyboardWidth: 388)

    expectNoDifference(commands, [])
  }

  @Test
  func testTouchesFarFromEveryKeyPressNothing() {
    let model = UpsideDownKeyboardModel()

    model.keyboardTouchesChanged(at: [CGPoint(x: 194, y: 300)], keyboardWidth: 388)

    expectNoDifference(model.pressedKeys, [])
  }

  // MARK: - Helpers

  private func keys(in row: UpsideDownKeyboardModel.Row) -> [UpsideDownKeyboardModel.Key] {
    Array(row.leading) + Array(row.center) + Array(row.trailing)
  }
}
