//
//  NowPlayingPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/17/25.
//

import FRadioPlayer
@testable import PlayolaRadio
import Testing

@MainActor
struct NowPlayingPageTests {
    @Suite("viewAppeared")
    struct ViewAppearedTests {
        @Test("Populates correctly when loading")
        @MainActor func testNowPlayingPopulatesCorrectlyWhenLoading() {
//      let player = URLStreamPlayerMock()
//
//      player.state = URLStreamPlayer.State(playbackState: .playing, playerStatus: .loading, currentStation: .mock)
            let playerMock = StationPlayerMock()
            playerMock.state = StationPlayer.State(playbackStatus: .loading(.mock))
            let nowPlayingPage = NowPlayingPageModel(stationPlayer: playerMock)
            nowPlayingPage.viewAppeared()
            #expect(nowPlayingPage.navigationBarTitle == "Bri Bagwell's Banned Radio")
            #expect(nowPlayingPage.nowPlayingArtist == "Station Loading...")
            #expect(nowPlayingPage.nowPlayingTitle == "Bri Bagwell's Banned Radio")
        }

        @Test("Populates correctly when something is playing")
        @MainActor func testNowPlayingPopulatesCorrectlyWhenSomethingIsPlaying() {
            let station = RadioStation.mock
            let playerMock = StationPlayerMock()
            playerMock.state = StationPlayer.State(
                playbackStatus: .playing(station),
                artistPlaying: "Rachel Loy",
                titlePlaying: "Selfie"
            )
            let nowPlayingPage = NowPlayingPageModel(stationPlayer: playerMock)
            nowPlayingPage.viewAppeared()
            #expect(nowPlayingPage.navigationBarTitle == "Bri Bagwell's Banned Radio")
            #expect(nowPlayingPage.nowPlayingArtist == "Rachel Loy")
            #expect(nowPlayingPage.nowPlayingTitle == "Selfie")
        }
    }

    @Suite("About Display")
    struct AboutDisplay {
        @Test("Tapping about button displays about as a sheet")
        @MainActor func testTappingAboutButtonDisplaysAboutPageAsSheet() {
            let nowPlayingPage = NowPlayingPageModel()
            #expect(nowPlayingPage.presentedSheet == nil)
            nowPlayingPage.aboutButtonTapped()
            #expect(nowPlayingPage.presentedSheet ~= .about(AboutPageModel()))
        }

        @Test("Can be dismissed")
        @MainActor func testTappingAboutButtonDismissWorks() {
            let nowPlayingPage = NowPlayingPageModel(presentedSheet: .about(AboutPageModel()))
            nowPlayingPage.dismissAboutSheetButtonTapped()
            #expect(nowPlayingPage.presentedSheet == nil)
        }
    }

    @Test("Info Button Tapped")
    func testInfoButtonPushesInfoOntoTheNavigationStack() {}
}
