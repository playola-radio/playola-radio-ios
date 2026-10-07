//
//  ClaimFieldModelTests.swift
//  PlayolaRadio
//

import CustomDump
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ClaimFieldModelTests {
  private let address = InfoField(
    key: "addr", label: "Shipping address", type: .address, options: [], required: true)
  private let optionalAddress = InfoField(
    key: "addr", label: "Shipping address", type: .address, options: [], required: false)
  private let size = InfoField(
    key: "size", label: "Shirt size", type: .singleChoice, options: ["S", "M", "L", "XL", "XXL"],
    required: true)
  private let note = InfoField(
    key: "note", label: "Name to sign it to", type: .shortText, options: [], required: false)
  private let fullAddress = ShippingAddress(
    fullName: "Jane", addressLine1: "1 Main", addressLine2: nil, city: "Austin", state: "TX",
    postalCode: "78701")

  @Test func testIdIsFieldKey() {
    #expect(ClaimFieldModel(field: note, prefill: nil).id == "note")
  }

  @Test func testWhitespaceOnlyRequiredTextIsMissing() {
    let field = ClaimFieldModel(
      field: InfoField(
        key: "n", label: "Guest list name", type: .shortText, options: [], required: true),
      prefill: nil)
    field.text = "   "
    expectNoDifference(field.missingParts, ["guest list name"])
    #expect(field.answer == nil)
  }

  @Test func testTextAnswerIsTrimmed() {
    let field = ClaimFieldModel(field: note, prefill: nil)
    field.text = "  Brian \n"
    #expect(field.answer == .text("Brian"))
  }

  @Test func testTextPrefillFillsText() {
    let field = ClaimFieldModel(field: note, prefill: .text("Brian"))
    #expect(field.text == "Brian")
  }

  @Test func testChoiceAnswerIsExactOption() {
    let field = ClaimFieldModel(field: size, prefill: nil)
    field.optionTapped("XL")
    #expect(field.answer == .text("XL"))
  }

  @Test func testRequiredChoiceWithoutSelectionIsMissing() {
    let field = ClaimFieldModel(field: size, prefill: nil)
    expectNoDifference(field.missingParts, ["shirt size"])
    #expect(field.answer == nil)
  }

  @Test func testRequiredChoiceStaysSelectedWhenTappedAgain() {
    let field = ClaimFieldModel(field: size, prefill: .text("M"))
    field.optionTapped("M")
    #expect(field.selectedOption == "M")
  }

  @Test func testOptionalChoiceDeselects() {
    let optionalSize = InfoField(
      key: "size", label: "Shirt size", type: .singleChoice, options: ["S", "M"], required: false)
    let field = ClaimFieldModel(field: optionalSize, prefill: .text("M"))
    field.optionTapped("M")
    #expect(field.selectedOption == nil)
    #expect(field.answer == nil)
  }

  @Test func testPrefillNotInOptionsIsIgnored() {
    let field = ClaimFieldModel(field: size, prefill: .text("Medium"))
    #expect(field.selectedOption == nil)
  }

  @Test func testPartialOptionalAddressBlocksSend() {
    let field = ClaimFieldModel(field: optionalAddress, prefill: nil)
    field.address.city = "Austin"
    expectNoDifference(field.missingParts, ["name", "street address", "state", "ZIP"])
  }

  @Test func testBlankOptionalAddressIsOmitted() {
    let field = ClaimFieldModel(field: optionalAddress, prefill: nil)
    #expect(field.missingParts.isEmpty)
    #expect(field.answer == nil)
  }

  @Test func testBlankRequiredAddressIsMissingAndOmitted() {
    let field = ClaimFieldModel(field: address, prefill: nil)
    expectNoDifference(field.missingParts, ["name", "street address", "city", "state", "ZIP"])
    #expect(field.answer == nil)
  }

  @Test func testCompleteAddressAnswer() {
    let field = ClaimFieldModel(field: address, prefill: .address(fullAddress))
    #expect(field.missingParts.isEmpty)
    #expect(field.answer == .address(fullAddress))
  }

  @Test func testPrefilledZipPlusFourIsValid() {
    var legacy = fullAddress
    legacy.postalCode = "78701-1234"
    let field = ClaimFieldModel(field: address, prefill: .address(legacy))
    #expect(field.missingParts.isEmpty)
    #expect(!field.hasMalformedZip)
    #expect(field.answer == .address(legacy))
  }

  @Test func testMalformedZipIsFlaggedNotMissing() {
    var bad = fullAddress
    bad.postalCode = "7870"
    let field = ClaimFieldModel(field: address, prefill: .address(bad))
    #expect(field.missingParts.isEmpty)
    #expect(field.hasMalformedZip)
  }

  @Test func testStateMustBeServerCode() {
    var bad = fullAddress
    bad.state = "XX"
    let field = ClaimFieldModel(field: address, prefill: .address(bad))
    expectNoDifference(field.missingParts, ["state"])
  }

  @Test(arguments: [
    (["S", "M", "L", "XL", "XXL"], ChoicePresentation.chips),
    (["Small", "Medium"], .inlineList),
    (["A", "B", "C", "D", "E", "F"], .inlineList),
    (["1", "2", "3", "4", "5", "6", "7"], .picker),
    (["Only"], .inlineList),
  ])
  func testChoicePresentationRule(options: [String], expected: ChoicePresentation) {
    #expect(ChoicePresentation.forOptions(options) == expected)
  }

  @Test func testKindFollowsFieldType() {
    let multiLine = InfoField(
      key: "m", label: "Message", type: .multiLineText, options: [], required: false)
    let unknown = InfoField(
      key: "u", label: "Mystery", type: .unknown, options: [], required: false)
    #expect(ClaimFieldModel(field: note, prefill: nil).kind == .text(multiLine: false))
    #expect(ClaimFieldModel(field: multiLine, prefill: nil).kind == .text(multiLine: true))
    #expect(ClaimFieldModel(field: unknown, prefill: nil).kind == .text(multiLine: false))
    #expect(ClaimFieldModel(field: size, prefill: nil).kind == .choice(.chips))
    #expect(ClaimFieldModel(field: address, prefill: nil).kind == .address)
  }

  @Test func testPickerOptions() {
    let many = InfoField(
      key: "c", label: "Country", type: .singleChoice,
      options: (1...13).map(String.init), required: false)
    let few = InfoField(
      key: "c", label: "Country", type: .singleChoice,
      options: (1...12).map(String.init), required: true)
    #expect(ClaimFieldModel(field: many, prefill: nil).pickerShowsSearch)
    #expect(ClaimFieldModel(field: many, prefill: nil).pickerShowsNone)
    #expect(!ClaimFieldModel(field: few, prefill: nil).pickerShowsSearch)
    #expect(!ClaimFieldModel(field: few, prefill: nil).pickerShowsNone)
  }

  @Test func testTextIsClampedToLimitInUTF16() {
    let field = ClaimFieldModel(field: note, prefill: nil)
    field.text = String(repeating: "😀", count: 200)
    #expect(field.text.utf16.count <= 255)
    #expect(field.text == String(repeating: "😀", count: 127))
  }

  @Test func testMultiLineTextAllowsFiveThousand() {
    let multiLine = InfoField(
      key: "m", label: "Message", type: .multiLineText, options: [], required: false)
    let field = ClaimFieldModel(field: multiLine, prefill: nil)
    field.text = String(repeating: "a", count: 6000)
    #expect(field.text.utf16.count == 5000)
  }

  @Test func testAddressPartsAreClamped() {
    let field = ClaimFieldModel(field: address, prefill: nil)
    field.address.city = String(repeating: "a", count: 400)
    #expect(field.address.city.utf16.count == 255)
  }
}
