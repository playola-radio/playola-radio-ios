//
//  StationPlayerMock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/16/25.
//

import Foundation
import FRadioPlayer
@testable import PlayolaRadio

class StationPlayerMock: StationPlayer {
  func setNowPlaying(station: RadioStation, artist: String, title: String) {
    self.state = StationPlayer.State(
      playbackState: .playing,
      playerStatus: .readyToPlay,
      currentStation: station,
      nowPlaying: FRadioPlayer.Metadata(
        artistName: artist,
        trackName: title,
        rawValue: nil,
        groups: []))
  }
}
