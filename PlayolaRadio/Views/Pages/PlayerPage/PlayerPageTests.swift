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
import PlayolaPlayer

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
      #expect(model.playolaAudioBlockPlaying == nil)
    }

    @Test("Populates correctly when loading (with progress)")
    @MainActor
    func testPopulatesCorrectlyWhenLoadingWithProgress() {
      let station     = RadioStation.mock
      let playerMock  = StationPlayerMock()
      playerMock.state = StationPlayer.State(
        playbackStatus: .loading(station, 0.42)
      )

      let model = PlayerPageModel(stationPlayer: playerMock)
      model.viewAppeared()

      #expect(model.primaryNavBarTitle   == station.name)
      #expect(model.secondaryNavBarTitle == station.desc)
      #expect(model.nowPlayingText       == "Station Loading...")
      #expect(model.loadingPercentage == 0.42)
      #expect(model.playolaAudioBlockPlaying == nil)
    }

    @Test("Populates correctly when something is playing")
    @MainActor
    func testPopulatesCorrectlyWhenSomethingIsPlaying() {
      let station     = RadioStation.mock
      let playerMock  = StationPlayerMock()
      playerMock.state = StationPlayer.State(
        playbackStatus: .playing(station),
        artistPlaying: "Rachel Loy",
        titlePlaying: "Selfie"
      )

      let model = PlayerPageModel(stationPlayer: playerMock)
      model.viewAppeared()

      #expect(model.nowPlayingText     == "Selfie - Rachel Loy")
      #expect(model.stationArtUrl      == URL(string: station.imageURL))
      #expect(model.playolaAudioBlockPlaying == nil) // No AudioBlock in this test
    }

    @Test("Populates correctly when something is playing with AudioBlock")
    @MainActor
    func testPopulatesCorrectlyWhenSomethingIsPlayingWithAudioBlock() {
      let station     = RadioStation.mock
      let audioBlock  = AudioBlock.mock
      let spin        = Spin.mockWith(audioBlock: audioBlock)
      let playerMock  = StationPlayerMock()
      playerMock.state = StationPlayer.State(
        playbackStatus: .playing(station),
        artistPlaying: "Rachel Loy",
        titlePlaying: "Selfie",
        playolaSpinPlaying: spin
      )

      let model = PlayerPageModel(stationPlayer: playerMock)
      model.viewAppeared()

      #expect(model.nowPlayingText     == "Selfie - Rachel Loy")
      #expect(model.stationArtUrl      == URL(string: station.imageURL))
      #expect(model.playolaAudioBlockPlaying == audioBlock)
    }

    @Test("Populates relatedText prioritizing the AudioBlock's transcript")
    @MainActor
    func testPopulatesRelatedTextPrioritizingTheAudioBlockTranscription() {
      let station     = RadioStation.mock
      let transcription = "This is the transcription"
      let audioBlock  = AudioBlock.mockWith(transcription: transcription)

      let relatedTexts = [
        RelatedText(title: "title1", body: "body1"),
        RelatedText(title: "title2", body: "body2")
      ]
      let spin        = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
      let playerMock  = StationPlayerMock()
      playerMock.state = StationPlayer.State(
        playbackStatus: .playing(station),
        artistPlaying: "Rachel Loy",
        titlePlaying: "Selfie",
        playolaSpinPlaying: spin
      )

      let model = PlayerPageModel(stationPlayer: playerMock)
      model.viewAppeared()

      #expect(model.relatedText?.title  == "Why I chose this song")
      #expect(model.relatedText?.body   == transcription)
      #expect(model.playolaAudioBlockPlaying == audioBlock)
    }

    @Test("Populates relatedText when it exists but transcription does not.")
    @MainActor
    func testPopulatesRelatedTextWhenRelatedTextButNoTranscription() {
      let station     = RadioStation.mock
      let audioBlock  = AudioBlock.mockWith(transcription: nil)

      let relatedTexts = [
        RelatedText(title: "title1", body: "body1"),
        RelatedText(title: "title2", body: "body2")
      ]
      let spin        = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
      let playerMock  = StationPlayerMock()
      playerMock.state = StationPlayer.State(
        playbackStatus: .playing(station),
        artistPlaying: "Rachel Loy",
        titlePlaying: "Selfie",
        playolaSpinPlaying: spin
      )

      let model = PlayerPageModel(stationPlayer: playerMock)
      model.viewAppeared()

      #expect(model.relatedText != nil)
      // randomly picks one.
      #expect(model.relatedText == relatedTexts[0] || model.relatedText == relatedTexts[1])
      #expect(model.playolaAudioBlockPlaying == audioBlock)
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
      #expect(model.playolaAudioBlockPlaying == nil)
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
      #expect(model.playolaAudioBlockPlaying == nil)
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
      #expect(model.playolaAudioBlockPlaying == nil)
    }

    @Test("Populates correctly when starting new station with AudioBlock")
    @MainActor
    func testPopulatesCorrectlyWhenStartingNewStationWithAudioBlock() {
      let station     = RadioStation.mock
      let audioBlock  = AudioBlock.mock
      let spin = Spin.mockWith(audioBlock: audioBlock)
      let playerMock  = StationPlayerMock()
      playerMock.state = StationPlayer.State(
        playbackStatus: .startingNewStation(station),
        playolaSpinPlaying: spin
      )

      let model = PlayerPageModel(stationPlayer: playerMock)
      model.viewAppeared()

      #expect(model.primaryNavBarTitle   == station.name)
      #expect(model.secondaryNavBarTitle == station.desc)
      #expect(model.nowPlayingText       == "")
      #expect(model.playolaAudioBlockPlaying == audioBlock)
    }
  }

  // MARK: - playPauseButtonTapped
  @Suite("playPauseButtonTapped")
  struct PlayPauseButtonTappedTests {

    @Test("Stops the stream when something is playing")
    @MainActor
    func testStopsWhenPlaying() {
      let station = RadioStation.mock
      let spy     = StationPlayerMock()
      spy.state   = StationPlayer.State(
        playbackStatus: .playing(station)
      )

      let model = PlayerPageModel(stationPlayer: spy)
      model.viewAppeared()
      #expect(spy.stopCalledCount == 0)
      model.playPauseButtonTapped()

      #expect(spy.stopCalledCount == 1)
      #expect(spy.callsToPlay.count  == 0)
    }

    @Test("Plays the previously-playing station when stopped")
    @MainActor
    func testPlaysWhenStopped() {
      let station = RadioStation.mock
      let spy     = StationPlayerMock()
      spy.state = StationPlayer.State(
        playbackStatus: .playing(station)
      )
      let model = PlayerPageModel(stationPlayer: spy)
      model.viewAppeared()

      spy.state = StationPlayer.State(
        playbackStatus: .stopped
      )

      model.playPauseButtonTapped()

      #expect(spy.callsToPlay.count == 1)
      #expect(spy.callsToPlay[0]  == station)
      #expect(spy.stopCalledCount == 0)
    }

    @Test("Dismisses the player when stop button is pressed during playback")
    @MainActor
    func testDismissesWhenStopButtonPressed() {
      let station = RadioStation.mock
      let spy     = StationPlayerMock()
      spy.state = StationPlayer.State(
        playbackStatus: .playing(station)
      )

      var dismissCalled = false
      let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })
      model.viewAppeared()

      model.playPauseButtonTapped()

      #expect(spy.stopCalledCount == 1)
      #expect(dismissCalled == true)
    }
  }
}
