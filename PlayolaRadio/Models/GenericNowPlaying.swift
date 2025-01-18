//
//  PlayerNowPlaying.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/17/25.
//
import Foundation
import FRadioPlayer

public struct GenericNowPlaying {
  let title: String
  let artist: String
  let albumArtUrl: URL? = nil

  init?(stationPlayerState: URLStreamPlayer.State) {
    guard let nowPlaying = stationPlayerState.nowPlaying else {
      return nil
    }
    self.artist = nowPlaying.artistName ?? "-------"
    self.title = nowPlaying.trackName ?? "-------"
  }
}
