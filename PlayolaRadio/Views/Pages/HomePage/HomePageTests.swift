//
//  HomePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//

@testable import PlayolaRadio
import Sharing
import Testing
import IdentifiedCollections

enum HomePageTests {
  @MainActor @Suite("ViewAppeared")
  struct ViewAppeared {
    @Test("Populates forYouStations based on initial value of shared stationLists")
    func testPopulatesForYouStationsBasedOnInitialValueOfSharedStationLists() async {
      @Shared(.stationLists) var stationLists = StationList.mocks
      let artistStations = stationLists.first { $0.id == StationList.artistListId }
      #expect(artistStations != nil)
      let model = HomePageModel()
      await model.viewAppeared()
      #expect(model.forYouStations.elements == artistStations!.stations)
    }

    @Test("Repopulates forYouStations when shared stationLists changes")
    func testRepopulatesForYouStationsWhenSharedStationListsChanges() async {
      @Shared(.stationLists) var stationLists = StationList.mocks
      let artistStations = stationLists.first { $0.id == StationList.artistListId }
      let inDevelopmentStations = stationLists.first { $0.id == StationList.inDevelopmentListId }
      #expect(artistStations != nil)
      #expect(inDevelopmentStations != nil)
      #expect(artistStations!.stations != inDevelopmentStations!.stations)
      let model = HomePageModel()
      await model.viewAppeared()
      #expect(model.forYouStations.elements == artistStations!.stations)
      $stationLists.withLock { $0 = IdentifiedArray(
        uniqueElements: [StationList(
          id: StationList.artistListId,
          title: "Changed",
          stations: inDevelopmentStations!.stations)]) }
      #expect(model.forYouStations.elements == inDevelopmentStations!.stations)
    }
  }

  @MainActor
  struct tappingTheP {
    @Test("Turns on the secret stations")
    func testTurnsOnTheSecretStations() {
      let homePage = HomePageModel()
      #expect(homePage.showSecretStations == false)
      homePage.handlePlayolaIconTapped10Times()
      #expect(homePage.showSecretStations == true)
      #expect(homePage.presentedAlert == .secretStationsTurnedOnAlert)
    }

    @Test("Hides the secret stations")
    func testHidesTheSecretStations() {
      @Shared(.showSecretStations) var showSecretStations = true
      let homePage = HomePageModel()
      #expect(homePage.showSecretStations == true)
      homePage.handlePlayolaIconTapped10Times()
      #expect(homePage.showSecretStations == false)
      #expect(homePage.presentedAlert == .secretStationsHiddenAlert)
    }
  }
}
