//
//  PAPSpin.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/19/24.
//

import Foundation

public struct PAPSpin {
  var fadeOutTimer: Timer?
  var audioFileURL: URL!
  var player: PlayolaStationPlayer!
  var playerSet: Bool = false
  var beginFadeOutTime: Date
  var startTime: Date
  var spinInfo: [String: Any]

  init(audioFileURL: URL, player: PlayolaStationPlayer!, startTime: Date, beginFadeOutTime: Date, spinInfo: [String: Any] = [:]) {
    self.audioFileURL = audioFileURL
    self.player = player
    self.startTime = startTime
    self.beginFadeOutTime = beginFadeOutTime
    self.spinInfo = spinInfo
    self.loadPlayer()
  }

  func loadPlayer() {
    self.player.loadFile(with: self.audioFileURL)
  }

  func isPlaying() -> Bool {
    return (Date().isAfter(self.startTime) && Date().isBefore(self.beginFadeOutTime))
  }
}
