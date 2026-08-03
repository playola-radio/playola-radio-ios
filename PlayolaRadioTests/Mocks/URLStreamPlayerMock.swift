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
  var stateAfterSet: URLStreamPlayer.State?
  var shouldHoldPlayResult = false
  private(set) var playCallCount = 0
  private var heldPlayContinuations: [CheckedContinuation<Bool, Never>] = []

  override func addObserverToPlayer() {}

  override func play(station: UrlStation) async -> Bool {
    playCallCount += 1
    guard shouldHoldPlayResult else {
      return await super.play(station: station)
    }
    return await withCheckedContinuation { continuation in
      heldPlayContinuations.append(continuation)
    }
  }

  func resolveHeldPlay(with result: Bool) {
    let continuations = heldPlayContinuations
    heldPlayContinuations = []
    for continuation in continuations {
      continuation.resume(returning: result)
    }
  }

  override func set(station: UrlStation?) {
    guard let stateAfterSet else {
      super.set(station: station)
      return
    }
    Task { @MainActor [weak self] in
      await Task.yield()
      self?.state = stateAfterSet
    }
  }

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
      ))
    return stationPlayerMock
  }

  static func mockStoppedPlayer() -> URLStreamPlayerMock {
    let stationPlayerMock = URLStreamPlayerMock()
    stationPlayerMock.state = State(
      playbackState: .stopped,
      playerStatus: .none,
      nowPlaying: nil)
    return stationPlayerMock
  }
}
