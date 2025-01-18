//
//  Untitled.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/16/25.
//
import Testing
import FRadioPlayer
@testable import PlayolaRadio

struct StationListPageTests {

  @Suite("ViewAppeared")
  struct ViewAppeared {

    @Test("Retrieves the list -- working")
    func testCorrectlyRetrievesStationListsWhenApiIsSuccessful() async {
      let apiMock = APIMock(getStationListsShouldSucceed: true)
      let stationListModel = StationListModel(api: apiMock)
      apiMock.beforeAssertions = {
        #expect(stationListModel.isLoadingStationLists == true)
      }
      await stationListModel.viewAppeared()
      #expect(stationListModel.stationLists.elementsEqual(StationList.mocks))
      #expect(stationListModel.isLoadingStationLists == false)
    }

    @Test("Displays an error alert on api error")
    func testDisplaysAnErrorAlertOnApiError() async {
      let apiMock = APIMock(getStationListsShouldSucceed: false)
      let stationListModel = StationListModel(api: apiMock)
      apiMock.beforeAssertions = {
        #expect(stationListModel.isLoadingStationLists == true)
      }
      await stationListModel.viewAppeared()
      #expect(stationListModel.presentedAlert == .errorLoadingStations)
      #expect(stationListModel.isLoadingStationLists == false)
    }

    @Test("Subscribes to stationPlayer changes")
    func testSubscribesToStationPlayerChanges() async {
      let stationPlayerMock = URLStreamPlayerMock()
      let apiMock = APIMock()
      let stationListModel = StationListModel(api: apiMock, stationPlayer: stationPlayerMock)
      #expect(stationListModel.stationPlayerState == URLStreamPlayer.State(playbackState: .stopped))

      let newState = URLStreamPlayer.State(playbackState: .playing, currentStation: RadioStation.mock, nowPlaying: FRadioPlayer.Metadata(artistName: "Test", trackName: "test", rawValue: nil, groups: []))

      stationPlayerMock.state = newState

      // TODO: Figure out how to wait for this value to change
//      #expect(stationListModel.stationPlayerState == newState)
    }
  }

  @Suite("Station Selected")
  struct StationSelected {
    @Test("Navigates to now playing when NowPlaying is tapped")
    func testNavigatesToNowPlayingWhenNowPlayingIsTapped() async {
      let stationPlayerMock: URLStreamPlayerMock = .mockPlayingPlayer()
      let navigationCoordinator = NavigationCoordinator()
      let stationListPage = StationListModel(stationPlayer: stationPlayerMock,
                                             navigationCoordinator: navigationCoordinator)
      await stationListPage.viewAppeared()
      stationListPage.nowPlayingToolbarButtonTapped()
      #expect(navigationCoordinator.path.last ~= .nowPlayingPage(NowPlayingPageModel()))
    }

    @Test("Navigates nowhere if it is tapped while a station is not playing")
    func testNavigatesNowhereIfTappedWhileAStationIsNotPlaying() async {
      let stationPlayerMock: URLStreamPlayerMock = .mockStoppedPlayer()

      let navigationCoordinator = NavigationCoordinator()
      let previousCount = navigationCoordinator.path.count
      let stationListPage = StationListModel(stationPlayer: stationPlayerMock,
                                             navigationCoordinator: navigationCoordinator)
      await stationListPage.viewAppeared()
      stationListPage.nowPlayingToolbarButtonTapped()
      #expect(navigationCoordinator.path.count == previousCount)
    }
  }

}
