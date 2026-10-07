//
//  ChoicePickerModelTests.swift
//  PlayolaRadio
//

import CustomDump
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ChoicePickerModelTests {
  private final class OutcomeRecorder {
    var outcomes: [ChoicePickerModel.Outcome] = []
  }

  private func makeModel(
    options: [String] = ["Alabama", "Alaska", "Arizona", "New Mexico", "new york"],
    selectedOption: String? = nil,
    showsSearch: Bool = true,
    showsNone: Bool = true,
    recorder: OutcomeRecorder = OutcomeRecorder()
  ) -> ChoicePickerModel {
    ChoicePickerModel(
      title: "State", options: options, selectedOption: selectedOption,
      showsSearch: showsSearch, showsNone: showsNone,
      onFinish: { recorder.outcomes.append($0) })
  }

  @Test func testCopy() {
    let model = makeModel()
    #expect(model.searchPlaceholder == "Search 5 options")
    #expect(model.noneTitle == "None")
    #expect(model.closeAccessibilityLabel == "Close")
  }

  @Test func testFilteredOptionsAreAllWhenSearchIsEmpty() {
    let model = makeModel()
    expectNoDifference(model.filteredOptions, model.options)
  }

  @Test func testFilteredOptionsMatchCaseInsensitively() {
    let model = makeModel()
    model.searchText = "NEW"
    expectNoDifference(model.filteredOptions, ["New Mexico", "new york"])
  }

  @Test func testFilteredOptionsIgnoreSurroundingWhitespace() {
    let model = makeModel()
    model.searchText = "  ala "
    expectNoDifference(model.filteredOptions, ["Alabama", "Alaska"])
  }

  @Test func testFilteredOptionsIgnoreSearchWhenSearchIsHidden() {
    let model = makeModel(showsSearch: false)
    model.searchText = "zzz"
    expectNoDifference(model.filteredOptions, model.options)
  }

  @Test func testIsOptionSelected() {
    let model = makeModel(selectedOption: "Alaska")
    #expect(model.isOptionSelected("Alaska"))
    #expect(!model.isOptionSelected("Alabama"))
    #expect(!model.isNoneSelected)
  }

  @Test func testIsNoneSelectedWhenNothingChosen() {
    #expect(makeModel().isNoneSelected)
  }

  @Test func testOptionTappedFinishesWithSelection() {
    let recorder = OutcomeRecorder()
    makeModel(recorder: recorder).optionTapped("Arizona")
    expectNoDifference(recorder.outcomes, [.selected("Arizona")])
  }

  @Test func testNoneTappedFinishesCleared() {
    let recorder = OutcomeRecorder()
    makeModel(selectedOption: "Alaska", recorder: recorder).noneTapped()
    expectNoDifference(recorder.outcomes, [.cleared])
  }

  @Test func testCloseTappedFinishesDismissed() {
    let recorder = OutcomeRecorder()
    makeModel(selectedOption: "Alaska", recorder: recorder).closeTapped()
    expectNoDifference(recorder.outcomes, [.dismissed])
  }
}
