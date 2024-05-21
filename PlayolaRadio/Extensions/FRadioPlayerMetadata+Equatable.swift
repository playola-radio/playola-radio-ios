//
//  FRadioPlayerMetadata+Equatable.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Foundation
import FRadioPlayer

extension FRadioPlayer.Metadata: Equatable {
  public static func == (lhs: FRadioPlayer.Metadata, rhs: FRadioPlayer.Metadata) -> Bool {
    return lhs.artistName == rhs.artistName &&
    lhs.trackName == rhs.trackName
  }
}

extension FRadioPlayer.PlaybackState: @unchecked Sendable {}
extension FRadioPlayer.State: @unchecked Sendable {}
extension FRadioPlayer.Metadata: @unchecked Sendable {}
