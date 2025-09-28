//
//  URLStreamPlayerMock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/16/25.
//

import FRadioPlayer
import Foundation

@testable import PlayolaRadio

class URLStreamPlayerMock: URLStreamPlayer {
  override func addObserverToPlayer() {}

  func setNowPlaying(station: UrlStation, artist: String, title: String) {
    state = URLStreamPlayer.State(
      playbackState: .playing,
      playerStatus: .loadingFinished,
      currentStation: station,
      nowPlaying: FRadioPlayer.Metadata(
        artistName: artist,
        trackName: title,
        rawValue: nil,
        groups: []
      )
    )
  }

  static func mockPlayingPlayer(artist: String = "Rachel Loy", title: String = "Selfie")
    -> URLStreamPlayerMock
  {
    let stationPlayerMock = URLStreamPlayerMock()
    stationPlayerMock.state = State(
      playbackState: .playing,
      playerStatus: .readyToPlay,
      currentStation: .mock,
      nowPlaying: FRadioPlayer.Metadata(
        artistName: artist,
        trackName: title,
        rawValue: nil,
        groups: []
      )
    )
    return stationPlayerMock
  }

  static func mockStoppedPlayer() -> URLStreamPlayerMock {
    let stationPlayerMock = URLStreamPlayerMock()
    stationPlayerMock.state = State(
      playbackState: .stopped,
      playerStatus: .none,
      nowPlaying: nil
    )
    return stationPlayerMock
  }
}
