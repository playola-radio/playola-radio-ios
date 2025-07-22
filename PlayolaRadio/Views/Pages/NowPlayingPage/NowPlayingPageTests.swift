//
//  NowPlayingPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/17/25.
//

import FRadioPlayer
import XCTest

@testable import PlayolaRadio

@MainActor
final class NowPlayingPageTests: XCTestCase {
  // MARK: - viewAppeared Tests

  func testViewAppeared_PopulatesCorrectlyWhenLoading() {
    let mockStation = RadioStation.mock
    let playerMock = StationPlayerMock()
    playerMock.state = StationPlayer.State(playbackStatus: .loading(mockStation))
    let nowPlayingPage = NowPlayingPageModel(stationPlayer: playerMock)
    nowPlayingPage.viewAppeared()

    let expectedTitle = "\(mockStation.name) \(mockStation.desc)"
    XCTAssertEqual(nowPlayingPage.navigationBarTitle, expectedTitle)
    XCTAssertEqual(nowPlayingPage.nowPlayingArtist, "Station Loading...")
    XCTAssertEqual(nowPlayingPage.nowPlayingTitle, expectedTitle)
  }

  func testViewAppeared_PopulatesCorrectlyWhenSomethingIsPlaying() {
    let mockStation = RadioStation.mock
    let testArtist = "Rachel Loy"
    let testTitle = "Selfie"
    let playerMock = StationPlayerMock()
    playerMock.state = StationPlayer.State(
      playbackStatus: .playing(mockStation),
      artistPlaying: testArtist,
      titlePlaying: testTitle
    )
    let nowPlayingPage = NowPlayingPageModel(stationPlayer: playerMock)
    nowPlayingPage.viewAppeared()

    let expectedTitle = "\(mockStation.name) \(mockStation.desc)"
    XCTAssertEqual(nowPlayingPage.navigationBarTitle, expectedTitle)
    XCTAssertEqual(nowPlayingPage.nowPlayingArtist, testArtist)
    XCTAssertEqual(nowPlayingPage.nowPlayingTitle, testTitle)
  }
}
