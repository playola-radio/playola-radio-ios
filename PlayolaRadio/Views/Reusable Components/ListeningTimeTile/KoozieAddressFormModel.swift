//
//  KoozieAddressFormModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/10/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class KoozieAddressFormModel {
  var fullName: String = ""
  var addressLine1: String = ""
  var addressLine2: String = ""
  var city: String = ""
  var state: String = ""
  var postalCode: String = ""

  var serverError: String?
  var isSubmitting: Bool = false

  // MARK: - Copy

  var title: String { "Where should we send it?" }
  var subtitle: String { "US addresses only. We'll only use this to ship your koozie." }
  var fullNamePlaceholder: String { "Full name" }
  var addressLine1Placeholder: String { "Street address" }
  var addressLine2Placeholder: String { "Apt, suite (optional)" }
  var cityPlaceholder: String { "City" }
  var statePlaceholder: String { "State" }
  var zipPlaceholder: String { "ZIP" }
  var backButtonText: String { "Back" }
  var submitButtonText: String { "Send my koozie" }

  // MARK: - Validation

  private func trimmed(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var isZipValid: Bool {
    trimmed(postalCode).range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) != nil
  }

  private var isStateValid: Bool {
    trimmed(state).range(of: #"^[A-Za-z]{2}$"#, options: .regularExpression) != nil
  }

  var canSubmit: Bool {
    guard !isSubmitting else { return false }
    return !trimmed(fullName).isEmpty && !trimmed(addressLine1).isEmpty && !trimmed(city).isEmpty
      && isStateValid && isZipValid
  }

  /// Trimmed, wire-ready address. `state` is uppercased; empty line 2 becomes nil.
  func trimmedAddress() -> KoozieShippingAddress {
    let line2 = trimmed(addressLine2)
    return KoozieShippingAddress(
      fullName: trimmed(fullName),
      addressLine1: trimmed(addressLine1),
      addressLine2: line2.isEmpty ? nil : line2,
      city: trimmed(city),
      state: trimmed(state).uppercased(),
      postalCode: trimmed(postalCode))
  }
}
