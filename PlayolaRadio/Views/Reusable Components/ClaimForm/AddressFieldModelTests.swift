//
//  AddressFieldModelTests.swift
//  PlayolaRadio
//

import CustomDump
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AddressFieldModelTests {
  private func filledModel() -> AddressFieldModel {
    AddressFieldModel(
      prefill: ShippingAddress(
        fullName: "Jane Doe", addressLine1: "123 Main St", addressLine2: nil, city: "Austin",
        state: "TX", postalCode: "78704"))
  }

  @Test func testPrefillNilStartsBlank() {
    let model = AddressFieldModel(prefill: nil)
    #expect(model.isBlank)
  }

  @Test func testPrefillFillsEveryPart() {
    let model = AddressFieldModel(
      prefill: ShippingAddress(
        fullName: "Jane", addressLine1: "1 Main", addressLine2: "Apt 2", city: "Austin",
        state: "TX", postalCode: "78701"))
    #expect(model.fullName == "Jane")
    #expect(model.addressLine2 == "Apt 2")
    #expect(!model.isBlank)
  }

  @Test func testMissingPartsListsEmptyPartsInOrder() {
    let model = AddressFieldModel(prefill: nil)
    expectNoDifference(model.missingParts, ["name", "street address", "city", "state", "ZIP"])
    model.fullName = "Jane"
    model.addressLine1 = "123 Main"
    model.city = "Austin"
    model.state = "TX"
    expectNoDifference(model.missingParts, ["ZIP"])
  }

  @Test func testCompleteWhenRequiredPartsFilled() {
    let model = filledModel()
    #expect(model.missingParts.isEmpty)
  }

  @Test func testZipMustMatchFiveOrNinePattern() {
    let model = filledModel()
    model.postalCode = "7870"
    #expect(model.hasMalformedZip)
    model.postalCode = "78704-1234"
    #expect(!model.hasMalformedZip)
    model.postalCode = "abcde"
    #expect(model.hasMalformedZip)
  }

  @Test func testEmptyZipIsMissingNotMalformed() {
    let model = filledModel()
    model.postalCode = ""
    expectNoDifference(model.missingParts, ["ZIP"])
    #expect(!model.hasMalformedZip)
  }

  @Test func testStateMustBeServerCode() {
    let model = filledModel()
    model.state = "Texas"
    expectNoDifference(model.missingParts, ["state"])
    model.state = "XX"
    expectNoDifference(model.missingParts, ["state"])
    model.state = "tx"
    #expect(model.missingParts.isEmpty)
    model.state = "PR"
    #expect(model.missingParts.isEmpty)
  }

  @Test func testWhitespaceOnlyPartsDoNotCount() {
    let model = filledModel()
    model.fullName = "   "
    expectNoDifference(model.missingParts, ["name"])
  }

  @Test func testIsBlankIgnoresWhitespace() {
    let model = AddressFieldModel(prefill: nil)
    model.city = "  \n"
    #expect(model.isBlank)
  }

  @Test func testAnswerTrimsAndOmitsEmptyLine2() {
    let model = filledModel()
    model.fullName = "  Jane Doe  "
    model.addressLine2 = "   "
    let address = model.answer()
    #expect(address.fullName == "Jane Doe")
    #expect(address.addressLine2 == nil)
    #expect(address.postalCode == "78704")
  }

  @Test func testAnswerKeepsNonEmptyLine2AndUppercasesState() {
    let model = filledModel()
    model.addressLine2 = " Apt 4 "
    model.state = "tx"
    let address = model.answer()
    #expect(address.addressLine2 == "Apt 4")
    #expect(address.state == "TX")
  }

  @Test func testPartsAreClampedToUTF16LimitOnCharacterBoundary() {
    let model = AddressFieldModel(prefill: nil)
    model.fullName = String(repeating: "😀", count: 200)
    #expect(model.fullName == String(repeating: "😀", count: 127))
    model.addressLine2 = String(repeating: "b", count: 300)
    #expect(model.addressLine2.utf16.count == 255)
  }

  @Test func testStateRowTappedPresentsConfiguredPicker() throws {
    let model = AddressFieldModel(prefill: nil)
    model.state = "CA"
    model.stateRowTapped()
    let picker = try #require(model.statePicker)
    #expect(picker.title == "State")
    expectNoDifference(picker.options, USStateCodes.all)
    #expect(picker.selectedOption == "CA")
    #expect(picker.showsSearch)
    #expect(!picker.showsNone)
  }

  @Test func testStatePickerSelectionSetsStateAndDismisses() throws {
    let model = AddressFieldModel(prefill: nil)
    model.stateRowTapped()
    try #require(model.statePicker).optionTapped("TX")
    #expect(model.state == "TX")
    #expect(model.statePicker == nil)
    #expect(model.stateValueText == "TX")
  }

  @Test func testStateValueTextIsPlaceholderUntilChosen() {
    let model = AddressFieldModel(prefill: nil)
    #expect(model.stateValueText == "State")
    #expect(model.isStatePlaceholder)
  }

  @Test func testStatePickerCloseKeepsState() throws {
    let model = AddressFieldModel(prefill: nil)
    model.state = "CA"
    model.stateRowTapped()
    try #require(model.statePicker).closeTapped()
    #expect(model.state == "CA")
    #expect(model.statePicker == nil)
  }
}
