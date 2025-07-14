//
//  HomePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//

import IdentifiedCollections
import Sharing
import Testing

@testable import PlayolaRadio

enum HomePageTests {
  @MainActor @Suite("ViewAppeared")
  struct ViewAppeared {
    @Test(
      "Populates forYouStations based on initial value of shared stationLists")
    func testPopulatesForYouStationsBasedOnInitialValueOfSharedStationLists()
      async
    {
      @Shared(.stationLists) var stationLists = StationList.mocks
      let artistStations = stationLists.first {
        $0.id == StationList.artistListId
      }
      #expect(artistStations != nil)
      let model = HomePageModel()
      await model.viewAppeared()
      #expect(model.forYouStations.elements == artistStations!.stations)
    }

    @Test("Repopulates forYouStations when shared stationLists changes")
    func testRepopulatesForYouStationsWhenSharedStationListsChanges() async {
      @Shared(.stationLists) var stationLists = StationList.mocks
      let artistStations = stationLists.first {
        $0.id == StationList.artistListId
      }
      let inDevelopmentStations = stationLists.first {
        $0.id == StationList.inDevelopmentListId
      }
      #expect(artistStations != nil)
      #expect(inDevelopmentStations != nil)
      #expect(artistStations!.stations != inDevelopmentStations!.stations)
      let model = HomePageModel()
      await model.viewAppeared()
      #expect(model.forYouStations.elements == artistStations!.stations)
      $stationLists.withLock {
        $0 = IdentifiedArray(
          uniqueElements: [
            StationList(
              id: StationList.artistListId,
              title: "Changed",
              stations: inDevelopmentStations!.stations)
          ])
      }
      #expect(model.forYouStations.elements == inDevelopmentStations!.stations)
    }
  }

  @MainActor @Suite("WelcomeMessage")
  struct WelcomeMessage {
    @Test("Shows generic welcome message when no user is logged in")
    func testShowsGenericWelcomeMessageWhenNoUserIsLoggedIn() {
      @Shared(.auth) var auth = Auth()
      let model = HomePageModel()
      #expect(model.welcomeMessage == "Welcome to Playola")
    }

    @Test("Shows personalized welcome message when user is logged in")
    func testShowsPersonalizedWelcomeMessageWhenUserIsLoggedIn() {
      let mockJWT =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjEyMyIsImRpc3BsYXlOYW1lIjoiSm9obiBEb2UiLCJlbWF" +
      "pbCI6ImpvaG5AZXhhbXBsZS5jb20iLCJyb2xlIjoidXNlciJ9.fake_signature"
      @Shared(.auth) var auth = Auth(jwtToken: mockJWT)
      let model = HomePageModel()
      #expect(model.welcomeMessage == "Welcome, John Doe")
    }

    @Test("Updates welcome message when auth changes")
    func testUpdatesWelcomeMessageWhenAuthChanges() {
      @Shared(.auth) var auth = Auth()
      let model = HomePageModel()
      #expect(model.welcomeMessage == "Welcome to Playola")

      let mockJWT =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjEyMyIsImRpc3BsYXlOYW1lIjoiSm9obiBEb2UiLCJlbWF" +
      "pbCI6ImpvaG5AZXhhbXBsZS5jb20iLCJyb2xlIjoidXNlciJ9.fake_signature"
      $auth.withLock { $0 = Auth(jwtToken: mockJWT) }
      #expect(model.welcomeMessage == "Welcome, John Doe")
    }
  }

  @MainActor
  struct TappingTheP {
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

  @MainActor @Suite("PlayerInteraction")
  struct StationPlayerInteraction {
    @Test("Plays a station when it is tapped")
    func testPlaysAStationWhenItIsTapped() {
      let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
      let station: RadioStation = .mock

      let homePageModel = HomePageModel(stationPlayer: stationPlayerMock)
      homePageModel.handleStationTapped(station)

      #expect(stationPlayerMock.callsToPlay.count == 1)
      #expect(stationPlayerMock.callsToPlay.first?.id == station.id)
    }
  }
}
