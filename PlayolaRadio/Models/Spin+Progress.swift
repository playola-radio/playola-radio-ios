//
//  Spin+Progress.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/26.
//

import Foundation
import PlayolaPlayer

extension Spin {
  /// Playback progress of this spin at the given moment, clamped to `0...1`.
  ///
  /// Duration is derived from the SDK's `endtime` (airtime plus the audio
  /// block's end-of-message duration), so this matches how the player itself
  /// decides when a spin has finished.
  func progress(at now: Date) -> Double {
    let elapsed = now.timeIntervalSince(airtime)
    let duration = endtime.timeIntervalSince(airtime)
    guard duration > 0 else { return 0 }
    return min(max(elapsed / duration, 0), 1)
  }
}
