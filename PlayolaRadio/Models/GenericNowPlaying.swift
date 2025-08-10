import FRadioPlayer
//
//  PlayerNowPlaying.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/17/25.
//
import Foundation

public struct GenericNowPlaying {
  public let title: String
  public let artist: String
  public let albumArtUrl: URL? = nil

  public init?(stationPlayerState: URLStreamPlayer.State) {
    guard let nowPlaying = stationPlayerState.nowPlaying else {
      return nil
    }
    artist = nowPlaying.artistName ?? "-------"
    title = nowPlaying.trackName ?? "-------"
  }
}
