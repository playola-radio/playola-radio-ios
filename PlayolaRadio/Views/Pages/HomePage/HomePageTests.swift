//
//  HomePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//

// swiftlint:disable force_try

import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class HomePageTests: XCTestCase {
  // MARK: - ViewAppeared Tests

  func testViewAppeared_PopulatesForYouStationsBasedOnInitialValueOfSharedStationLists() async {
    @Shared(.stationLists) var stationLists = StationList.mocks
    let artistStations = stationLists.first {
      $0.slug == StationList.artistListSlug
    }
    XCTAssertNotNil(artistStations)
    let model = HomePageModel()
    await model.viewAppeared()
    XCTAssertEqual(model.forYouStations.elements, artistStations!.stations)
  }

  func testViewAppeared_RepopulatesForYouStationsWhenSharedStationListsChanges() async {
    @Shared(.stationLists) var stationLists = StationList.mocks
    let artistStations = stationLists.first {
      $0.slug == StationList.artistListSlug
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
            id: "artist_list",
            name: "Changed",
            slug: StationList.artistListSlug,
            hidden: false,
            sortOrder: 1,
            createdAt: Date(),
            updatedAt: Date(),
            items: [
              APIStationItem(
                sortOrder: 0, station: nil,
                urlStation: UrlStation(
                  id: "different-station",
                  name: "Different Station",
                  streamUrl: "https://different.stream.url",
                  imageUrl: "https://different.image.url",
                  description: "A different station",
                  website: nil,
                  location: "Different City, TX",
                  active: true,
                  createdAt: Date(),
                  updatedAt: Date()
                ))
            ])
        ])
    }

    XCTAssertEqual(model.forYouStations.elements.count, 1)
    XCTAssertEqual(model.forYouStations.elements.first?.id, "different-station")
  }

  func testStationListItemVisibilityDecodesKnownValue() throws {
    let jsonData = "\"coming-soon\"".data(using: .utf8)!
    let visibility = try JSONDecoder().decode(StationListItemVisibility.self, from: jsonData)
    XCTAssertEqual(visibility, .comingSoon)
  }

  func testStationListItemVisibilityDecodesUnknownValueAsUnknown() throws {
    let jsonData = "\"future-release\"".data(using: .utf8)!
    let visibility = try JSONDecoder().decode(StationListItemVisibility.self, from: jsonData)
    XCTAssertEqual(visibility, .unknown)
  }

  func testStationListStationsFiltersByVisibility() {
    let fixture = makeVisibilityFixture()

    let visibleItems = fixture.list.stationItems(includeHidden: false)
    XCTAssertEqual(visibleItems.count, 2)
    XCTAssertTrue(
      visibleItems.allSatisfy {
        $0.visibility != StationListItemVisibility.hidden
          && $0.visibility != StationListItemVisibility.comingSoon
      }
    )

    let visibleStations = visibleItems.compactMap { $0.anyStation }
    XCTAssertEqual(visibleStations.count, 2)
    if case let .playola(station) = visibleStations[0] {
      XCTAssertEqual(station.id, fixture.visiblePlayola.id)
    } else {
      XCTFail("Expected first visible station to be playola")
    }

    if case let .playola(station) = visibleStations[1] {
      XCTAssertEqual(station.id, fixture.unknownPlayola.id)
    } else {
      XCTFail("Expected second visible station to be playola")
    }

    XCTAssertEqual(
      fixture.items.filter { $0.visibility == StationListItemVisibility.comingSoon }.count,
      1
    )
    let allItemsIncludingHidden = fixture.list.stationItems(includeHidden: true)
    XCTAssertTrue(allItemsIncludingHidden.contains { $0.visibility == .hidden })

    let hiddenItems = allItemsIncludingHidden.filter {
      $0.visibility == StationListItemVisibility.hidden
    }
    XCTAssertEqual(hiddenItems.count, 1)
    XCTAssertEqual(hiddenItems.first?.urlStation?.id, fixture.hiddenUrl.id)
  }

  // MARK: - Welcome Message Tests

  func testWelcomeMessage_ShowsGenericWelcomeMessageWhenNoUserIsLoggedIn() {
    @Shared(.auth) var auth = Auth()
    let model = HomePageModel()
    XCTAssertEqual(model.welcomeMessage, "Welcome to Playola")
  }

  // Helper function to create valid JWT tokens for testing
  static func createTestJWT(
    id: String = "test-user-123",
    firstName: String = "John",
    lastName: String? = "Doe",
    email: String = "john@example.com",
    profileImageUrl: String? = nil,
    role: String = "user"
  ) -> String {
    let header = ["alg": "HS256", "typ": "JWT"]
    var payload: [String: Any] = [
      "id": id,
      "firstName": firstName,
      "email": email,
      "role": role,
    ]
    if let lastName = lastName {
      payload["lastName"] = lastName
    }
    if let profileImageUrl = profileImageUrl {
      payload["profileImageUrl"] = profileImageUrl
    }

    let headerData = try! JSONSerialization.data(withJSONObject: header)
    let payloadData = try! JSONSerialization.data(withJSONObject: payload)

    let headerString = headerData.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")

    let payloadString = payloadData.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")

    return "\(headerString).\(payloadString).fake_signature"
  }

  func testWelcomeMessage_ShowsPersonalizedWelcomeMessageWhenUserIsLoggedIn() {
    let mockJWT = HomePageTests.createTestJWT(firstName: "John")
    @Shared(.auth) var auth = Auth(jwtToken: mockJWT)
    let model = HomePageModel()
    XCTAssertEqual(model.welcomeMessage, "Welcome, John")
  }

  func testWelcomeMessage_UpdatesWelcomeMessageWhenAuthChanges() {
    @Shared(.auth) var auth = Auth()
    let model = HomePageModel()
    XCTAssertEqual(model.welcomeMessage, "Welcome to Playola")

    let mockJWT = HomePageTests.createTestJWT(firstName: "John")
    $auth.withLock { $0 = Auth(jwtToken: mockJWT) }
    XCTAssertEqual(model.welcomeMessage, "Welcome, John")
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

  // MARK: - Listening Tile Navigation Tests

  func testListeningTile_NavigationToRewardsTracksAnalytics() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    @Shared(.activeTab) var activeTab = MainContainerModel.ActiveTab.home

    let homePageModel = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      HomePageModel()
    }

    // Call the button action on the listening tile model
    await homePageModel.listeningTimeTileModel.buttonAction?()

    // Verify navigation happened
    XCTAssertEqual(activeTab, .rewards)

    // Verify analytics event was tracked
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events.first, .navigatedToRewardsFromListeningTile)
  }

  // MARK: - Player Interaction Tests

  func testPlayerInteraction_PlaysAStationWhenItIsTapped() async {
    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let station: AnyStation = .mock
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let homePageModel = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      HomePageModel(stationPlayer: stationPlayerMock)
    }

    await homePageModel.handleStationTapped(station)

    XCTAssertEqual(stationPlayerMock.callsToPlay.count, 1)
    XCTAssertEqual(stationPlayerMock.callsToPlay.first?.id, station.id)

    // Verify analytics event was tracked
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 1)
    if case .startedStation(let stationInfo, let entryPoint) = events.first {
      XCTAssertEqual(stationInfo.id, station.id)
      XCTAssertEqual(stationInfo.name, station.name)
      XCTAssertEqual(entryPoint, "home_recommendations")
    } else {
      XCTFail("Expected startedStation event, got: \(String(describing: events.first))")
    }
  }
}

