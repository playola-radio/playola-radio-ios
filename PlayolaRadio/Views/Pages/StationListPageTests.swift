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
      let stationPlayerMock = StationPlayerMock()
      let apiMock = APIMock()
      let stationListModel = StationListModel(api: apiMock, stationPlayer: stationPlayerMock)
      #expect(stationListModel.stationPlayerState == StationPlayer.State(playbackState: .stopped))

      let newState = StationPlayer.State(playbackState: .playing, currentStation: RadioStation.mock, nowPlaying: FRadioPlayer.Metadata(artistName: "Test", trackName: "test", rawValue: nil, groups: []))

      stationPlayerMock.state = newState

      // TODO: Figure out how to wait for this value to change
//      #expect(stationListModel.stationPlayerState == newState)
    }
  }

  @Suite("Station Selected")
  struct StationSelected {
    
  }

}
