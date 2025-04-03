//
//  ViewModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//

@MainActor
class ViewModel: Hashable {
  @MainActor
  init() {}

  nonisolated static func == (lhs: ViewModel, rhs: ViewModel) -> Bool {
    ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }

  nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