extension HomePageTests {
  fileprivate struct VisibilityFixture {
    let list: StationList
    let visiblePlayola: PlayolaPlayer.Station
    let unknownPlayola: PlayolaPlayer.Station
    let comingSoonUrl: UrlStation
    let hiddenUrl: UrlStation
    let items: [APIStationItem]
  }

  fileprivate func makeVisibilityFixture() -> VisibilityFixture {
    let now = Date(timeIntervalSince1970: 1_758_915_200)

    let visiblePlayola = PlayolaPlayer.Station(
      id: "visible-playola",
      name: "Visible Playola",
      curatorName: "DJ Visible",
      imageUrl: URL(string: "https://example.com/visible.png"),
      description: "Visible station",
      active: true,
      createdAt: now,
      updatedAt: now
    )

    let unknownPlayola = PlayolaPlayer.Station(
      id: "unknown-playola",
      name: "Unknown Playola",
      curatorName: "DJ Mystery",
      imageUrl: nil as URL?,
      description: "Unknown visibility treated as visible",
      active: true,
      createdAt: now,
      updatedAt: now
    )

    let comingSoonUrl = UrlStation(
      id: "coming-soon-url",
      name: "Coming Soon FM",
      streamUrl: "https://example.com/coming",
      imageUrl: URL(string: "https://example.com/coming.png"),
      description: "Coming soon station",
      website: nil,
      location: "Austin, TX",
      active: true,
      createdAt: now,
      updatedAt: now
    )

    let hiddenUrl = UrlStation(
      id: "hidden-url",
      name: "Hidden FM",
      streamUrl: "https://example.com/hidden",
      imageUrl: URL(string: "https://example.com/hidden.png"),
      description: "Hidden station",
      website: nil,
      location: "Dallas, TX",
      active: true,
      createdAt: now,
      updatedAt: now
    )

    let items: [APIStationItem] = [
      APIStationItem(
        sortOrder: 0,
        visibility: .visible,
        station: visiblePlayola,
        urlStation: nil
      ),
      APIStationItem(
        sortOrder: 1,
        visibility: .comingSoon,
        station: nil,
        urlStation: comingSoonUrl
      ),
      APIStationItem(
        sortOrder: 2,
        visibility: .hidden,
        station: nil,
        urlStation: hiddenUrl
      ),
      APIStationItem(
        sortOrder: 3,
        visibility: .unknown,
        station: unknownPlayola,
        urlStation: nil
      ),
    ]

    let list = StationList(
      id: "test-list",
      name: "Test List",
      slug: "test-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: items
    )

    return VisibilityFixture(
      list: list,
      visiblePlayola: visiblePlayola,
      unknownPlayola: unknownPlayola,
      comingSoonUrl: comingSoonUrl,
      hiddenUrl: hiddenUrl,
      items: items
    )
  }
}

// swiftlint:enable force_try
