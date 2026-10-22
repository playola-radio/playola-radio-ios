//
//  AudioBlock+Identifiable.swift
//  PlayolaRadio
//

import PlayolaPlayer

// AudioBlock already exposes a stable `id: String`; the SDK just never declared the conformance.
// Declaring it app-side lets AudioBlock collections use IdentifiedArrayOf and SwiftUI list identity.
// swift-format-ignore: AvoidRetroactiveConformances
extension AudioBlock: @retroactive Identifiable {}
