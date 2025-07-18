//
//  HomePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//

import IdentifiedCollections
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class HomePageTests: XCTestCase {
  // MARK: - ViewAppeared Tests

  func testViewAppeared_PopulatesForYouStationsBasedOnInitialValueOfSharedStationLists() async {
    @Shared(.stationLists) var stationLists = StationList.mocks
    let artistStations = stationLists.first {
      $0.id == StationList.artistListId
    }
    XCTAssertNotNil(artistStations)
    let model = HomePageModel()
    await model.viewAppeared()
    XCTAssertEqual(model.forYouStations.elements, artistStations!.stations)
  }

  func testViewAppeared_RepopulatesForYouStationsWhenSharedStationListsChanges() async {
    @Shared(.stationLists) var stationLists = StationList.mocks
    let artistStations = stationLists.first {
      $0.id == StationList.artistListId
    }
    let inDevelopmentStations = stationLists.first {
      $0.id == StationList.inDevelopmentListId
    }
    XCTAssertNotNil(artistStations)
    XCTAssertNotNil(inDevelopmentStations)
    XCTAssertNotEqual(artistStations!.stations, inDevelopmentStations!.stations)
    let model = HomePageModel()
    await model.viewAppeared()
    XCTAssertEqual(model.forYouStations.elements, artistStations!.stations)
    $stationLists.withLock {
      $0 = IdentifiedArray(
        uniqueElements: [
          StationList(
            id: StationList.artistListId,
            title: "Changed",
            stations: inDevelopmentStations!.stations)
        ])
    }
    XCTAssertEqual(model.forYouStations.elements, inDevelopmentStations!.stations)
  }

  // MARK: - Welcome Message Tests

  func testWelcomeMessage_ShowsGenericWelcomeMessageWhenNoUserIsLoggedIn() {
    @Shared(.auth) var auth = Auth()
    let model = HomePageModel()
    XCTAssertEqual(model.welcomeMessage, "Welcome to Playola")
  }

  func testWelcomeMessage_ShowsPersonalizedWelcomeMessageWhenUserIsLoggedIn() {
    let mockJWT =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjEyMyIsImRpc3BsYXlOYW1lIjoiSm9obiBEb2UiLCJlbWF"
      + "pbCI6ImpvaG5AZXhhbXBsZS5jb20iLCJyb2xlIjoidXNlciJ9.fake_signature"
    @Shared(.auth) var auth = Auth(jwtToken: mockJWT)
    let model = HomePageModel()
    XCTAssertEqual(model.welcomeMessage, "Welcome, John Doe")
  }

  func testWelcomeMessage_UpdatesWelcomeMessageWhenAuthChanges() {
    @Shared(.auth) var auth = Auth()
    let model = HomePageModel()
    XCTAssertEqual(model.welcomeMessage, "Welcome to Playola")

    let mockJWT =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjEyMyIsImRpc3BsYXlOYW1lIjoiSm9obiBEb2UiLCJlbWF"
      + "pbCI6ImpvaG5AZXhhbXBsZS5jb20iLCJyb2xlIjoidXNlciJ9.fake_signature"
    $auth.withLock { $0 = Auth(jwtToken: mockJWT) }
    XCTAssertEqual(model.welcomeMessage, "Welcome, John Doe")
  }

  // MARK: - Tapping The P Tests

  func testTappingTheP_TurnsOnTheSecretStations() {
    let homePage = HomePageModel()
    XCTAssertFalse(homePage.showSecretStations)
    homePage.handlePlayolaIconTapped10Times()
    XCTAssertTrue(homePage.showSecretStations)
    XCTAssertEqual(homePage.presentedAlert, .secretStationsTurnedOnAlert)
  }

  func testTappingTheP_HidesTheSecretStations() {
    @Shared(.showSecretStations) var showSecretStations = true
    let homePage = HomePageModel()
    XCTAssertTrue(homePage.showSecretStations)
    homePage.handlePlayolaIconTapped10Times()
    XCTAssertFalse(homePage.showSecretStations)
    XCTAssertEqual(homePage.presentedAlert, .secretStationsHiddenAlert)
  }

  // MARK: - Player Interaction Tests

  func testPlayerInteraction_PlaysAStationWhenItIsTapped() {
    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let station: RadioStation = .mock

    let homePageModel = HomePageModel(stationPlayer: stationPlayerMock)
    homePageModel.handleStationTapped(station)

    XCTAssertEqual(stationPlayerMock.callsToPlay.count, 1)
    XCTAssertEqual(stationPlayerMock.callsToPlay.first?.id, station.id)
  }
}
