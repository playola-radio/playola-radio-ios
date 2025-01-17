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
  override func addObserverToPlayer() {}

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

  static func mockPlayingPlayer(artist: String = "Rachel Loy", title: String = "Selfie") -> StationPlayerMock {
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = State(playbackState: .playing,
                                    playerStatus: .readyToPlay,
                                    currentStation: .mock,
                                    nowPlaying: FRadioPlayer.Metadata(
                                      artistName: artist,
                                      trackName: title,
                                      rawValue: nil,
                                      groups: []))
    return stationPlayerMock
  }

  static func mockStoppedPlayer() -> StationPlayerMock {
    let stationPlayerMock = StationPlayerMock()
    stationPlayerMock.state = State(playbackState: .stopped,
                                    playerStatus: .none,
                                    nowPlaying: nil)
    return stationPlayerMock
  }
}
