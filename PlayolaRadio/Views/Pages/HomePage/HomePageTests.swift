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
    let visibleStation = Station.mockWith(
      id: "visible-station", name: "Visible Station", curatorName: "DJ Visible")
    let artistList = StationList.mockArtistList(items: [
      .mockWith(sortOrder: 0, visibility: .visible, station: visibleStation),
      .mockWith(
        sortOrder: 1, visibility: .comingSoon, urlStation: .mockWith(id: "coming-soon-station")),
    ])

    @Shared(.stationLists) var stationLists = IdentifiedArray(uniqueElements: [artistList])

    let model = HomePageModel()
    await model.viewAppeared()

    XCTAssertEqual(model.forYouStations.count, 1)
    XCTAssertEqual(model.forYouStations.first?.id, visibleStation.id)
    XCTAssertNil(model.forYouStations[id: "coming-soon-station"])
  }

  func testShowSecretStationsIncludesActiveComingSoonStations() async {
    let visibleStation = Station.mockWith(id: "visible-station", curatorName: "DJ Visible")
    let comingSoonStation = Station.mockWith(id: "coming-soon-station", curatorName: "DJ Soon")
    let artistList = StationList.mockArtistList(items: [
      .mockWith(sortOrder: 0, visibility: .visible, station: visibleStation),
      .mockWith(sortOrder: 1, visibility: .comingSoon, station: comingSoonStation),
    ])

    @Shared(.stationLists) var stationLists = IdentifiedArray(uniqueElements: [artistList])
    @Shared(.showSecretStations) var showSecretStations = false

    let model = HomePageModel()
    await model.viewAppeared()

    XCTAssertEqual(model.forYouStations.count, 1)
    XCTAssertNil(model.forYouStations[id: comingSoonStation.id])

    $showSecretStations.withLock { $0 = true }

    XCTAssertNotNil(model.forYouStations[id: comingSoonStation.id])
    XCTAssertEqual(model.forYouStations.count, 2)
  }

  func testShowSecretStationsStillHidesInactiveComingSoonStations() async {
    let visibleStation = Station.mockWith(id: "visible-station", curatorName: "DJ Visible")
    let inactiveStation = Station.mockWith(
      id: "inactive-coming-soon", curatorName: "DJ Snooze", active: false)
    let artistList = StationList.mockArtistList(items: [
      .mockWith(sortOrder: 0, visibility: .visible, station: visibleStation),
      .mockWith(sortOrder: 1, visibility: .comingSoon, station: inactiveStation),
    ])

    @Shared(.stationLists) var stationLists = IdentifiedArray(uniqueElements: [artistList])
    @Shared(.showSecretStations) var showSecretStations = true

    let model = HomePageModel()
    await model.viewAppeared()

    XCTAssertEqual(model.forYouStations.count, 1)
    XCTAssertNil(model.forYouStations[id: inactiveStation.id])
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
    let visiblePlayola = Station.mockWith(id: "visible-playola")
    let unknownPlayola = Station.mockWith(id: "unknown-playola")
    let comingSoonUrl = UrlStation.mockWith(id: "coming-soon-url")
    let hiddenUrl = UrlStation.mockWith(id: "hidden-url")

    let list = StationList(
      id: "test-list", name: "Test List", slug: "test-list", hidden: false, sortOrder: 0,
      createdAt: Date(), updatedAt: Date(),
      items: [
        .mockWith(sortOrder: 0, visibility: .visible, station: visiblePlayola),
        .mockWith(sortOrder: 1, visibility: .comingSoon, urlStation: comingSoonUrl),
        .mockWith(sortOrder: 2, visibility: .hidden, urlStation: hiddenUrl),
        .mockWith(sortOrder: 3, visibility: .unknown, station: unknownPlayola),
      ]
    )

    let visibleItems = list.stationItems(includeHidden: false)
    XCTAssertEqual(visibleItems.map(\.visibility), [.visible, .comingSoon, .unknown])

    let visibleStations = visibleItems.map { $0.anyStation }
    XCTAssertEqual(visibleStations.count, 3)
    if case .playola(let station) = visibleStations[0] {
      XCTAssertEqual(station.id, visiblePlayola.id)
    } else {
      XCTFail("Expected first visible station to be playola")
    }

    if case .url(let station) = visibleStations[1] {
      XCTAssertEqual(station.id, comingSoonUrl.id)
    } else {
      XCTFail("Expected second visible station to be coming soon url station")
    }

    if case .playola(let station) = visibleStations[2] {
      XCTAssertEqual(station.id, unknownPlayola.id)
    } else {
      XCTFail("Expected second visible station to be playola")
    }

    let allItemsIncludingHidden = list.stationItems(includeHidden: true)
    let comingSoonItems = allItemsIncludingHidden.filter { $0.visibility == .comingSoon }
    XCTAssertEqual(comingSoonItems.count, 1)
    XCTAssertEqual(comingSoonItems.first?.urlStation?.id, comingSoonUrl.id)

    let hiddenItems = allItemsIncludingHidden.filter { $0.visibility == .hidden }
    XCTAssertEqual(hiddenItems.count, 1)
    XCTAssertEqual(hiddenItems.first?.urlStation?.id, hiddenUrl.id)
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
    homePage.playolaIconTapped10Times()
    XCTAssertTrue(homePage.showSecretStations)
    XCTAssertEqual(homePage.presentedAlert, .secretStationsTurnedOnAlert)
  }

  func testTappingTheP_HidesTheSecretStations() {
    @Shared(.showSecretStations) var showSecretStations = true
    let homePage = HomePageModel()
    XCTAssertTrue(homePage.showSecretStations)
    homePage.playolaIconTapped10Times()
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

    await homePageModel.stationTapped(station)

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
    let artistList = StationList.mockArtistList(items: [
      .mockWith(sortOrder: 0, visibility: .visible, station: .mockWith(id: "visible-playola")),
      .mockWith(sortOrder: 1, visibility: .hidden, station: .mockWith(id: "hidden-playola")),
    ])
    @Shared(.stationLists) var stationLists = IdentifiedArray(uniqueElements: [artistList])
    @Shared(.showSecretStations) var showSecretStations = false

    let model = HomePageModel()
    await model.viewAppeared()

    XCTAssertEqual(model.forYouStations.count, 1)

    $showSecretStations.withLock { $0 = true }
    XCTAssertEqual(model.forYouStations.count, 2)

    $showSecretStations.withLock { $0 = false }
    XCTAssertEqual(model.forYouStations.count, 1)
  }

  // MARK: - Scheduled Shows Tests

  func testViewAppearedSetsHasScheduledShowsToTrueWhenAiringsExist() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()

    let futureAiring = Airing.mockWith(
      id: "future-airing",
      airtime: now.addingTimeInterval(3600),
      episode: .mockWith(durationMS: 3_600_000)
    )

    await withDependencies {
      $0.date.now = now
      $0.api.getAirings = { _, _ in [futureAiring] }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertTrue(model.hasScheduledShows)
    }
  }

  func testViewAppearedSetsHasScheduledShowsToFalseWhenNoAirings() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.getAirings = { _, _ in [] }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertFalse(model.hasScheduledShows)
    }
  }

  func testViewAppearedSetsHasScheduledShowsToFalseOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.getAirings = { _, _ in
        throw APIError.dataNotValid
      }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertFalse(model.hasScheduledShows)
    }
  }

  func testScheduledShowsTileNavigatesToSeriesListPage() async {
    @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator =
      MainContainerNavigationCoordinator()

    let model = HomePageModel()

    await model.scheduledShowsTileModel.buttonAction?()

    XCTAssertEqual(navigationCoordinator.path.count, 1)
    if case .seriesListPage = navigationCoordinator.path.first {
      // Success
    } else {
      XCTFail(
        "Expected seriesListPage, got: \(String(describing: navigationCoordinator.path.first))")
    }
  }

  func testViewAppearedSetsHasScheduledShowsToFalseWhenAllAiringsEnded() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()

    let endedAirings = [
      Airing.mockWith(
        id: "ended-1",
        airtime: now.addingTimeInterval(-7200),
        episode: .mockWith(durationMS: 3_600_000)
      ),
      Airing.mockWith(
        id: "ended-2",
        airtime: now.addingTimeInterval(-3600),
        episode: .mockWith(durationMS: 1_800_000)
      ),
    ]

    await withDependencies {
      $0.date.now = now
      $0.api.getAirings = { _, _ in endedAirings }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertFalse(model.hasScheduledShows)
    }
  }

  // MARK: - Listener Question Airing Tests

  func testViewAppearedSetsUpcomingQuestionAiringWhenAiringsExist() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let futureDate = Date().addingTimeInterval(2 * 24 * 60 * 60)
    let expectedAiring = ListenerQuestionAiring.mockWith(
      id: "airing-1",
      airtime: futureDate,
      station: .mockWith(curatorName: "DJ Test")
    )

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in [expectedAiring] }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertNotNil(model.upcomingQuestionAiring)
      XCTAssertEqual(model.upcomingQuestionAiring?.id, expectedAiring.id)
      XCTAssertTrue(model.hasUpcomingQuestionAiring)
    }
  }

  func testViewAppearedSetsUpcomingQuestionAiringToNilWhenNoAirings() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in [] }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertNil(model.upcomingQuestionAiring)
      XCTAssertFalse(model.hasUpcomingQuestionAiring)
    }
  }

  func testViewAppearedSetsUpcomingQuestionAiringToNilOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in
        throw APIError.dataNotValid
      }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertNil(model.upcomingQuestionAiring)
      XCTAssertFalse(model.hasUpcomingQuestionAiring)
    }
  }

  func testViewAppearedDoesNotCheckAiringsWhenNotLoggedIn() async {
    @Shared(.auth) var auth = Auth()
    var apiCalled = false

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in
        apiCalled = true
        return []
      }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertFalse(apiCalled)
      XCTAssertNil(model.upcomingQuestionAiring)
    }
  }

  func testQuestionAiringTileShowsStationNameAndAirtime() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let futureDate = Date().addingTimeInterval(2 * 24 * 60 * 60)
    let airing = ListenerQuestionAiring.mockWith(
      airtime: futureDate,
      station: .mockWith(curatorName: "DJ Awesome")
    )

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in [airing] }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertEqual(model.questionAiringTileModel.content, "You're On Air Soon!")
      XCTAssertTrue(
        model.questionAiringTileModel.paragraph!.contains("DJ Awesome picked your question!"))
    }
  }

  // MARK: - Question Airing Share Tests

  func testQuestionAiringShareButtonPresentsShareSheetWithReferralCode() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator =
      MainContainerNavigationCoordinator()

    let futureDate = Date().addingTimeInterval(2 * 24 * 60 * 60)
    let airing = ListenerQuestionAiring.mockWith(
      airtime: futureDate,
      station: .mockWith(curatorName: "Jason Eady")
    )
    let mockReferralCode = ReferralCode(
      id: "ref-123",
      code: "JASON-ABCD",
      createdByUserId: "user-123",
      invitationCodeId: "inv-123",
      maxUses: nil,
      description: nil,
      expiresAt: futureDate.addingTimeInterval(24 * 60 * 60),
      isActive: true,
      createdAt: Date(),
      updatedAt: Date()
    )

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in [airing] }
      $0.api.getOrCreateReferralCode = { _, _ in mockReferralCode }
    } operation: {
      let model = HomePageModel()
      await model.viewAppeared()

      await model.questionAiringTileModel.buttonAction?()

      if case .share(let shareModel) = navigationCoordinator.presentedSheet {
        XCTAssertTrue(shareModel.items[0].contains("Jason Eady's radio station"))
        XCTAssertTrue(shareModel.items[1].contains("JASON-ABCD"))
      } else {
        XCTFail("Expected share sheet to be presented")
      }
    }
  }

  func testQuestionAiringShareButtonUsesGenericMessageWhenNoCuratorName() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator =
      MainContainerNavigationCoordinator()

    let futureDate = Date().addingTimeInterval(2 * 24 * 60 * 60)
    let airing = ListenerQuestionAiring.mockWith(
      airtime: futureDate,
      station: nil
    )
    let mockReferralCode = ReferralCode(
      id: "ref-123",
      code: "USER-ABCD",
      createdByUserId: "user-123",
      invitationCodeId: "inv-123",
      maxUses: nil,
      description: nil,
      expiresAt: futureDate.addingTimeInterval(24 * 60 * 60),
      isActive: true,
      createdAt: Date(),
      updatedAt: Date()
    )

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in [airing] }
      $0.api.getOrCreateReferralCode = { _, _ in mockReferralCode }
    } operation: {
      let model = HomePageModel()
      await model.viewAppeared()

      await model.questionAiringTileModel.buttonAction?()

      if case .share(let shareModel) = navigationCoordinator.presentedSheet {
        XCTAssertTrue(shareModel.items[0].contains("an internet radio station"))
      } else {
        XCTFail("Expected share sheet to be presented")
      }
    }
  }

  func testQuestionAiringShareButtonShowsErrorAlertOnFailure() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator =
      MainContainerNavigationCoordinator()

    let futureDate = Date().addingTimeInterval(2 * 24 * 60 * 60)
    let airing = ListenerQuestionAiring.mockWith(
      airtime: futureDate,
      station: .mockWith(curatorName: "DJ Test")
    )

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in [airing] }
      $0.api.getOrCreateReferralCode = { _, _ in
        throw APIError.dataNotValid
      }
    } operation: {
      let model = HomePageModel()
      await model.viewAppeared()

      await model.questionAiringTileModel.buttonAction?()

      XCTAssertNil(navigationCoordinator.presentedSheet)
      XCTAssertEqual(model.presentedAlert, .errorCreatingReferralCode)
    }
  }

  // MARK: - Invite Friends Tile Tests

  func testCanInviteFriendsIsTrueWhenUserHasTwoOrMoreHours() {
    let rewardsProfile = RewardsProfile(
      totalTimeListenedMS: 2 * 60 * 60 * 1000,  // 2 hours
      totalMSAvailableForRewards: 0,
      accurateAsOfTime: Date()
    )
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = ListeningTracker(
      rewardsProfile: rewardsProfile)

    let model = HomePageModel()

    XCTAssertTrue(model.canInviteFriends)
  }

  func testCanInviteFriendsIsFalseWhenUserHasLessThanTwoHours() {
    let rewardsProfile = RewardsProfile(
      totalTimeListenedMS: 1 * 60 * 60 * 1000,  // 1 hour
      totalMSAvailableForRewards: 0,
      accurateAsOfTime: Date()
    )
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = ListeningTracker(
      rewardsProfile: rewardsProfile)

    let model = HomePageModel()

    XCTAssertFalse(model.canInviteFriends)
  }

  func testCanInviteFriendsIsFalseWhenListeningTrackerIsNil() {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker?

    let model = HomePageModel()

    XCTAssertFalse(model.canInviteFriends)
  }

  func testInviteFriendsTileHasCorrectContent() {
    let model = HomePageModel()

    XCTAssertEqual(model.inviteFriendsTileModel.label, "Power Listener Reward")
    XCTAssertEqual(model.inviteFriendsTileModel.content, "Invite Your Friends")
    XCTAssertEqual(model.inviteFriendsTileModel.buttonText, "Invite")
    XCTAssertNotNil(model.inviteFriendsTileModel.paragraph)
  }

  func testInviteFriendsTilePresentsShareSheet() async {
    let rewardsProfile = RewardsProfile(
      totalTimeListenedMS: 3 * 60 * 60 * 1000,  // 3 hours
      totalMSAvailableForRewards: 0,
      accurateAsOfTime: Date()
    )
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = ListeningTracker(
      rewardsProfile: rewardsProfile)
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator =
      MainContainerNavigationCoordinator()

    let mockReferralCode = ReferralCode(
      id: "ref-123",
      code: "INVITE-ABCD",
      createdByUserId: "user-123",
      invitationCodeId: "inv-123",
      maxUses: nil,
      description: nil,
      expiresAt: nil,
      isActive: true,
      createdAt: Date(),
      updatedAt: Date()
    )

    await withDependencies {
      $0.api.getOrCreateReferralCode = { _, _ in mockReferralCode }
    } operation: {
      let model = HomePageModel()

      await model.inviteFriendsTileModel.buttonAction?()

      if case .share(let shareModel) = navigationCoordinator.presentedSheet {
        XCTAssertTrue(shareModel.items[1].contains("INVITE-ABCD"))
      } else {
        XCTFail("Expected share sheet to be presented")
      }
    }
  }

  // MARK: - Past Airing Tests

  func testViewAppearedSetsPastQuestionAiringsWhenPastAiringsExist() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()
    let pastAiring = ListenerQuestionAiring.mockWith(
      id: "past-airing",
      airtime: now.addingTimeInterval(-86400),
      station: .mockWith(curatorName: "DJ Past")
    )

    await withDependencies {
      $0.date.now = now
      $0.api.getMyListenerQuestionAirings = { _ in [pastAiring] }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertTrue(model.hasPastAirings)
      XCTAssertEqual(model.pastQuestionAirings.count, 1)
    }
  }

  func testHasPastAiringsIsFalseWhenNoPastAirings() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()
    let futureAiring = ListenerQuestionAiring.mockWith(
      airtime: now.addingTimeInterval(86400)
    )

    await withDependencies {
      $0.date.now = now
      $0.api.getMyListenerQuestionAirings = { _ in [futureAiring] }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertFalse(model.hasPastAirings)
      XCTAssertTrue(model.pastQuestionAirings.isEmpty)
    }
  }

  func testPastAiringTileIsPersonalizedWithCuratorName() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()
    let pastAiring = ListenerQuestionAiring.mockWith(
      airtime: now.addingTimeInterval(-86400),
      station: .mockWith(curatorName: "DJ Awesome")
    )

    await withDependencies {
      $0.date.now = now
      $0.api.getMyListenerQuestionAirings = { _ in [pastAiring] }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertTrue(model.pastAiringTileModel.paragraph?.contains("DJ Awesome") ?? false)
    }
  }

  func testMyAiringsButtonTappedPushesMyAiringsPage() async {
    @Shared(.mainContainerNavigationCoordinator) var navCoordinator =
      MainContainerNavigationCoordinator()

    let model = HomePageModel()

    model.myAiringsButtonTapped()

    XCTAssertEqual(navCoordinator.path.count, 1)
    if case .myAiringsPage = navCoordinator.path.first {
      // Expected
    } else {
      XCTFail("Expected myAiringsPage to be pushed")
    }
  }

  func testViewAppearedSchedulesLocalNotificationsViaSharedMethod() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()
    let futureAiring = ListenerQuestionAiring.mockWith(
      airtime: now.addingTimeInterval(86400),
      station: .mockWith(curatorName: "DJ Notify")
    )
    var scheduledCount = 0

    await withDependencies {
      $0.date.now = now
      $0.api.getMyListenerQuestionAirings = { _ in [futureAiring] }
      $0.pushNotifications.scheduleNotification = { _, _, _, _ in
        scheduledCount += 1
      }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      XCTAssertEqual(scheduledCount, 1)
    }
  }
}

// swiftlint:enable force_try
