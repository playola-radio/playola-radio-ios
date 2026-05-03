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
import Testing

@testable import PlayolaRadio

@MainActor
struct PlayerPageTests {
  // MARK: - viewAppeared Tests

  @Test
  func testViewAppearedPopulatesCorrectlyWhenLoadingNoProgress() {
    let station = AnyStation.mock
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .loading(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.primaryNavBarTitle == station.name)
    if station.isPlayolaStation {
      #expect(model.secondaryNavBarTitle == station.stationName)
    } else {
      #expect(model.secondaryNavBarTitle == station.location ?? "")
    }
    #expect(model.nowPlayingText == "Station Loading...")
    #expect(model.playolaAudioBlockPlaying == nil)
  }

  @Test
  func testViewAppearedPopulatesCorrectlyWhenLoadingWithProgress() {
    let station = AnyStation.mock
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .loading(station, 0.42))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.primaryNavBarTitle == station.name)
    if station.isPlayolaStation {
      #expect(model.secondaryNavBarTitle == station.stationName)
    } else {
      #expect(model.secondaryNavBarTitle == station.location ?? "")
    }
    #expect(model.nowPlayingText == "Station Loading...")
    #expect(model.loadingPercentage == 0.42)
    #expect(model.playolaAudioBlockPlaying == nil)
  }

  @Test
  func testViewAppearedPopulatesCorrectlyWhenSomethingIsPlaying() {
    let station = AnyStation.mock
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      artistPlaying: "Rachel Loy", titlePlaying: "Selfie", station: station)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.nowPlayingText == "Selfie - Rachel Loy")
    #expect(model.stationArtUrl == station.imageUrl)
    #expect(model.playolaAudioBlockPlaying == nil)
  }

  @Test
  func testViewAppearedPopulatesCorrectlyWhenSomethingIsPlayingWithAudioBlock() {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(title: "Selfie", artist: "Rachel Loy", type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      artistPlaying: "Rachel Loy", titlePlaying: "Selfie", spin: spin, station: station)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.nowPlayingText == "Selfie - Rachel Loy")
    #expect(model.stationArtUrl == station.imageUrl)
    #expect(model.playolaAudioBlockPlaying == audioBlock)
  }

  @Test
  func testViewAppearedPopulatesRelatedTextPrioritizingTheAudioBlockTranscription() {
    let transcription = "This is the transcription"
    let audioBlock = AudioBlock.mockWith(type: "song", transcription: transcription)
    let relatedTexts = [
      RelatedText(title: "title1", body: "body1"),
      RelatedText(title: "title2", body: "body2"),
    ]
    let spin = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.relatedText?.title == "Why I chose this song")
    #expect(model.relatedText?.body == transcription)
    #expect(model.playolaAudioBlockPlaying == audioBlock)
  }

  @Test
  func testViewAppearedPopulatesRelatedTextWhenRelatedTextButNoTranscription() {
    let audioBlock = AudioBlock.mockWith(type: "song", transcription: nil)
    let relatedTexts = [
      RelatedText(title: "title1", body: "body1"),
      RelatedText(title: "title2", body: "body2"),
    ]
    let spin = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.relatedText != nil)
    #expect(model.relatedText == relatedTexts[0] || model.relatedText == relatedTexts[1])
    #expect(model.playolaAudioBlockPlaying == audioBlock)
  }

  @Test
  func testViewAppearedPopulatesCorrectlyWhenStopped() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: nil, status: .stopped)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.nowPlayingText == "")
    #expect(model.albumArtUrl == nil)
    #expect(model.playolaAudioBlockPlaying == nil)
  }

  @Test
  func testViewAppearedPopulatesCorrectlyWhenError() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: nil, status: .error)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.nowPlayingText == "Error Playing Station")
    #expect(model.primaryNavBarTitle == "")
    #expect(model.secondaryNavBarTitle == "")
    #expect(model.albumArtUrl == nil)
    #expect(model.playolaAudioBlockPlaying == nil)
  }

  @Test
  func testViewAppearedPopulatesCorrectlyWhenStartingNewStation() {
    let station = AnyStation.mock
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .startingNewStation(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.primaryNavBarTitle == station.name)
    if station.isPlayolaStation {
      #expect(model.secondaryNavBarTitle == station.stationName)
    } else {
      #expect(model.secondaryNavBarTitle == station.location ?? "")
    }
    #expect(model.nowPlayingText == "Station Loading...")
    #expect(model.loadingPercentage == 0.0)
    #expect(model.playolaAudioBlockPlaying == nil)
  }

  @Test
  func testViewAppearedPopulatesCorrectlyWhenStartingNewStationWithAudioBlock() {
    let station = AnyStation.mock
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      spin: spin, station: station, status: .startingNewStation(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.primaryNavBarTitle == station.name)
    if station.isPlayolaStation {
      #expect(model.secondaryNavBarTitle == station.stationName)
    } else {
      #expect(model.secondaryNavBarTitle == station.location ?? "")
    }
    #expect(model.nowPlayingText == "Station Loading...")
    #expect(model.loadingPercentage == 0.0)
    #expect(model.playolaAudioBlockPlaying == audioBlock)
  }

  @Test
  func testRelatedTextReturnsConsistentValueForSameSpin() {
    let audioBlock = AudioBlock.mockWith(type: "song", transcription: nil)
    let relatedTexts = [
      RelatedText(title: "title1", body: "body1"),
      RelatedText(title: "title2", body: "body2"),
    ]
    let spin = Spin.mockWith(audioBlock: audioBlock, relatedTexts: relatedTexts)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    let firstResult = model.relatedText
    #expect(firstResult != nil)
    #expect(firstResult == model.relatedText)
    #expect(firstResult == model.relatedText)
  }

  // MARK: - playPauseButtonTapped Tests

  @Test
  func testPlayPauseButtonTappedStopsWhenPlaying() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith()
    let spy = StationPlayerMock()
    let model = PlayerPageModel(stationPlayer: spy)

    model.playPauseButtonTapped()

    #expect(spy.stopCalledCount == 1)
    #expect(spy.callsToPlay.count == 0)
  }

  @Test
  func testPlayPauseButtonTappedDismissesWhenStopButtonPressed() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith()
    let spy = StationPlayerMock()
    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.playPauseButtonTapped()

    #expect(spy.stopCalledCount == 1)
    #expect(dismissCalled)
  }

  // MARK: - scenePhaseChanged Tests

  @Test
  func testScenePhaseChangedDismissesWhenActiveAndPlayerStopped() {
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .stopped)

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .active)

    #expect(dismissCalled)
  }

  @Test
  func testScenePhaseChangedDismissesWhenActiveAndPlayerError() {
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .error)

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .active)

    #expect(dismissCalled)
  }

  @Test
  func testScenePhaseChangedDoesNotDismissWhenActiveAndPlayerPlaying() {
    let station = AnyStation.mock
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .playing(station))

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .active)

    #expect(!dismissCalled)
  }

  @Test
  func testScenePhaseChangedDoesNotDismissWhenActiveAndPlayerLoading() {
    let station = AnyStation.mock
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .loading(station))

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .active)

    #expect(!dismissCalled)
  }

  @Test
  func testScenePhaseChangedDoesNotDismissWhenActiveAndPlayerStartingNewStation() {
    let station = AnyStation.mock
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .startingNewStation(station))

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .active)

    #expect(!dismissCalled)
  }

  @Test
  func testScenePhaseChangedDoesNotDismissWhenBackgroundPhase() {
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .stopped)

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .background)

    #expect(!dismissCalled)
  }

  @Test
  func testScenePhaseChangedDoesNotDismissWhenInactivePhase() {
    let spy = StationPlayerMock()
    spy.state = StationPlayer.State(playbackStatus: .stopped)

    var dismissCalled = false
    let model = PlayerPageModel(stationPlayer: spy, onDismiss: { dismissCalled = true })

    model.scenePhaseChanged(newPhase: .inactive)

    #expect(!dismissCalled)
  }

  // MARK: - Heart State Tests

  @Test
  func testHeartStateHiddenWhenNotPlayingPlayolaSong() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith()  // No spin
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.heartState == .hidden)
    #expect(model.heartState.imageName == "")
    #expect(model.heartState.imageColorHex == "")
  }

  @Test
  func testHeartStateEmptyWhenPlayingUnlikedSong() async {
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())

      #expect(model.heartState == .empty)
      #expect(model.heartState.imageName == "heart")
      #expect(model.heartState.imageColorHex == "#BABABA")
    }
  }

  @Test
  func testHeartStateFilledWhenPlayingLikedSong() async {
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      let likesManager = LikesManager()
      likesManager.like(audioBlock)
      $0.likesManager = likesManager
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())

      #expect(model.heartState == .filled)
      #expect(model.heartState.imageName == "heart.fill")
      #expect(model.heartState.imageColorHex == "#EF6962")
    }
  }

  // MARK: - Heart Button Tap Tests

  @Test
  func testHeartButtonTappedDoesNothingWhenNoAudioBlock() async {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith()  // No spin

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())
      model.heartButtonTapped()
      #expect(model.likesManager.allLikedAudioBlocks.count == 0)
    }
  }

  @Test
  func testHeartButtonTappedLikesUnlikedSong() async {
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())

      #expect(model.heartState == .empty)
      model.heartButtonTapped()

      #expect(model.heartState == .filled)
      #expect(model.likesManager.isLiked(audioBlock.id))
      #expect(model.likesManager.allLikedAudioBlocks.count == 1)
    }
  }

  @Test
  func testHeartButtonTappedUnlikesLikedSong() async {
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      let likesManager = LikesManager()
      likesManager.like(audioBlock)
      $0.likesManager = likesManager
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())

      #expect(model.heartState == .filled)
      model.heartButtonTapped()

      #expect(model.heartState == .empty)
      #expect(!model.likesManager.isLiked(audioBlock.id))
      #expect(model.likesManager.allLikedAudioBlocks.count == 0)
    }
  }

  @Test
  func testHeartButtonTappedCreatesPendingOperation() async {
    let audioBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: audioBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())
      model.heartButtonTapped()

      #expect(model.likesManager.pendingOperations.count == 1)
      #expect(model.likesManager.pendingOperations.first?.type == .like)
      #expect(model.likesManager.pendingOperations.first?.audioBlock.id == audioBlock.id)
    }
  }

  // MARK: - Button Visibility Tests (Type-based)

  @Test
  func testHeartStateHiddenWhenPlayingNonSongAudioBlock() async {
    let commercialBlock = AudioBlock.mockWith(type: "commercial")
    let spin = Spin.mockWith(audioBlock: commercialBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())

      #expect(model.heartState == .hidden)
      #expect(model.heartState.imageName == "")
      #expect(model.heartState.imageColorHex == "")
    }
  }

  @Test
  func testHeartStateVisibleWhenPlayingSongAudioBlock() async {
    let songBlock = AudioBlock.mockWith(type: "song")
    let spin = Spin.mockWith(audioBlock: songBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())

      #expect(model.heartState == .empty)
      #expect(model.heartState.imageName == "heart")
      #expect(model.heartState.imageColorHex == "#BABABA")
    }
  }

  @Test
  func testHeartButtonTappedDoesNothingWhenPlayingNonSongAudioBlock() async {
    let commercialBlock = AudioBlock.mockWith(type: "commercial")
    let spin = Spin.mockWith(audioBlock: commercialBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    withDependencies {
      $0.likesManager = LikesManager()
    } operation: {
      let model = PlayerPageModel(stationPlayer: StationPlayerMock())
      model.heartButtonTapped()

      #expect(model.likesManager.allLikedAudioBlocks.count == 0)
      #expect(model.likesManager.pendingOperations.count == 0)
    }
  }

  // MARK: - Navigation Bar Title Tests

  @Test
  func testNavBarTitlesPlayolaStationLoading() {
    let station = AnyStation.mockPlayola(name: "Test Radio Show", curatorName: "Test Curator")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .loading(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.primaryNavBarTitle == "Test Curator")
    #expect(model.secondaryNavBarTitle == "Test Radio Show")
  }

  @Test
  func testNavBarTitlesPlayolaStationStartingNewStation() {
    let station = AnyStation.mockPlayola(name: "Another Radio Show", curatorName: "Another Curator")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .startingNewStation(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.primaryNavBarTitle == "Another Curator")
    #expect(model.secondaryNavBarTitle == "Another Radio Show")
  }

  @Test
  func testNavBarTitlesUrlStationLoading() {
    let station = AnyStation.mockUrl(name: "Test FM", location: "Test City, TX")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .loading(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.primaryNavBarTitle == "Test FM")
    #expect(model.secondaryNavBarTitle == "Test City, TX")
  }

  @Test
  func testNavBarTitlesUrlStationStartingNewStation() {
    let station = AnyStation.mockUrl(name: "Another FM", location: "Another City, CA")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .startingNewStation(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.primaryNavBarTitle == "Another FM")
    #expect(model.secondaryNavBarTitle == "Another City, CA")
  }

  @Test
  func testNavBarTitlesUrlStationWithoutLocation() {
    let station = AnyStation.mockUrl(name: "No Location FM", location: "")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(
      station: station, status: .loading(station))
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.primaryNavBarTitle == "No Location FM")
    #expect(model.secondaryNavBarTitle == "")
  }

  @Test
  func testNavBarTitlesWhenPlaying() {
    let station = AnyStation.mock
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: station)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.primaryNavBarTitle == station.name)
    if station.isPlayolaStation {
      #expect(model.secondaryNavBarTitle == station.stationName)
    } else {
      #expect(model.secondaryNavBarTitle == station.location ?? "")
    }
  }

  @Test
  func testNavBarTitlesEmptyWhenStopped() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: nil, status: .stopped)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.primaryNavBarTitle == "")
    #expect(model.secondaryNavBarTitle == "")
  }

  // MARK: - Now Playing Text Tests

  @Test
  func testNowPlayingTextShowsPlayolaPaysForCommercial() {
    let commercialBlock = AudioBlock.mockWith(type: "commercial")
    let spin = Spin.mockWith(audioBlock: commercialBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.nowPlayingText == "Playola Pays")
  }

  @Test
  func testNowPlayingTextShowsTitleArtistForSong() {
    let songBlock = AudioBlock.mockWith(title: "Test Song", artist: "Test Artist", type: "song")
    let spin = Spin.mockWith(audioBlock: songBlock)
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.nowPlayingText == "Test Song - Test Artist")
  }

  @Test
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

    #expect(model.nowPlayingText == "Airing Song - Airing Artist")
  }

  @Test
  func testNowPlayingTextShowsEpisodeTitleForNonSongWithAiring() {
    let voiceTrackBlock = AudioBlock.mockWith(type: "voicetrack")
    let airing = Airing.mockWith(
      episode: Episode.mockWith(title: "My Cool Episode")
    )
    let spin = Spin.mockWith(audioBlock: voiceTrackBlock, airing: airing)

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin)

    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.nowPlayingText == "My Cool Episode")
  }

  @Test
  func testNowPlayingTextShowsStationNameForNonSongWithoutAiring() {
    let station = AnyStation.mockPlayola(name: "Test Station Name")
    let voiceTrackBlock = AudioBlock.mockWith(type: "voicetrack")
    let spin = Spin.mockWith(audioBlock: voiceTrackBlock, airing: nil)

    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(spin: spin, station: station)

    let model = PlayerPageModel(stationPlayer: StationPlayerMock())

    #expect(model.nowPlayingText == "Test Station Name")
  }

  // MARK: - Ask Question Tests

  @Test
  func testCanAskQuestionTrueForPlayolaStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: .mockPlayola())
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())
    #expect(model.canAskQuestion)
  }

  @Test
  func testCanAskQuestionFalseForUrlStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: .mockUrl())
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())
    #expect(!model.canAskQuestion)
  }

  @Test
  func testCanAskQuestionFalseWhenNoStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: nil, status: .stopped)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())
    #expect(!model.canAskQuestion)
  }

  @Test
  func testCurrentPlayolaStationReturnsStationForPlayolaStation() {
    let station = AnyStation.mockPlayola(id: "test-id", curatorName: "Test Curator")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: station)
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())
    #expect(model.currentPlayolaStation?.id == "test-id")
    #expect(model.currentPlayolaStation?.curatorName == "Test Curator")
  }

  @Test
  func testCurrentPlayolaStationReturnsNilForUrlStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: .mockUrl())
    let model = PlayerPageModel(stationPlayer: StationPlayerMock())
    #expect(model.currentPlayolaStation == nil)
  }

  @Test
  func testAskQuestionButtonTappedNavigatesToAskQuestionPageAndDismisses() {
    let station = AnyStation.mockPlayola(id: "test-id", curatorName: "Test Curator")
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: station)
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    var dismissCalled = false
    let model = PlayerPageModel(
      stationPlayer: StationPlayerMock(), onDismiss: { dismissCalled = true })

    model.askQuestionButtonTapped()

    #expect(navCoordinator.path.count == 1)
    if case .askQuestionPage(let askModel) = navCoordinator.path.first {
      #expect(askModel.station.id == "test-id")
      #expect(askModel.curatorName == "Test Curator")
    } else {
      Issue.record("Expected askQuestionPage in navigation path")
    }
    #expect(dismissCalled)
  }

  @Test
  func testAskQuestionButtonTappedDoesNothingForUrlStation() {
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = .mockWith(station: .mockUrl())
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    let model = PlayerPageModel(stationPlayer: StationPlayerMock())
    model.askQuestionButtonTapped()

    #expect(navCoordinator.path.isEmpty)
  }
}
