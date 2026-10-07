//
//  AddressFieldModel.swift
//  PlayolaRadio
//

import Foundation
import Observation

@MainActor
@Observable
final class AddressFieldModel: ViewModel {
  static let partLimit = 255

  var fullName: String = "" {
    didSet {
      if fullName.exceeds(utf16Limit: Self.partLimit) {
        fullName = fullName.clamped(toUTF16: Self.partLimit)
      }
    }
  }
  var addressLine1: String = "" {
    didSet {
      if addressLine1.exceeds(utf16Limit: Self.partLimit) {
        addressLine1 = addressLine1.clamped(toUTF16: Self.partLimit)
      }
    }
  }
  var addressLine2: String = "" {
    didSet {
      if addressLine2.exceeds(utf16Limit: Self.partLimit) {
        addressLine2 = addressLine2.clamped(toUTF16: Self.partLimit)
      }
    }
  }
  var city: String = "" {
    didSet {
      if city.exceeds(utf16Limit: Self.partLimit) { city = city.clamped(toUTF16: Self.partLimit) }
    }
  }
  var state: String = "" {
    didSet {
      if state.exceeds(utf16Limit: Self.partLimit) {
        state = state.clamped(toUTF16: Self.partLimit)
      }
    }
  }
  var postalCode: String = "" {
    didSet {
      if postalCode.exceeds(utf16Limit: Self.partLimit) {
        postalCode = postalCode.clamped(toUTF16: Self.partLimit)
      }
    }
  }

  var statePicker: ChoicePickerModel?

  init(prefill: ShippingAddress?) {
    super.init()
    guard let prefill else { return }
    fullName = prefill.fullName
    addressLine1 = prefill.addressLine1
    addressLine2 = prefill.addressLine2 ?? ""
    city = prefill.city
    state = prefill.state
    postalCode = prefill.postalCode
  }

  // MARK: - Copy

  var captionText: String { "United States only" }
  var fullNamePlaceholder: String { "Full name" }
  var addressLine1Placeholder: String { "Street address" }
  var addressLine2Placeholder: String { "Apt, suite (optional)" }
  var cityPlaceholder: String { "City" }
  var statePlaceholder: String { "State" }
  var zipPlaceholder: String { "ZIP" }

  var stateValueText: String { isStatePlaceholder ? statePlaceholder : state }
  var isStatePlaceholder: Bool { trimmed(state).isEmpty }

  func stateRowTapped() {
    statePicker = ChoicePickerModel(
      title: statePlaceholder,
      options: USStateCodes.all,
      selectedOption: isStatePlaceholder ? nil : state,
      showsSearch: true,
      showsNone: false,
      onFinish: { [weak self] outcome in
        if case .selected(let code) = outcome { self?.state = code }
        self?.statePicker = nil
      })
  }

  // MARK: - Validation

  private func trimmed(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var isZipValid: Bool {
    trimmed(postalCode).range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) != nil
  }

  private var isStateValid: Bool {
    USStateCodes.all.contains(trimmed(state).uppercased())
  }

  var isBlank: Bool {
    [fullName, addressLine1, addressLine2, city, state, postalCode].allSatisfy {
      trimmed($0).isEmpty
    }
  }

  var hasMalformedZip: Bool {
    !trimmed(postalCode).isEmpty && !isZipValid
  }

  var missingParts: [String] {
    var parts: [String] = []
    if trimmed(fullName).isEmpty { parts.append("name") }
    if trimmed(addressLine1).isEmpty { parts.append("street address") }
    if trimmed(city).isEmpty { parts.append("city") }
    if !isStateValid { parts.append("state") }
    if trimmed(postalCode).isEmpty { parts.append("ZIP") }
    return parts
  }

  var isComplete: Bool {
    missingParts.isEmpty && !hasMalformedZip
  }

  /// Trimmed, wire-ready address. `state` is uppercased; empty line 2 becomes nil.
  func answer() -> ShippingAddress {
    let line2 = trimmed(addressLine2)
    return ShippingAddress(
      fullName: trimmed(fullName),
      addressLine1: trimmed(addressLine1),
      addressLine2: line2.isEmpty ? nil : line2,
      city: trimmed(city),
      state: trimmed(state).uppercased(),
      postalCode: trimmed(postalCode))
  }
}
