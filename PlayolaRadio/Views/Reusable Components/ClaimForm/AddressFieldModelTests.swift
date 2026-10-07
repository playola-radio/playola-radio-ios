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
    #expect(!model.isComplete)
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
    #expect(model.isComplete)
    #expect(model.missingParts.isEmpty)
  }

  @Test func testZipMustMatchFiveOrNinePattern() {
    let model = filledModel()
    model.postalCode = "7870"
    #expect(model.hasMalformedZip)
    #expect(!model.isComplete)
    model.postalCode = "78704-1234"
    #expect(!model.hasMalformedZip)
    #expect(model.isComplete)
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
}
