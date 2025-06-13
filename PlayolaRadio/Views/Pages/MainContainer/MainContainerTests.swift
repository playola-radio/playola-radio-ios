//
//  MainContainerTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/12/25.
//
@testable import PlayolaRadio
import Sharing
import Testing

enum MainContainerTests {
  @MainActor @Suite("ViewAppeared")
  struct ViewAppeared {
    @Test("Retrieves the list -- working")
    func testCorrectlyRetrievesStationListsWhenApiIsSuccessful() async {
      @Shared(.stationListsLoaded) var stationListsLoaded = false
      @Shared(.stationLists) var stationLists = StationList.mocks
      let apiMock = APIMock(getStationListsShouldSucceed: true)
      let mainContainerModel = MainContainerModel(api: apiMock)
      await mainContainerModel.viewAppeared()
      #expect(apiMock.getStationListsCallCount == 1)
    }
    
    @Test("Displays an error alert on api error")
    func testDisplaysAnErrorAlertOnApiError() async {
      @Shared(.stationListsLoaded) var stationListsLoaded = false
      @Shared(.stationLists) var stationLists = StationList.mocks
      let apiMock = APIMock(getStationListsShouldSucceed: false)
      let mainContainerModel = MainContainerModel(api: apiMock)
      await mainContainerModel.viewAppeared()
      #expect(mainContainerModel.presentedAlert == .errorLoadingStations)
    }
  }
}
