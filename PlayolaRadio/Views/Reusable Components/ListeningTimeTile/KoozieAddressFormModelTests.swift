//
//  KoozieAddressFormModelTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/10/26.
//

import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct KoozieAddressFormModelTests {
  private func filledModel() -> KoozieAddressFormModel {
    let model = KoozieAddressFormModel()
    model.fullName = "Jane Doe"
    model.addressLine1 = "123 Main St"
    model.city = "Austin"
    model.state = "TX"
    model.postalCode = "78704"
    return model
  }

  @Test func canSubmitFalseWhenRequiredFieldsBlank() {
    let model = KoozieAddressFormModel()
    #expect(model.canSubmit == false)
    model.fullName = "Jane"
    model.addressLine1 = "123 Main"
    model.city = "Austin"
    model.state = "TX"
    #expect(model.canSubmit == false)  // still missing ZIP
  }

  @Test func canSubmitTrueWhenRequiredFilledAndZipValid() {
    #expect(filledModel().canSubmit == true)
  }

  @Test func zipMustMatchFiveOrNinePattern() {
    let model = filledModel()
    model.postalCode = "7870"
    #expect(model.canSubmit == false)
    model.postalCode = "78704-1234"
    #expect(model.canSubmit == true)
    model.postalCode = "abcde"
    #expect(model.canSubmit == false)
  }

  @Test func whitespaceOnlyFieldsDoNotCount() {
    let model = filledModel()
    model.fullName = "   "
    #expect(model.canSubmit == false)
  }

  @Test func cannotSubmitWhileSubmitting() {
    let model = filledModel()
    model.isSubmitting = true
    #expect(model.canSubmit == false)
  }

  @Test func trimmedAddressTrimsAndOmitsEmptyLine2() {
    let model = filledModel()
    model.fullName = "  Jane Doe  "
    model.addressLine2 = "   "
    let address = model.trimmedAddress()
    #expect(address.fullName == "Jane Doe")
    #expect(address.addressLine2 == nil)
    #expect(address.postalCode == "78704")
  }

  @Test func trimmedAddressKeepsNonEmptyLine2AndUppercasesState() {
    let model = filledModel()
    model.addressLine2 = " Apt 4 "
    model.state = "tx"
    let address = model.trimmedAddress()
    #expect(address.addressLine2 == "Apt 4")
    #expect(address.state == "TX")
  }
}
