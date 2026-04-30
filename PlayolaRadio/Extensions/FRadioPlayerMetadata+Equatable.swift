//
//  FRadioPlayerMetadata+Equatable.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import FRadioPlayer
import Foundation

// swift-format-ignore: AvoidRetroactiveConformances
extension FRadioPlayer.Metadata: @retroactive Equatable {
  public static func == (lhs: FRadioPlayer.Metadata, rhs: FRadioPlayer.Metadata) -> Bool {
    lhs.artistName == rhs.artistName && lhs.trackName == rhs.trackName
  }
}

// swift-format-ignore: AvoidRetroactiveConformances
extension FRadioPlayer.PlaybackState: @retroactive @unchecked Sendable {}
// swift-format-ignore: AvoidRetroactiveConformances
extension FRadioPlayer.State: @retroactive @unchecked Sendable {}
// swift-format-ignore: AvoidRetroactiveConformances
extension FRadioPlayer.Metadata: @retroactive @unchecked Sendable {}
