//
//  ClaimFieldModel.swift
//  PlayolaRadio
//

import Foundation
import Observation

extension String {
  func exceeds(utf16Limit limit: Int) -> Bool { utf16.count > limit }

  /// Cuts to at most `limit` UTF-16 units, never splitting a Character.
  func clamped(toUTF16 limit: Int) -> String {
    guard exceeds(utf16Limit: limit) else { return self }
    var result = ""
    var used = 0
    for character in self {
      let width = character.utf16.count
      if used + width > limit { break }
      result.append(character)
      used += width
    }
    return result
  }
}

enum ChoicePresentation: Equatable, Sendable {
  case chips
  case inlineList
  case picker

  static func forOptions(_ options: [String]) -> ChoicePresentation {
    if (2...5).contains(options.count) && options.allSatisfy({ $0.count <= 4 }) { return .chips }
    if options.count <= 6 { return .inlineList }
    return .picker
  }
}

@MainActor
@Observable
final class ClaimFieldModel: ViewModel, Identifiable {
  enum Kind: Equatable {
    case text(multiLine: Bool)
    case choice(ChoicePresentation)
    case address
  }

  static let shortTextLimit = 255
  static let multiLineTextLimit = 5000
  static let pickerSearchThreshold = 12

  let field: InfoField
  let kind: Kind
  let address: AddressFieldModel
  var selectedOption: String?
  var picker: ChoicePickerModel?
  var text: String = "" {
    didSet { if text.exceeds(utf16Limit: textLimit) { text = text.clamped(toUTF16: textLimit) } }
  }

  nonisolated var id: String { field.key }

  init(field: InfoField, prefill: InfoAnswer?) {
    self.field = field
    switch field.type {
    case .multiLineText: kind = .text(multiLine: true)
    case .singleChoice: kind = .choice(.forOptions(field.options))
    case .address: kind = .address
    case .shortText, .unknown: kind = .text(multiLine: false)
    }
    var prefilledAddress: ShippingAddress?
    if case .address(let value) = prefill { prefilledAddress = value }
    address = AddressFieldModel(prefill: prefilledAddress)
    super.init()
    if case .text(let value) = prefill {
      switch kind {
      case .text: text = value
      case .choice: selectedOption = field.options.contains(value) ? value : nil
      case .address: break
      }
    }
  }

  private var textLimit: Int {
    kind == .text(multiLine: true) ? Self.multiLineTextLimit : Self.shortTextLimit
  }

  private var trimmedText: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var label: String { field.label }

  // MARK: - Choice

  func isOptionSelected(_ option: String) -> Bool { selectedOption == option }

  var pickerShowsSearch: Bool { field.options.count > Self.pickerSearchThreshold }
  var pickerShowsNone: Bool { !field.required }

  var pickerPlaceholder: String { "Choose one" }
  var pickerValueText: String { selectedOption ?? pickerPlaceholder }
  var isPickerValuePlaceholder: Bool { selectedOption == nil }

  func pickerRowTapped() {
    picker = ChoicePickerModel(
      title: label,
      options: field.options,
      selectedOption: selectedOption,
      showsSearch: pickerShowsSearch,
      showsNone: pickerShowsNone,
      onFinish: { [weak self] outcome in
        switch outcome {
        case .selected(let option): self?.selectedOption = option
        case .cleared: self?.selectedOption = nil
        case .dismissed: break
        }
        self?.picker = nil
      })
  }

  func optionTapped(_ option: String) {
    if selectedOption == option && !field.required {
      selectedOption = nil
    } else {
      selectedOption = option
    }
  }

  // MARK: - Validation

  private var omitsBlankAddress: Bool {
    !field.required && address.isBlank
  }

  var missingParts: [String] {
    switch kind {
    case .text:
      return field.required && trimmedText.isEmpty ? [field.label.lowercased()] : []
    case .choice:
      return field.required && selectedOption == nil ? [field.label.lowercased()] : []
    case .address:
      return omitsBlankAddress ? [] : address.missingParts
    }
  }

  var hasMalformedZip: Bool {
    kind == .address && address.hasMalformedZip
  }

  var answer: InfoAnswer? {
    switch kind {
    case .text:
      return trimmedText.isEmpty ? nil : .text(trimmedText)
    case .choice:
      return selectedOption.map { .text($0) }
    case .address:
      return address.isBlank ? nil : .address(address.answer())
    }
  }
}
