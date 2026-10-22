import CustomDump
import SwiftUI
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct SectionIndexViewTests {
  @Test func dragSelectionDeduplicatesAndClearsAtTheEnd() {
    var selections: [String] = []
    let model = SectionIndexModel(letters: ["A", "B", "C"]) {
      selections.append($0)
    }

    model.dragChanged(locationY: 21)
    model.dragChanged(locationY: 21)
    expectNoDifference(model.selectedLetter, "B")
    expectNoDifference(selections, ["B"])

    model.dragEnded()
    expectNoDifference(model.selectedLetter, nil)
  }

  @Test func accessibilityAdjustmentClampsAfterLettersShrink() {
    var selections: [String] = []
    let model = SectionIndexModel(letters: ["A", "B", "C"]) {
      selections.append($0)
    }

    model.accessibilityAdjusted(.increment)
    model.accessibilityAdjusted(.increment)
    model.lettersChanged(["A"])
    model.accessibilityAdjusted(.increment)

    expectNoDifference(model.accessibilityValue, "A")
    expectNoDifference(selections, ["B", "C", "A"])
  }
}
