//
//  PAPSpinPlayer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/20/24.
//

import Foundation
public protocol PAPSpinPlayer {
  func stop()
  func play(from: Double, to: Double?)
  func schedulePlay(at: Date)
  func loadFile(with url: URL)
  func setVolume(_ level: Float)
  var volume: Float { get }
  var duration: Double { get }
}
