//
//  ChoicePickerModel.swift
//  PlayolaRadio
//

import Foundation
import Observation

@MainActor
@Observable
final class ChoicePickerModel: ViewModel, Identifiable {
  enum Outcome: Equatable {
    case selected(String)
    case cleared
    case dismissed
  }

  let title: String
  let options: [String]
  let selectedOption: String?
  let showsSearch: Bool
  let showsNone: Bool
  var searchText = ""

  @ObservationIgnored private let onFinish: (Outcome) -> Void

  nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }

  init(
    title: String,
    options: [String],
    selectedOption: String?,
    showsSearch: Bool,
    showsNone: Bool,
    onFinish: @escaping (Outcome) -> Void
  ) {
    self.title = title
    self.options = options
    self.selectedOption = selectedOption
    self.showsSearch = showsSearch
    self.showsNone = showsNone
    self.onFinish = onFinish
    super.init()
  }

  // MARK: - Copy

  var searchPlaceholder: String { "Search \(options.count) options" }
  var noneTitle: String { "None" }
  var closeAccessibilityLabel: String { "Close" }

  // MARK: - View Helpers

  var filteredOptions: [String] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard showsSearch, !query.isEmpty else { return options }
    return options.filter { $0.localizedCaseInsensitiveContains(query) }
  }

  var isNoneSelected: Bool { selectedOption == nil }

  func isOptionSelected(_ option: String) -> Bool { selectedOption == option }

  // MARK: - User Actions

  func optionTapped(_ option: String) {
    onFinish(.selected(option))
  }

  func noneTapped() {
    onFinish(.cleared)
  }

  func closeTapped() {
    onFinish(.dismissed)
  }
}
