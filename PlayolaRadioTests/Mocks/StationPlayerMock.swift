//
//  StationPlayerMock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//
@testable import PlayolaRadio

class StationPlayerMock: StationPlayer {
  var callsToPlay: [RadioStation] = []
  var stopCalledCount = 0
  override init(urlStreamPlayer: URLStreamPlayer? = nil) {
    super.init(urlStreamPlayer: URLStreamPlayerMock())
  }
  public override func play(station: RadioStation) {
    self.callsToPlay.append(station)
  }
  public override func stop() {
    self.stopCalledCount += 1
  }

  public static func mockPlayingPlayer(artist: String = "Rachel Loy", title: String = "Selfie") -> StationPlayerMock {
    let player = StationPlayerMock()
    player.state = StationPlayer.State(
      playbackStatus: .playing(.mock),
      artistPlaying: artist,
      titlePlaying: title)
    return player
  }
  public static func mockStoppedPlayer() -> StationPlayerMock {
    let player = StationPlayerMock()
    player.state = StationPlayer.State(playbackStatus: .stopped)
    return player
  }
}
