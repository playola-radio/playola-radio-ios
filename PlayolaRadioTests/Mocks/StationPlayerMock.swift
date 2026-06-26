//
//  StationPlayerMock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//
import PlayolaPlayer

@testable import PlayolaRadio

class StationPlayerMock: StationPlayer {
  var callsToPlay: [AnyStation] = []
  var stopCalledCount = 0
  override init(
    urlStreamPlayer: URLStreamPlayer? = nil,
    playolaStationPlayer: (any PlayolaTransport)? = nil,
    audioSessionCoordinator: AudioSessionCoordinator? = nil
  ) {
    super.init(
      urlStreamPlayer: urlStreamPlayer ?? URLStreamPlayerMock(),
      playolaStationPlayer: playolaStationPlayer,
      audioSessionCoordinator: audioSessionCoordinator)
  }

  override public func play(station: AnyStation) async {
    callsToPlay.append(station)
  }

  override public func stop() {
    stopCalledCount += 1
  }

  public static func mockPlayingPlayer(artist: String = "Rachel Loy", title: String = "Selfie")
    -> StationPlayerMock
  {
    let player = StationPlayerMock()
    player.state = StationPlayer.State(
      playbackStatus: .playing(.mock),
      artistPlaying: artist,
      titlePlaying: title
    )
    return player
  }

  public static func mockStoppedPlayer() -> StationPlayerMock {
    let player = StationPlayerMock()
    player.state = StationPlayer.State(playbackStatus: .stopped)
    return player
  }
}
