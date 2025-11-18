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
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      currentStation: station,
      playbackStatus: .loading(station)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

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
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      currentStation: station,
      playbackStatus: .loading(station, 0.42)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

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
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      currentStation: station,
      playbackStatus: .playing(station)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.nowPlayingText, "Selfie - Rachel Loy")
    XCTAssertEqual(model.stationArtUrl, station.imageUrl)
    XCTAssertNil(model.playolaAudioBlockPlaying)  // No AudioBlock in this test
  }

  func testViewAppeared_PopulatesCorrectlyWhenSomethingIsPlayingWithAudioBlock() {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .playing(station)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.nowPlayingText, "Selfie - Rachel Loy")
    XCTAssertEqual(model.stationArtUrl, station.imageUrl)
    XCTAssertEqual(model.playolaAudioBlockPlaying, audioBlock)
  }

  func testViewAppeared_PopulatesRelatedTextPrioritizingTheAudioBlockTranscription() {
    let station = AnyStation.mock
    let transcription = "This is the transcription"
    let audioBlock = AudioBlock.mockWith(type: "song", transcription: transcription)

    let relatedTexts = [
      RelatedText(title: "title1", body: "body1"),
      RelatedText(title: "title2", body: "body2"),
    ]
    let spin = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .playing(station)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.relatedText?.title, "Why I chose this song")
    XCTAssertEqual(model.relatedText?.body, transcription)
    XCTAssertEqual(model.playolaAudioBlockPlaying, audioBlock)
  }

  func testViewAppeared_PopulatesRelatedTextWhenRelatedTextButNoTranscription() {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(type: "song", transcription: nil)

    let relatedTexts = [
      RelatedText(title: "title1", body: "body1"),
      RelatedText(title: "title2", body: "body2"),
    ]
    let spin = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .playing(station)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertNotNil(model.relatedText)
    // randomly picks one.
    XCTAssertTrue(model.relatedText == relatedTexts[0] || model.relatedText == relatedTexts[1])
    XCTAssertEqual(model.playolaAudioBlockPlaying, audioBlock)
  }

  func testViewAppeared_PopulatesCorrectlyWhenStopped() {
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      playbackStatus: .stopped
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.nowPlayingText, "")
    XCTAssertNil(model.albumArtUrl)
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenError() {
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      playbackStatus: .error
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.nowPlayingText, "Error Playing Station")
    XCTAssertEqual(model.primaryNavBarTitle, "")
    XCTAssertEqual(model.secondaryNavBarTitle, "")
    XCTAssertNil(model.albumArtUrl)
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenStartingNewStation() {
    let station = AnyStation.mock
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      currentStation: station,
      playbackStatus: .startingNewStation(station)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.primaryNavBarTitle, station.name)
    if station.isPlayolaStation {
      XCTAssertEqual(model.secondaryNavBarTitle, station.stationName)
    } else {
      XCTAssertEqual(model.secondaryNavBarTitle, station.location ?? "")
    }
    XCTAssertEqual(model.nowPlayingText, "Station Loading...")
    XCTAssertEqual(model.loadingPercentage, 0.0)  // Just starting, 0% loaded
    XCTAssertNil(model.playolaAudioBlockPlaying)
  }

  func testViewAppeared_PopulatesCorrectlyWhenStartingNewStationWithAudioBlock() {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .startingNewStation(station)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.primaryNavBarTitle, station.name)
    if station.isPlayolaStation {
      XCTAssertEqual(model.secondaryNavBarTitle, station.stationName)
    } else {
      XCTAssertEqual(model.secondaryNavBarTitle, station.location ?? "")
    }
    XCTAssertEqual(model.nowPlayingText, "Station Loading...")
    XCTAssertEqual(model.loadingPercentage, 0.0)  // Just starting, 0% loaded
    XCTAssertEqual(model.playolaAudioBlockPlaying, audioBlock)
  }

  func testRelatedText_ReturnsConsistentValueForSameSpin() {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(type: "song", transcription: nil)

    let relatedTexts = [
      RelatedText(title: "title1", body: "body1"),
      RelatedText(title: "title2", body: "body2"),
    ]
    let spin = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .playing(station)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    // Get the first relatedText result
    let firstResult = model.relatedText
    XCTAssertNotNil(firstResult)

    // Get it again - should be the same
    let secondResult = model.relatedText
    XCTAssertEqual(firstResult, secondResult)

    // And again - should still be the same
    let thirdResult = model.relatedText
    XCTAssertEqual(firstResult, thirdResult)
  }

  // MARK: - playPauseButtonTapped Tests

  func testPlayPauseButtonTapped_StopsWhenPlaying() {
    let station = AnyStation.mock
    let spy = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      currentStation: station,
      playbackStatus: .playing(station)
    )

    let model = PlayerPageModel(stationPlayer: spy)

    XCTAssertEqual(spy.stopCalledCount, 0)
    model.playPauseButtonTapped()

    XCTAssertEqual(spy.stopCalledCount, 1)
    XCTAssertEqual(spy.callsToPlay.count, 0)
  }

  func testPlayPauseButtonTapped_DismissesWhenStopButtonPressed() {
    let station = AnyStation.mock
    let spy = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      currentStation: station,
      playbackStatus: .playing(station)
    )

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
    let station = AnyStation.mock
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      currentStation: station,
      playbackStatus: .playing(station)
    )
    // No playolaSpinPlaying, so no AudioBlock

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.heartState, .hidden)
    XCTAssertEqual(model.heartState.imageName, "")
    XCTAssertEqual(model.heartState.imageColorHex, "")
  }

  func testHeartState_EmptyWhenPlayingUnlikedSong() async {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .playing(station)
    )

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: playerMock)

      XCTAssertEqual(model.heartState, .empty)
      XCTAssertEqual(model.heartState.imageName, "heart")
      XCTAssertEqual(model.heartState.imageColorHex, "#BABABA")
    }
  }

  func testHeartState_FilledWhenPlayingLikedSong() async {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .playing(station)
    )

    withDependencies {
      let likesManager = LikesManager()
      // Pre-like the song
      likesManager.like(audioBlock)
      $0.likesManager = likesManager
    } operation: {
      let model = PlayerPageModel(stationPlayer: playerMock)

      XCTAssertEqual(model.heartState, .filled)
      XCTAssertEqual(model.heartState.imageName, "heart.fill")
      XCTAssertEqual(model.heartState.imageColorHex, "#EF6962")
    }
  }

  // MARK: - Heart Button Tap Tests

  func testHeartButtonTapped_DoesNothingWhenNoAudioBlock() async {
    let station = AnyStation.mock
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      currentStation: station,
      playbackStatus: .playing(station)
    )
    // No playolaSpinPlaying

    withDependencies {
      let likesManager = LikesManager()
      $0.likesManager = likesManager
    } operation: {
      let model = PlayerPageModel(stationPlayer: playerMock)

      model.heartButtonTapped()

      // Should not crash and likes should remain empty
      XCTAssertEqual(model.likesManager.allLikedAudioBlocks.count, 0)
    }
  }

  func testHeartButtonTapped_LikesUnlikedSong() async {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .playing(station)
    )

    withDependencies {
      let likesManager = LikesManager()
      $0.likesManager = likesManager
    } operation: {
      let model = PlayerPageModel(stationPlayer: playerMock)

      XCTAssertEqual(model.heartState, .empty)

      model.heartButtonTapped()

      XCTAssertEqual(model.heartState, .filled)
      XCTAssertTrue(model.likesManager.isLiked(audioBlock.id))
      XCTAssertEqual(model.likesManager.allLikedAudioBlocks.count, 1)
    }
  }

  func testHeartButtonTapped_UnlikesLikedSong() async {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .playing(station)
    )

    withDependencies {
      let likesManager = LikesManager()
      // Pre-like the song
      likesManager.like(audioBlock)
      $0.likesManager = likesManager
    } operation: {
      let model = PlayerPageModel(stationPlayer: playerMock)

      XCTAssertEqual(model.heartState, .filled)

      model.heartButtonTapped()

      XCTAssertEqual(model.heartState, .empty)
      XCTAssertFalse(model.likesManager.isLiked(audioBlock.id))
      XCTAssertEqual(model.likesManager.allLikedAudioBlocks.count, 0)
    }
  }

  func testHeartButtonTapped_CreatesPendingOperation() async {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .playing(station)
    )

    withDependencies {
      let likesManager = LikesManager()
      $0.likesManager = likesManager
    } operation: {
      let model = PlayerPageModel(stationPlayer: playerMock)

      model.heartButtonTapped()

      XCTAssertEqual(model.likesManager.pendingOperations.count, 1)
      XCTAssertEqual(model.likesManager.pendingOperations.first?.type, .like)
      XCTAssertEqual(model.likesManager.pendingOperations.first?.audioBlock.id, audioBlock.id)
    }
  }

  // MARK: - Button Visibility Tests (Type-based)

  func testHeartState_HiddenWhenPlayingNonSongAudioBlock() async {
    let station = AnyStation.mock
    let commercialBlock = AudioBlock.mockWith(type: "commercial")
    let spin = Spin.mockWith(audioBlock: commercialBlock)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Ad Content",
      titlePlaying: "Commercial",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .playing(station)
    )

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: playerMock)

      XCTAssertEqual(model.heartState, .hidden)
      XCTAssertEqual(model.heartState.imageName, "")
      XCTAssertEqual(model.heartState.imageColorHex, "")
    }
  }

  func testHeartState_VisibleWhenPlayingSongAudioBlock() async {
    let station = AnyStation.mock
    let songBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: songBlock)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Rachel Loy",
      titlePlaying: "Selfie",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .playing(station)
    )

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: playerMock)

      XCTAssertEqual(model.heartState, .empty)
      XCTAssertEqual(model.heartState.imageName, "heart")
      XCTAssertEqual(model.heartState.imageColorHex, "#BABABA")
    }
  }

  func testHeartButtonTapped_DoesNothingWhenPlayingNonSongAudioBlock() async {
    let station = AnyStation.mock
    let commercialBlock = AudioBlock.mockWith(type: "commercial")
    let spin = Spin.mockWith(audioBlock: commercialBlock)
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      artistPlaying: "Ad Content",
      titlePlaying: "Commercial",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: .playing(station)
    )

    withDependencies {
      let likesManager = LikesManager()
      $0.likesManager = likesManager
    } operation: {
      let model = PlayerPageModel(stationPlayer: playerMock)

      model.heartButtonTapped()

      // Should not create any likes or pending operations
      XCTAssertEqual(model.likesManager.allLikedAudioBlocks.count, 0)
      XCTAssertEqual(model.likesManager.pendingOperations.count, 0)
    }
  }

  // MARK: - Navigation Bar Title Tests

  func testNavBarTitles_PlayolaStationLoading() {
    let playolaStation = AnyStation.playola(
      PlayolaPlayer.Station(
        id: "test-playola-id",
        name: "Test Radio Show",
        curatorName: "Test Curator",
        imageUrl: "https://test.image.url",
        description: "Test Description",
        active: true,
        createdAt: Date(),
        updatedAt: Date()
      ))
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      currentStation: playolaStation,
      playbackStatus: .loading(playolaStation)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.primaryNavBarTitle, "Test Curator")
    XCTAssertEqual(model.secondaryNavBarTitle, "Test Radio Show")
  }

  func testNavBarTitles_PlayolaStationStartingNewStation() {
    let playolaStation = AnyStation.playola(
      PlayolaPlayer.Station(
        id: "test-playola-id",
        name: "Another Radio Show",
        curatorName: "Another Curator",
        imageUrl: "https://test.image.url",
        description: "Another Description",
        active: true,
        createdAt: Date(),
        updatedAt: Date()
      ))
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      currentStation: playolaStation,
      playbackStatus: .startingNewStation(playolaStation)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.primaryNavBarTitle, "Another Curator")
    XCTAssertEqual(model.secondaryNavBarTitle, "Another Radio Show")
  }

  func testNavBarTitles_UrlStationLoading() {
    let urlStation = AnyStation.url(
      UrlStation(
        id: "test-url-id",
        name: "Test FM",
        streamUrl: "https://test.stream.url",
        imageUrl: "https://test.image.url",
        description: "Test FM Station",
        website: nil,
        location: "Test City, TX",
        active: true,
        createdAt: Date(),
        updatedAt: Date()
      ))
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      currentStation: urlStation,
      playbackStatus: .loading(urlStation)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.primaryNavBarTitle, "Test FM")
    XCTAssertEqual(model.secondaryNavBarTitle, "Test City, TX")
  }

  func testNavBarTitles_UrlStationStartingNewStation() {
    let urlStation = AnyStation.url(
      UrlStation(
        id: "test-url-id2",
        name: "Another FM",
        streamUrl: "https://test.stream.url",
        imageUrl: "https://test.image.url",
        description: "Another FM Station",
        website: nil,
        location: "Another City, CA",
        active: true,
        createdAt: Date(),
        updatedAt: Date()
      ))
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      currentStation: urlStation,
      playbackStatus: .startingNewStation(urlStation)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.primaryNavBarTitle, "Another FM")
    XCTAssertEqual(model.secondaryNavBarTitle, "Another City, CA")
  }

  func testNavBarTitles_UrlStationWithoutLocation() {
    let urlStationNoLocation = AnyStation.url(
      UrlStation(
        id: "test-url-no-location",
        name: "No Location FM",
        streamUrl: "https://test.stream.url",
        imageUrl: "https://test.image.url",
        description: "FM Station without location",
        website: nil,
        location: nil,
        active: true,
        createdAt: Date(),
        updatedAt: Date()
      ))
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      currentStation: urlStationNoLocation,
      playbackStatus: .loading(urlStationNoLocation)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.primaryNavBarTitle, "No Location FM")
    XCTAssertEqual(model.secondaryNavBarTitle, "")
  }

  func testNavBarTitles_WhenPlaying() {
    let station = AnyStation.mock
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      currentStation: station,
      playbackStatus: .playing(station)
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.primaryNavBarTitle, station.name)
    if station.isPlayolaStation {
      XCTAssertEqual(model.secondaryNavBarTitle, station.stationName)
    } else {
      XCTAssertEqual(model.secondaryNavBarTitle, station.location ?? "")
    }
  }

  func testNavBarTitles_EmptyWhenStopped() {
    let playerMock = StationPlayerMock()

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying(
      playbackStatus: .stopped
    )

    let model = PlayerPageModel(stationPlayer: playerMock)

    XCTAssertEqual(model.primaryNavBarTitle, "")
    XCTAssertEqual(model.secondaryNavBarTitle, "")
  }
}
