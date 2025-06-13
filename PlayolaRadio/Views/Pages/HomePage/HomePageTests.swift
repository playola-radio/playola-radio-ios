//
//  HomePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//

@testable import PlayolaRadio
import Sharing
import Testing

enum HomePageTests {
  @MainActor @Suite("ViewAppeared")
  struct ViewAppeared {
    @Test("Populates forYouStations based on initial value of shared stationLists")
    func testPopulatesForYouStationsBasedOnInitialValueOfSharedStationLists() async {
    }

    @Test("Repopulates forYouStations when shared stationLists changes")
    func testRepopulatesForYouStationsWhenSharedStationListsChanges() async {
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
