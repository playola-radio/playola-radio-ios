//
//  PlayerPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/16/25.
//

import Dependencies
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
    let station = AnyStation.mock
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .loading(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.primaryNavBarTitle, station.name)
    if station.isPlayolaStation {
      XCTAssertEqual(model.secondaryNavBarTitle, station.stationName)
    } else {
      XCTAssertEqual(model.secondaryNavBarTitle, station.location ?? "")
    }
    XCTAssertEqual(model.nowPlayingText, "Station Loading...")
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenLoadingWithProgress() {
    let station = AnyStation.mock
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .loading(station, 0.42))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.primaryNavBarTitle, station.name)
    if station.isPlayolaStation {
      XCTAssertEqual(model.secondaryNavBarTitle, station.stationName)
    } else {
      XCTAssertEqual(model.secondaryNavBarTitle, station.location ?? "")
    }
    XCTAssertEqual(model.nowPlayingText, "Station Loading...")
    XCTAssertEqual(model.loadingPercentage, 0.42)
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenSomethingIsPlaying() {
    let station = AnyStation.mock
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      artistPlaying: "Rachel Loy", titlePlaying: "Selfie", station: station)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.nowPlayingText, "Selfie - Rachel Loy")
    XCTAssertEqual(model.stationArtUrl, station.imageUrl)
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenSomethingIsPlayingWithAudioBlock() {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(title: "Selfie", artist: "Rachel Loy", type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      artistPlaying: "Rachel Loy", titlePlaying: "Selfie", spin: spin, station: station)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.nowPlayingText, "Selfie - Rachel Loy")
    XCTAssertEqual(model.stationArtUrl, station.imageUrl)
    XCTAssertEqual(model.playolaAudioBlockPlaying, audioBlock)
  }

  func testViewAppeared_PopulatesRelatedTextPrioritizingTheAudioBlockTranscription() {
    let transcription = "This is the transcription"
    let audioBlock = AudioBlock.mockWith(type: "song", transcription: transcription)
    let relatedTexts = [
      RelatedText(title: "title1", body: "body1"),
      RelatedText(title: "title2", body: "body2"),
    ]
    let spin = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.relatedText?.title, "Why I chose this song")
    XCTAssertEqual(model.relatedText?.body, transcription)
    XCTAssertEqual(model.playolaAudioBlockPlaying, audioBlock)
  }

  func testViewAppeared_PopulatesRelatedTextWhenRelatedTextButNoTranscription() {
    let audioBlock = AudioBlock.mockWith(type: "song", transcription: nil)
    let relatedTexts = [
      RelatedText(title: "title1", body: "body1"),
      RelatedText(title: "title2", body: "body2"),
    ]
    let spin = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertNotNil(model.relatedText)
    XCTAssertTrue(model.relatedText == relatedTexts[0] || model.relatedText == relatedTexts[1])
    XCTAssertEqual(model.playolaAudioBlockPlaying, audioBlock)
  }

  func testViewAppeared_PopulatesCorrectlyWhenStopped() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: nil, status: .stopped)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.nowPlayingText, "")
    XCTAssertNil(model.albumArtUrl)
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenError() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: nil, status: .error)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.nowPlayingText, "Error Playing Station")
    XCTAssertEqual(model.primaryNavBarTitle, "")
    XCTAssertEqual(model.secondaryNavBarTitle, "")
    XCTAssertNil(model.albumArtUrl)
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenStartingNewStation() {
    let station = AnyStation.mock
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .startingNewStation(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.primaryNavBarTitle, station.name)
    if station.isPlayolaStation {
      XCTAssertEqual(model.secondaryNavBarTitle, station.stationName)
    } else {
      XCTAssertEqual(model.secondaryNavBarTitle, station.location ?? "")
    }
    XCTAssertEqual(model.nowPlayingText, "Station Loading...")
    XCTAssertEqual(model.loadingPercentage, 0.0)
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenStartingNewStationWithAudioBlock() {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      spin: spin, station: station, status: .startingNewStation(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.primaryNavBarTitle, station.name)
    if station.isPlayolaStation {
      XCTAssertEqual(model.secondaryNavBarTitle, station.stationName)
    } else {
      XCTAssertEqual(model.secondaryNavBarTitle, station.location ?? "")
    }
    XCTAssertEqual(model.nowPlayingText, "Station Loading...")
    XCTAssertEqual(model.loadingPercentage, 0.0)
    XCTAssertEqual(model.playolaAudioBlockPlaying, audioBlock)
  }

  func testRelatedText_ReturnsConsistentValueForSameSpin() {
    let audioBlock = AudioBlock.mockWith(type: "song", transcription: nil)
    let relatedTexts = [
      RelatedText(title: "title1", body: "body1"),
      RelatedText(title: "title2", body: "body2"),
    ]
    let spin = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    let firstResult = model.relatedText
    XCTAssertNotNil(firstResult)
    XCTAssertEqual(firstResult, model.relatedText)
    XCTAssertEqual(firstResult, model.relatedText)
  }

  // MARK: - playPauseButtonTapped Tests

  func testPlayPauseButtonTapped_StopsWhenPlaying() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith()
    let spy = StationPlayerMock()
    let model = PlayerPageModel(stationPlayer: spy)

    model.playPauseButtonTapped()

    XCTAssertEqual(spy.stopCalledCount, 1)
    XCTAssertEqual(spy.callsToPlay.count, 0)
  }

  func testPlayPauseButtonTapped_DismissesWhenStopButtonPressed() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith()
    let spy = StationPlayerMock()
    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.playPauseButtonTapped()

    XCTAssertEqual(spy.stopCalledCount, 1)
    XCTAssertTrue(dismissCalled)
  }

  // MARK: - scenePhaseChanged Tests

  func testScenePhaseChanged_DismissesWhenActiveAndPlayerStopped() {
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .stopped)

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .active)

    XCTAssertTrue(dismissCalled)
  }

  func testScenePhaseChanged_DismissesWhenActiveAndPlayerError() {
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .error)

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .active)

    XCTAssertTrue(dismissCalled)
  }

  func testScenePhaseChanged_DoesNotDismissWhenActiveAndPlayerPlaying() {
    let station = AnyStation.mock
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .playing(station))

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .active)

    XCTAssertFalse(dismissCalled)
  }

  func testScenePhaseChanged_DoesNotDismissWhenActiveAndPlayerLoading() {
    let station = AnyStation.mock
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .loading(station))

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .active)

    XCTAssertFalse(dismissCalled)
  }

  func testScenePhaseChanged_DoesNotDismissWhenActiveAndPlayerStartingNewStation() {
    let station = AnyStation.mock
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .startingNewStation(station))

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .active)

    XCTAssertFalse(dismissCalled)
  }

  func testScenePhaseChanged_DoesNotDismissWhenBackgroundPhase() {
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .stopped)

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .background)

    XCTAssertFalse(dismissCalled)
  }

  func testScenePhaseChanged_DoesNotDismissWhenInactivePhase() {
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .stopped)

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .inactive)

    XCTAssertFalse(dismissCalled)
  }

  // MARK: - Heart State Tests

  func testHeartState_HiddenWhenNotPlayingPlayolaSong() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith()  // No spin
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.heartState, .hidden)
    XCTAssertEqual(model.heartState.imageName, "")
    XCTAssertEqual(model.heartState.imageColorHex, "")
  }

  func testHeartState_EmptyWhenPlayingUnlikedSong() async {
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())

      XCTAssertEqual(model.heartState, .empty)
      XCTAssertEqual(model.heartState.imageName, "heart")
      XCTAssertEqual(model.heartState.imageColorHex, "#BABABA")
    }
  }

  func testHeartState_FilledWhenPlayingLikedSong() async {
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      let likesManager = LikesManager()
      likesManager.like(audioBlock)
      $0.likesManager = likesManager
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())

      XCTAssertEqual(model.heartState, .filled)
      XCTAssertEqual(model.heartState.imageName, "heart.fill")
      XCTAssertEqual(model.heartState.imageColorHex, "#EF6962")
    }
  }

  // MARK: - Heart Button Tap Tests

  func testHeartButtonTapped_DoesNothingWhenNoAudioBlock() async {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith()  // No spin

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())
      model.heartButtonTapped()
      XCTAssertEqual(model.likesManager.allLikedAudioBlocks.count, 0)
    }
  }

  func testHeartButtonTapped_LikesUnlikedSong() async {
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())

      XCTAssertEqual(model.heartState, .empty)
      model.heartButtonTapped()

      XCTAssertEqual(model.heartState, .filled)
      XCTAssertTrue(model.likesManager.isLiked(audioBlock.id))
      XCTAssertEqual(model.likesManager.allLikedAudioBlocks.count, 1)
    }
  }

  func testHeartButtonTapped_UnlikesLikedSong() async {
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      let likesManager = LikesManager()
      likesManager.like(audioBlock)
      $0.likesManager = likesManager
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())

      XCTAssertEqual(model.heartState, .filled)
      model.heartButtonTapped()

      XCTAssertEqual(model.heartState, .empty)
      XCTAssertFalse(model.likesManager.isLiked(audioBlock.id))
      XCTAssertEqual(model.likesManager.allLikedAudioBlocks.count, 0)
    }
  }

  func testHeartButtonTapped_CreatesPendingOperation() async {
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())
      model.heartButtonTapped()

      XCTAssertEqual(model.likesManager.pendingOperations.count, 1)
      XCTAssertEqual(model.likesManager.pendingOperations.first?.type, .like)
      XCTAssertEqual(model.likesManager.pendingOperations.first?.audioBlock.id, audioBlock.id)
    }
  }

  // MARK: - Button Visibility Tests (Type-based)

  func testHeartState_HiddenWhenPlayingNonSongAudioBlock() async {
    let commercialBlock = AudioBlock.mockWith(type: "commercial")
    let spin = Spin.mockWith(audioBlock: commercialBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())

      XCTAssertEqual(model.heartState, .hidden)
      XCTAssertEqual(model.heartState.imageName, "")
      XCTAssertEqual(model.heartState.imageColorHex, "")
    }
  }

  func testHeartState_VisibleWhenPlayingSongAudioBlock() async {
    let songBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: songBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())

      XCTAssertEqual(model.heartState, .empty)
      XCTAssertEqual(model.heartState.imageName, "heart")
      XCTAssertEqual(model.heartState.imageColorHex, "#BABABA")
    }
  }

  func testHeartButtonTapped_DoesNothingWhenPlayingNonSongAudioBlock() async {
    let commercialBlock = AudioBlock.mockWith(type: "commercial")
    let spin = Spin.mockWith(audioBlock: commercialBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())
      model.heartButtonTapped()

      XCTAssertEqual(model.likesManager.allLikedAudioBlocks.count, 0)
      XCTAssertEqual(model.likesManager.pendingOperations.count, 0)
    }
  }

  // MARK: - Navigation Bar Title Tests

  func testNavBarTitles_PlayolaStationLoading() {
    let station = AnyStation.mockPlayola(name: "Test Radio Show", curatorName: "Test Curator")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .loading(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.primaryNavBarTitle, "Test Curator")
    XCTAssertEqual(model.secondaryNavBarTitle, "Test Radio Show")
  }

  func testNavBarTitles_PlayolaStationStartingNewStation() {
    let station = AnyStation.mockPlayola(name: "Another Radio Show", curatorName: "Another Curator")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .startingNewStation(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.primaryNavBarTitle, "Another Curator")
    XCTAssertEqual(model.secondaryNavBarTitle, "Another Radio Show")
  }

  func testNavBarTitles_UrlStationLoading() {
    let station = AnyStation.mockUrl(name: "Test FM", location: "Test City, TX")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .loading(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.primaryNavBarTitle, "Test FM")
    XCTAssertEqual(model.secondaryNavBarTitle, "Test City, TX")
  }

  func testNavBarTitles_UrlStationStartingNewStation() {
    let station = AnyStation.mockUrl(name: "Another FM", location: "Another City, CA")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .startingNewStation(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.primaryNavBarTitle, "Another FM")
    XCTAssertEqual(model.secondaryNavBarTitle, "Another City, CA")
  }

  func testNavBarTitles_UrlStationWithoutLocation() {
    let station = AnyStation.mockUrl(name: "No Location FM", location: "")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .loading(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.primaryNavBarTitle, "No Location FM")
    XCTAssertEqual(model.secondaryNavBarTitle, "")
  }

  func testNavBarTitles_WhenPlaying() {
    let station = AnyStation.mock
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: station)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.primaryNavBarTitle, station.name)
    if station.isPlayolaStation {
      XCTAssertEqual(model.secondaryNavBarTitle, station.stationName)
    } else {
      XCTAssertEqual(model.secondaryNavBarTitle, station.location ?? "")
    }
  }

  func testNavBarTitles_EmptyWhenStopped() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: nil, status: .stopped)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.primaryNavBarTitle, "")
    XCTAssertEqual(model.secondaryNavBarTitle, "")
  }

  // MARK: - Now Playing Text Tests

  func testNowPlayingTextShowsPlayolaPaysForCommercial() {
    let commercialBlock = AudioBlock.mockWith(type: "commercial")
    let spin = Spin.mockWith(audioBlock: commercialBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.nowPlayingText, "Playola Pays")
  }

  func testNowPlayingTextShowsTitleArtistForSong() {
    let songBlock = AudioBlock.mockWith(title: "Test Song", artist: "Test Artist", type: "song")
    let spin = Spin.mockWith(audioBlock: songBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.nowPlayingText, "Test Song - Test Artist")
  }

  func testNowPlayingTextShowsTitleArtistForSongEvenWithAiring() {
    let songBlock = AudioBlock.mockWith(
      title: "Airing Song",
      artist: "Airing Artist",
      type: "song"
    )
    let airing = Airing.mockWith(
      episode: Episode.mockWith(title: "Episode Title")
    )
    let spin = Spin.mockWith(audioBlock: songBlock, airing: airing)

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.nowPlayingText, "Airing Song - Airing Artist")
  }

  func testNowPlayingTextShowsEpisodeTitleForNonSongWithAiring() {
    let voiceTrackBlock = AudioBlock.mockWith(type: "voicetrack")
    let airing = Airing.mockWith(
      episode: Episode.mockWith(title: "My Cool Episode")
    )
    let spin = Spin.mockWith(audioBlock: voiceTrackBlock, airing: airing)

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.nowPlayingText, "My Cool Episode")
  }

  func testNowPlayingTextShowsStationNameForNonSongWithoutAiring() {
    let station = AnyStation.mockPlayola(name: "Test Station Name")
    let voiceTrackBlock = AudioBlock.mockWith(type: "voicetrack")
    let spin = Spin.mockWith(audioBlock: voiceTrackBlock, airing: nil)

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin, station: station)

    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    XCTAssertEqual(model.nowPlayingText, "Test Station Name")
  }

  // MARK: - Ask Question Tests

  func testCanAskQuestionTrueForPlayolaStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: .mockPlayola())
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())
    XCTAssertTrue(model.canAskQuestion)
  }

  func testCanAskQuestionFalseForUrlStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: .mockUrl())
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())
    XCTAssertFalse(model.canAskQuestion)
  }

  func testCanAskQuestionFalseWhenNoStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: nil, status: .stopped)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())
    XCTAssertFalse(model.canAskQuestion)
  }

  func testCurrentPlayolaStationReturnsStationForPlayolaStation() {
    let station = AnyStation.mockPlayola(id: "test-id", curatorName: "Test Curator")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: station)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())
    XCTAssertEqual(model.currentPlayolaStation?.id, "test-id")
    XCTAssertEqual(model.currentPlayolaStation?.curatorName, "Test Curator")
  }

  func testCurrentPlayolaStationReturnsNilForUrlStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: .mockUrl())
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())
    XCTAssertNil(model.currentPlayolaStation)
  }

  func testAskQuestionButtonTappedNavigatesToAskQuestionPageAndDismisses() {
    let station = AnyStation.mockPlayola(id: "test-id", curatorName: "Test Curator")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: station)
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    var dismissCalled = false
    let model = PlayerPageModel(
      stationPlayer: StationPlayerMock(), onDismiss: { dismissCalled = true })

    model.askQuestionButtonTapped()

    XCTAssertEqual(navCoordinator.path.count, 1)
    if case .askQuestionPage(let askModel) = navCoordinator.path.first {
      XCTAssertEqual(askModel.station.id, "test-id")
      XCTAssertEqual(askModel.curatorName, "Test Curator")
    } else {
      XCTFail("Expected askQuestionPage in navigation path")
    }
    XCTAssertTrue(dismissCalled)
  }

  func testAskQuestionButtonTappedDoesNothingForUrlStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: .mockUrl())
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    let model = PlayerPageModel(stationPlayer: StationPlayerMock())
    model.askQuestionButtonTapped()

    XCTAssertTrue(navCoordinator.path.isEmpty)
  }
}
