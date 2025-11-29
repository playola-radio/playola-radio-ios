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

private let homePageTestDate = Date(timeIntervalSince1970: 1_758_915_200)

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
                )
              )
            ]
          )
        ])
    }

    XCTAssertEqual(model.forYouStations.elements.count, 1)
    XCTAssertEqual(model.forYouStations.elements.first?.id, "different-station")
  }

  func testViewAppeared_ExcludesComingSoonStationsFromForYouList() async {
    let visibleStation = makePlayolaStation(
      id: "visible-station",
      name: "Visible Station",
      curatorName: "DJ Visible"
    )
    let comingSoonItem = makeStationItem(
      sortOrder: 1,
      visibility: .comingSoon,
      urlStation: makeUrlStation(
        id: "coming-soon-station",
        name: "Coming Soon Station",
        streamUrl: "https://example.com/comingSoon",
        imageUrl: "https://example.com/comingsoon.png",
        description: "Coming soon station description",
        location: "Austin, TX"
      )
    )

    let artistList = makeArtistList(
      items: [
        makeStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: visibleStation
        ),
        comingSoonItem,
      ]
    )

    @Shared(.stationLists) var stationLists = IdentifiedArray(uniqueElements: [artistList])

    let model = HomePageModel()
    await model.viewAppeared()

    await assertEventually(model.forYouStations.count == 1)
    XCTAssertEqual(model.forYouStations.first?.id, visibleStation.id)
    XCTAssertNil(model.forYouStations[id: "coming-soon-station"])
  }

  func testShowSecretStationsIncludesActiveComingSoonStations() async {
    let visibleStation = makePlayolaStation(
      id: "visible-station",
      name: "Visible Station",
      curatorName: "DJ Visible"
    )
    let comingSoonStation = makePlayolaStation(
      id: "coming-soon-station",
      name: "Coming Soon Station",
      curatorName: "DJ Soon",
      imageUrl: URL(string: "https://example.com/comingsoon.png"),
      description: "Coming soon station description"
    )

    let artistList = makeArtistList(
      items: [
        makeStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: visibleStation
        ),
        makeStationItem(
          sortOrder: 1,
          visibility: .comingSoon,
          station: comingSoonStation
        ),
      ]
    )

    @Shared(.stationLists) var stationLists = IdentifiedArray(uniqueElements: [artistList])
    @Shared(.showSecretStations) var showSecretStations = false

    let model = HomePageModel()
    await model.viewAppeared()

    await assertEventually(model.forYouStations.count == 1)
    XCTAssertNil(model.forYouStations[id: comingSoonStation.id])

    $showSecretStations.withLock { $0 = true }

    await assertEventually(model.forYouStations[id: comingSoonStation.id] != nil)
    await assertEventually(model.forYouStations.count == 2)
  }

  func testShowSecretStationsStillHidesInactiveComingSoonStations() async {
    let visibleStation = makePlayolaStation(
      id: "visible-station",
      name: "Visible Station",
      curatorName: "DJ Visible"
    )
    let inactiveComingSoonStation = makePlayolaStation(
      id: "inactive-coming-soon",
      name: "Inactive Coming Soon",
      curatorName: "DJ Snooze",
      imageUrl: URL(string: "https://example.com/inactive.png"),
      description: "Inactive coming soon description",
      active: false
    )

    let artistList = makeArtistList(
      items: [
        makeStationItem(
          sortOrder: 0,
          visibility: .visible,
          station: visibleStation
        ),
        makeStationItem(
          sortOrder: 1,
          visibility: .comingSoon,
          station: inactiveComingSoonStation
        ),
      ]
    )

    @Shared(.stationLists) var stationLists = IdentifiedArray(uniqueElements: [artistList])
    @Shared(.showSecretStations) var showSecretStations = true

    let model = HomePageModel()
    await model.viewAppeared()

    await assertEventually(model.forYouStations.count == 1)
    XCTAssertNil(model.forYouStations[id: inactiveComingSoonStation.id])
  }

  func testStationListItemVisibilityDecodesKnownValue() throws {
    let jsonData = Data("\"coming-soon\"".utf8)
    let visibility = try JSONDecoder().decode(StationListItemVisibility.self, from: jsonData)
    XCTAssertEqual(visibility, .comingSoon)
  }

  func testStationListItemVisibilityDecodesUnknownValueAsUnknown() throws {
    let jsonData = Data("\"future-release\"".utf8)
    let visibility = try JSONDecoder().decode(StationListItemVisibility.self, from: jsonData)
    XCTAssertEqual(visibility, .unknown)
  }

  func testStationListStationsFiltersByVisibility() {
    let fixture = makeVisibilityFixture()

    let visibleItems = fixture.list.stationItems(includeHidden: false)
    XCTAssertEqual(visibleItems.map(\.visibility), [.visible, .comingSoon, .unknown])

    let visibleStations = visibleItems.map { $0.anyStation }
    XCTAssertEqual(visibleStations.count, 3)
    if case .playola(let station) = visibleStations[0] {
      XCTAssertEqual(station.id, fixture.visiblePlayola.id)
    } else {
      XCTFail("Expected first visible station to be playola")
    }

    if case .url(let station) = visibleStations[1] {
      XCTAssertEqual(station.id, fixture.comingSoonUrl.id)
    } else {
      XCTFail("Expected second visible station to be coming soon url station")
    }

    if case .playola(let station) = visibleStations[2] {
      XCTAssertEqual(station.id, fixture.unknownPlayola.id)
    } else {
      XCTFail("Expected second visible station to be playola")
    }

    let allItemsIncludingHidden = fixture.list.stationItems(includeHidden: true)
    let comingSoonItems = allItemsIncludingHidden.filter { $0.visibility == .comingSoon }
    XCTAssertEqual(comingSoonItems.count, 1)
    XCTAssertEqual(comingSoonItems.first?.urlStation?.id, fixture.comingSoonUrl.id)

    let hiddenItems = allItemsIncludingHidden.filter { $0.visibility == .hidden }
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

  func testShowSecretStationsToggleUpdatesForYouStations() async {
    @Shared(.stationLists) var stationLists =
      IdentifiedArray(uniqueElements: [makeArtistListWithHiddenStation()])
    @Shared(.showSecretStations) var showSecretStations = false

    let model = HomePageModel()
    await model.viewAppeared()

    await assertEventually(model.forYouStations.count == 1)

    $showSecretStations.withLock { $0 = true }
    await assertEventually(model.forYouStations.count == 2)

    $showSecretStations.withLock { $0 = false }
    await assertEventually(model.forYouStations.count == 1)
  }

  // MARK: - Live Shows Tests

  func testLiveShows_HasLiveShowsReturnsTrueWhenLiveShowExists() async {
    await withDependencies {
      $0.date.now = Date()
    } operation: {
      @Dependency(\.date.now) var now
      @Shared(.scheduledShows) var scheduledShows: IdentifiedArrayOf<ScheduledShow> = []

      let showDurationInSeconds = TimeInterval(Show.mock.durationMS) / 1000.0
      let timeAgo = showDurationInSeconds / 2

      let liveShow = ScheduledShow(
        id: "live-show-1",
        showId: "show-1",
        stationId: "station-1",
        airtime: now.addingTimeInterval(-timeAgo),
        createdAt: now,
        updatedAt: now,
        show: Show.mock,
        station: nil
      )

      $scheduledShows.withLock { $0 = IdentifiedArray(uniqueElements: [liveShow]) }

      let model = HomePageModel()
      XCTAssertTrue(model.hasLiveShows)
    }
  }

  func testLiveShows_HasLiveShowsReturnsFalseWhenNoScheduledShows() async {
    @Shared(.scheduledShows) var scheduledShows: IdentifiedArrayOf<ScheduledShow> = []

    let model = HomePageModel()
    XCTAssertFalse(model.hasLiveShows)
  }

  func testLiveShows_HasLiveShowsReturnsFalseWhenAllShowsHaveEnded() async {
    await withDependencies {
      $0.date.now = Date()
    } operation: {
      @Dependency(\.date.now) var now
      @Shared(.scheduledShows) var scheduledShows: IdentifiedArrayOf<ScheduledShow> = []

      let showDurationInSeconds = TimeInterval(Show.mock.durationMS) / 1000.0
      let endedShow = ScheduledShow(
        id: "ended-show-1",
        showId: "show-1",
        stationId: "station-1",
        airtime: now.addingTimeInterval(-(showDurationInSeconds + 3600)),
        createdAt: now,
        updatedAt: now,
        show: Show.mock,
        station: nil
      )

      $scheduledShows.withLock { $0 = IdentifiedArray(uniqueElements: [endedShow]) }

      let model = HomePageModel()
      XCTAssertFalse(model.hasLiveShows)
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

  private struct VisibilityStations {
    let visiblePlayola: PlayolaPlayer.Station
    let unknownPlayola: PlayolaPlayer.Station
    let comingSoonUrl: UrlStation
    let hiddenUrl: UrlStation
  }

  fileprivate func makeVisibilityFixture() -> VisibilityFixture {
    let now = Date(timeIntervalSince1970: 1_758_915_200)
    let stations = makeVisibilityStations(date: now)
    let items = makeVisibilityItems(from: stations)

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
      visiblePlayola: stations.visiblePlayola,
      unknownPlayola: stations.unknownPlayola,
      comingSoonUrl: stations.comingSoonUrl,
      hiddenUrl: stations.hiddenUrl,
      items: items
    )
  }

  fileprivate func makeArtistListWithHiddenStation() -> StationList {
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

    let hiddenPlayola = PlayolaPlayer.Station(
      id: "hidden-playola",
      name: "Hidden Playola",
      curatorName: "DJ Hidden",
      imageUrl: URL(string: "https://example.com/hidden.png"),
      description: "Hidden station",
      active: true,
      createdAt: now,
      updatedAt: now
    )

    let items: [APIStationItem] = [
      APIStationItem(sortOrder: 0, visibility: .visible, station: visiblePlayola, urlStation: nil),
      APIStationItem(sortOrder: 1, visibility: .hidden, station: hiddenPlayola, urlStation: nil),
    ]

    return StationList(
      id: StationList.KnownIDs.artistList.rawValue,
      name: "Artists",
      slug: StationList.artistListSlug,
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: items
    )
  }

  private func makeVisibilityStations(date: Date) -> VisibilityStations {
    let visiblePlayola = PlayolaPlayer.Station(
      id: "visible-playola",
      name: "Visible Playola",
      curatorName: "DJ Visible",
      imageUrl: URL(string: "https://example.com/visible.png"),
      description: "Visible station",
      active: true,
      createdAt: date,
      updatedAt: date
    )

    let unknownPlayola = PlayolaPlayer.Station(
      id: "unknown-playola",
      name: "Unknown Playola",
      curatorName: "DJ Mystery",
      imageUrl: nil as URL?,
      description: "Unknown visibility treated as visible",
      active: true,
      createdAt: date,
      updatedAt: date
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
      createdAt: date,
      updatedAt: date
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
      createdAt: date,
      updatedAt: date
    )

    return VisibilityStations(
      visiblePlayola: visiblePlayola,
      unknownPlayola: unknownPlayola,
      comingSoonUrl: comingSoonUrl,
      hiddenUrl: hiddenUrl
    )
  }

  private func makeVisibilityItems(from stations: VisibilityStations) -> [APIStationItem] {
    [
      APIStationItem(
        sortOrder: 0,
        visibility: .visible,
        station: stations.visiblePlayola,
        urlStation: nil
      ),
      APIStationItem(
        sortOrder: 1,
        visibility: .comingSoon,
        station: nil,
        urlStation: stations.comingSoonUrl
      ),
      APIStationItem(
        sortOrder: 2,
        visibility: .hidden,
        station: nil,
        urlStation: stations.hiddenUrl
      ),
      APIStationItem(
        sortOrder: 3,
        visibility: .unknown,
        station: stations.unknownPlayola,
        urlStation: nil
      ),
    ]
  }

  fileprivate func makeArtistList(items: [APIStationItem]) -> StationList {
    StationList(
      id: StationList.KnownIDs.artistList.rawValue,
      name: "Artists",
      slug: StationList.artistListSlug,
      hidden: false,
      sortOrder: 0,
      createdAt: homePageTestDate,
      updatedAt: homePageTestDate,
      items: items
    )
  }

  fileprivate func makeStationItem(
    sortOrder: Int,
    visibility: StationListItemVisibility,
    station: PlayolaPlayer.Station? = nil,
    urlStation: UrlStation? = nil
  ) -> APIStationItem {
    APIStationItem(
      sortOrder: sortOrder,
      visibility: visibility,
      station: station,
      urlStation: urlStation
    )
  }

  fileprivate func makePlayolaStation(
    id: String,
    name: String,
    curatorName: String,
    imageUrl: URL? = URL(string: "https://example.com/visible.png"),
    description: String = "Visible station description",
    active: Bool = true
  ) -> PlayolaPlayer.Station {
    PlayolaPlayer.Station(
      id: id,
      name: name,
      curatorName: curatorName,
      imageUrl: imageUrl,
      description: description,
      active: active,
      createdAt: homePageTestDate,
      updatedAt: homePageTestDate
    )
  }

  fileprivate func makeUrlStation(
    id: String,
    name: String,
    streamUrl: String,
    imageUrl: String,
    description: String,
    website: String? = nil,
    location: String? = nil,
    active: Bool = true
  ) -> UrlStation {
    UrlStation(
      id: id,
      name: name,
      streamUrl: streamUrl,
      imageUrl: imageUrl,
      description: description,
      website: website,
      location: location,
      active: active,
      createdAt: homePageTestDate,
      updatedAt: homePageTestDate
    )
  }
}

// swiftlint:enable force_try

extension HomePageTests {
  fileprivate func assertEventually(
    _ condition: @autoclosure @escaping () -> Bool,
    timeout: TimeInterval = 1.0,
    file: StaticString = #fileID,
    line: UInt = #line
  ) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() { return }
      try? await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTFail("Condition not satisfied within timeout", file: file, line: line)
  }
}
