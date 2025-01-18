//
//  NowPlayingPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/17/25.
//

import Testing
import FRadioPlayer
@testable import PlayolaRadio

struct NowPlayingPageTests {
  @Suite("viewAppeared")
  struct ViewAppearedTests {
    @Test("Populates correctly when loading")
    func testNowPlayingPopulatesCorrectlyWhenLoading() {
      let player = URLStreamPlayerMock()
      player.state = URLStreamPlayer.State(playbackState: .playing, playerStatus: .loading, currentStation: .mock)
      let nowPlayingPage = NowPlayingPageModel(stationPlayer: player)
      nowPlayingPage.viewAppeared()
      #expect(nowPlayingPage.navigationBarTitle == "Bri Bagwell's Banned Radio")
      #expect(nowPlayingPage.nowPlayingArtist == "Station Loading...")
      #expect(nowPlayingPage.nowPlayingTitle == "Bri Bagwell's Banned Radio")
    }

    @Test("Populates correctly when something is playing")
    func testNowPlayingPopulatesCorrectlyWhenSomethingIsPlaying() {
      let player = URLStreamPlayerMock()
      let station = RadioStation.mock
      player.setNowPlaying(station: station, artist: "Rachel Loy", title: "Selfie")

      let nowPlayingPage = NowPlayingPageModel(stationPlayer: player)
      nowPlayingPage.viewAppeared()
      #expect(nowPlayingPage.navigationBarTitle == "Bri Bagwell's Banned Radio")
      #expect(nowPlayingPage.nowPlayingArtist == "Rachel Loy")
      #expect(nowPlayingPage.nowPlayingTitle == "Selfie")
    }
  }

  @Suite("About Display")
  struct AboutDisplay {
    @Test("Tapping about button displays about as a sheet")
    func testTappingAboutButtonDisplaysAboutPageAsSheet() {
      let nowPlayingPage = NowPlayingPageModel()
      #expect(nowPlayingPage.presentedSheet == nil)
      nowPlayingPage.aboutButtonTapped()
      #expect(nowPlayingPage.presentedSheet ~= .about(AboutPageModel()))
    }

    @Test("Can be dismissed")
    func testTappingAboutButtonDismissWorks() {
      let nowPlayingPage = NowPlayingPageModel(presentedSheet: .about(AboutPageModel()))
      nowPlayingPage.dismissAboutSheetButtonTapped()
      #expect(nowPlayingPage.presentedSheet == nil)
    }
  }

  @Test("Airplay Button")
  func testAirplayButtonTappedShowsAirplayStuff() {

  }

  @Test("Info Button Tapped")
  func testInfoButtonPushesInfoOntoTheNavigationStack() {
    
  }

}
