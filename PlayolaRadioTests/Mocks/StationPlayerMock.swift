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
}
