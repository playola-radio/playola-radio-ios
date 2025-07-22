//
//  PlayerPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/16/25.
//

import FRadioPlayer
import Foundation
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class PlayerPageTests: XCTestCase {
  // MARK: - viewAppeared Tests

  func testViewAppeared_PopulatesCorrectlyWhenLoadingNoProgress() {
    let station = RadioStation.mock
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock {
      $0 = NowPlaying(
        currentStation: station,
        playbackStatus: .loading(station)
      )
    }

    let model = PlayerPageModel(stationPlayer: playerMock)
    model.viewAppeared()

    XCTAssertEqual(model.primaryNavBarTitle, station.name)
    XCTAssertEqual(model.secondaryNavBarTitle, station.desc)
    XCTAssertEqual(model.nowPlayingText, "Station Loading...")
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenLoadingWithProgress() {
    let station = RadioStation.mock
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock {
      $0 = NowPlaying(
        currentStation: station,
        playbackStatus: .loading(station, 0.42)
      )
    }

    let model = PlayerPageModel(stationPlayer: playerMock)
    model.viewAppeared()

    XCTAssertEqual(model.primaryNavBarTitle, station.name)
    XCTAssertEqual(model.secondaryNavBarTitle, station.desc)
    XCTAssertEqual(model.nowPlayingText, "Station Loading...")
    XCTAssertEqual(model.loadingPercentage, 0.42)
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenSomethingIsPlaying() {
    let station = RadioStation.mock
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "Rachel Loy",
        titlePlaying: "Selfie",
        currentStation: station,
        playbackStatus: .playing(station)
      )
    }

    let model = PlayerPageModel(stationPlayer: playerMock)
    model.viewAppeared()

    XCTAssertEqual(model.nowPlayingText, "Selfie - Rachel Loy")
    XCTAssertEqual(model.stationArtUrl, URL(string: station.imageURL))
    XCTAssertNil(model.playolaAudioBlockPlaying)  // No AudioBlock in this test
  }

  func testViewAppeared_PopulatesCorrectlyWhenSomethingIsPlayingWithAudioBlock() {
    let station = RadioStation.mock
    let audioBlock = AudioBlock.mock
    let spin = Spin.mockWith(audioBlock: audioBlock)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "Rachel Loy",
        titlePlaying: "Selfie",
        playolaSpinPlaying: spin,
        currentStation: station,
        playbackStatus: .playing(station)
      )
    }

    let model = PlayerPageModel(stationPlayer: playerMock)
    model.viewAppeared()

    XCTAssertEqual(model.nowPlayingText, "Selfie - Rachel Loy")
    XCTAssertEqual(model.stationArtUrl, URL(string: station.imageURL))
    XCTAssertEqual(model.playolaAudioBlockPlaying, audioBlock)
  }

  func testViewAppeared_PopulatesRelatedTextPrioritizingTheAudioBlockTranscription() {
    let station = RadioStation.mock
    let transcription = "This is the transcription"
    let audioBlock = AudioBlock.mockWith(transcription: transcription)

    let relatedTexts = [
      RelatedText(title: "title1", body: "body1"),
      RelatedText(title: "title2", body: "body2"),
    ]
    let spin = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "Rachel Loy",
        titlePlaying: "Selfie",
        playolaSpinPlaying: spin,
        currentStation: station,
        playbackStatus: .playing(station)
      )
    }

    let model = PlayerPageModel(stationPlayer: playerMock)
    model.viewAppeared()

    XCTAssertEqual(model.relatedText?.title, "Why I chose this song")
    XCTAssertEqual(model.relatedText?.body, transcription)
    XCTAssertEqual(model.playolaAudioBlockPlaying, audioBlock)
  }

  func testViewAppeared_PopulatesRelatedTextWhenRelatedTextButNoTranscription() {
    let station = RadioStation.mock
    let audioBlock = AudioBlock.mockWith(transcription: nil)

    let relatedTexts = [
      RelatedText(title: "title1", body: "body1"),
      RelatedText(title: "title2", body: "body2"),
    ]
    let spin = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock {
      $0 = NowPlaying(
        artistPlaying: "Rachel Loy",
        titlePlaying: "Selfie",
        playolaSpinPlaying: spin,
        currentStation: station,
        playbackStatus: .playing(station)
      )
    }

    let model = PlayerPageModel(stationPlayer: playerMock)
    model.viewAppeared()

    XCTAssertNotNil(model.relatedText)
    // randomly picks one.
    XCTAssertTrue(model.relatedText == relatedTexts[0] || model.relatedText == relatedTexts[1])
    XCTAssertEqual(model.playolaAudioBlockPlaying, audioBlock)
  }

  func testViewAppeared_PopulatesCorrectlyWhenStopped() {
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock {
      $0 = NowPlaying(
        playbackStatus: .stopped
      )
    }

    let model = PlayerPageModel(stationPlayer: playerMock)
    model.viewAppeared()

    XCTAssertEqual(model.nowPlayingText, "")
    XCTAssertNil(model.albumArtUrl)
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenError() {
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock {
      $0 = NowPlaying(
        playbackStatus: .error
      )
    }

    let model = PlayerPageModel(stationPlayer: playerMock)
    model.viewAppeared()

    XCTAssertEqual(model.nowPlayingText, "Error Playing Station")
    XCTAssertEqual(model.primaryNavBarTitle, "")
    XCTAssertEqual(model.secondaryNavBarTitle, "")
    XCTAssertNil(model.albumArtUrl)
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenStartingNewStation() {
    let station = RadioStation.mock
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock {
      $0 = NowPlaying(
        currentStation: station,
        playbackStatus: .startingNewStation(station)
      )
    }

    let model = PlayerPageModel(stationPlayer: playerMock)
    model.viewAppeared()

    XCTAssertEqual(model.primaryNavBarTitle, station.name)
    XCTAssertEqual(model.secondaryNavBarTitle, station.desc)
    XCTAssertEqual(model.nowPlayingText, "")
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenStartingNewStationWithAudioBlock() {
    let station = RadioStation.mock
    let audioBlock = AudioBlock.mock
    let spin = Spin.mockWith(audioBlock: audioBlock)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock {
      $0 = NowPlaying(
        playolaSpinPlaying: spin,
        currentStation: station,
        playbackStatus: .startingNewStation(station)
      )
    }

    let model = PlayerPageModel(stationPlayer: playerMock)
    model.viewAppeared()

    XCTAssertEqual(model.primaryNavBarTitle, station.name)
    XCTAssertEqual(model.secondaryNavBarTitle, station.desc)
    XCTAssertEqual(model.nowPlayingText, "")
    XCTAssertEqual(model.playolaAudioBlockPlaying, audioBlock)
  }

  // MARK: - playPauseButtonTapped Tests

  func testPlayPauseButtonTapped_StopsWhenPlaying() {
    let station = RadioStation.mock
    let spy = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock {
      $0 = NowPlaying(
        currentStation: station,
        playbackStatus: .playing(station)
      )
    }

    let model = PlayerPageModel(stationPlayer: spy)
    model.viewAppeared()
    XCTAssertEqual(spy.stopCalledCount, 0)
    model.playPauseButtonTapped()

    XCTAssertEqual(spy.stopCalledCount, 1)
    XCTAssertEqual(spy.callsToPlay.count, 0)
  }

  func testPlayPauseButtonTapped_DismissesWhenStopButtonPressed() {
    let station = RadioStation.mock
    let spy = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying?
    $nowPlaying.withLock {
      $0 = NowPlaying(
        currentStation: station,
        playbackStatus: .playing(station)
      )
    }

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })
    model.viewAppeared()

    model.playPauseButtonTapped()

    XCTAssertEqual(spy.stopCalledCount, 1)
    XCTAssertTrue(dismissCalled)
  }
}
