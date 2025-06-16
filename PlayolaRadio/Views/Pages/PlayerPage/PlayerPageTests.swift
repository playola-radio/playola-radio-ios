//
//  PlayerPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/16/25.
//

import FRadioPlayer
@testable import PlayolaRadio
import Testing
import Foundation

@MainActor
struct PlayerPageTests {
  // MARK: - viewAppeared
  @Suite("viewAppeared")
  struct ViewAppearedTests {

    @Test("Populates correctly when loading (no progress)")
    @MainActor
    func testPopulatesCorrectlyWhenLoadingNoProgress() {
      let station     = RadioStation.mock
      let playerMock  = StationPlayerMock()
      playerMock.state = StationPlayer.State(
        playbackStatus: .loading(station) // no progress
      )

      let model = PlayerPageModel(stationPlayer: playerMock)
      model.viewAppeared()

      #expect(model.primaryNavBarTitle   == station.name)
      #expect(model.secondaryNavBarTitle == station.desc)
      #expect(model.nowPlayingText       == "Station Loading...")
    }

    @Test("Populates correctly when loading (with progress)")
    @MainActor
    func testPopulatesCorrectlyWhenLoadingWithProgress() {
      let station     = RadioStation.mock
      let playerMock  = StationPlayerMock()
      playerMock.state = StationPlayer.State(
        playbackStatus: .loading(station, 0.42)   // 42 %
      )

      let model = PlayerPageModel(stationPlayer: playerMock)
      model.viewAppeared()

      #expect(model.primaryNavBarTitle   == station.name)
      #expect(model.secondaryNavBarTitle == station.desc)
      #expect(model.nowPlayingText       == "Station Loading... 42%")
    }

    @Test("Populates correctly when something is playing")
    @MainActor
    func testPopulatesCorrectlyWhenSomethingIsPlaying() {
      let station     = RadioStation.mock
      let playerMock  = StationPlayerMock()
      playerMock.state = StationPlayer.State(
        playbackStatus : .playing(station),
        artistPlaying  : "Rachel Loy",
        titlePlaying   : "Selfie"
      )

      let model = PlayerPageModel(stationPlayer: playerMock)
      model.viewAppeared()

      #expect(model.nowPlayingText     == "Selfie / Rachel Loy")
      #expect(model.stationArtUrl      == URL(string: station.imageURL))
    }

    @Test("Populates correctly when stopped")
    @MainActor
    func testPopulatesCorrectlyWhenStopped() {
      let playerMock  = StationPlayerMock()
      playerMock.state = StationPlayer.State(
        playbackStatus: .stopped
      )

      let model = PlayerPageModel(stationPlayer: playerMock)
      model.viewAppeared()

      #expect(model.nowPlayingText == "")
      #expect(model.albumArtUrl    == nil)
    }

    @Test("Populates correctly when error")
    @MainActor
    func testPopulatesCorrectlyWhenError() {
      let playerMock  = StationPlayerMock()
      playerMock.state = StationPlayer.State(
        playbackStatus: .error
      )

      let model = PlayerPageModel(stationPlayer: playerMock)
      model.viewAppeared()
      
      #expect(model.nowPlayingText       == "Error Playing Station")
      #expect(model.primaryNavBarTitle   == "")
      #expect(model.secondaryNavBarTitle == "")
      #expect(model.albumArtUrl          == nil)
    }

    @Test("Populates correctly when starting new station")
    @MainActor
    func testPopulatesCorrectlyWhenStartingNewStation() {
      let station     = RadioStation.mock
      let playerMock  = StationPlayerMock()
      playerMock.state = StationPlayer.State(
        playbackStatus: .startingNewStation(station)
      )

      let model = PlayerPageModel(stationPlayer: playerMock)
      model.viewAppeared()

      #expect(model.primaryNavBarTitle   == station.name)
      #expect(model.secondaryNavBarTitle == station.desc)
      #expect(model.nowPlayingText       == "")
    }
  }
}
