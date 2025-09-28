//
//  ViewModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/12/25.
//

@MainActor
class ViewModel: Hashable {
    init() {}

    nonisolated static func == (lhs: ViewModel, rhs: ViewModel) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
