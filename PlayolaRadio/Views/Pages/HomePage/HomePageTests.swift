//
//  HomePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//

// swiftlint:disable force_try

import ConcurrencyExtras
import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

// Helper function to create valid JWT tokens for testing
private func createTestJWT(
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

@MainActor
struct HomePageTests {
  // MARK: - ViewAppeared Tests

  @Test
  func testViewAppearedPopulatesForYouStationsBasedOnInitialValueOfSharedStationLists() async {
    @Shared(.stationLists) var stationLists = StationList.mocks
    let artistStations = stationLists.first {
      $0.slug == StationList.artistListSlug
    }
    #expect(artistStations != nil)
    let model = HomePageModel()
    await model.viewAppeared()
    #expect(model.forYouStations.elements == artistStations!.stations)
  }

  @Test
  func testViewAppearedRepopulatesForYouStationsWhenSharedStationListsChanges() async {
    @Shared(.stationLists) var stationLists = StationList.mocks
    let artistStations = stationLists.first {
      $0.slug == StationList.artistListSlug
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

    #expect(model.forYouStations.elements.count == 1)
    #expect(model.forYouStations.elements.first?.id == "different-station")
  }

  @Test
  func testViewAppearedExcludesComingSoonStationsFromForYouList() async {
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

    #expect(model.forYouStations.count == 1)
    #expect(model.forYouStations.first?.id == visibleStation.id)
    #expect(model.forYouStations[id: "coming-soon-station"] == nil)
  }

  @Test
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

    #expect(model.forYouStations.count == 1)
    #expect(model.forYouStations[id: comingSoonStation.id] == nil)

    $showSecretStations.withLock { $0 = true }

    #expect(model.forYouStations[id: comingSoonStation.id] != nil)
    #expect(model.forYouStations.count == 2)
  }

  @Test
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

    #expect(model.forYouStations.count == 1)
    #expect(model.forYouStations[id: inactiveStation.id] == nil)
  }

  @Test
  func testStationListItemVisibilityDecodesKnownValue() throws {
    let jsonData = Data("\"coming-soon\"".utf8)
    let visibility = try JSONDecoder().decode(StationListItemVisibility.self, from: jsonData)
    #expect(visibility == .comingSoon)
  }

  @Test
  func testStationListItemVisibilityDecodesUnknownValueAsUnknown() throws {
    let jsonData = Data("\"future-release\"".utf8)
    let visibility = try JSONDecoder().decode(StationListItemVisibility.self, from: jsonData)
    #expect(visibility == .unknown)
  }

  @Test
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
    #expect(visibleItems.map(\.visibility) == [.visible, .comingSoon, .unknown])

    let visibleStations = visibleItems.map { $0.anyStation }
    #expect(visibleStations.count == 3)
    if case .playola(let station) = visibleStations[0] {
      #expect(station.id == visiblePlayola.id)
    } else {
      Issue.record("Expected first visible station to be playola")
    }

    if case .url(let station) = visibleStations[1] {
      #expect(station.id == comingSoonUrl.id)
    } else {
      Issue.record("Expected second visible station to be coming soon url station")
    }

    if case .playola(let station) = visibleStations[2] {
      #expect(station.id == unknownPlayola.id)
    } else {
      Issue.record("Expected second visible station to be playola")
    }

    let allItemsIncludingHidden = list.stationItems(includeHidden: true)
    let comingSoonItems = allItemsIncludingHidden.filter { $0.visibility == .comingSoon }
    #expect(comingSoonItems.count == 1)
    #expect(comingSoonItems.first?.urlStation?.id == comingSoonUrl.id)

    let hiddenItems = allItemsIncludingHidden.filter { $0.visibility == .hidden }
    #expect(hiddenItems.count == 1)
    #expect(hiddenItems.first?.urlStation?.id == hiddenUrl.id)
  }

  // MARK: - Welcome Message Tests

  @Test
  func testWelcomeMessageShowsGenericWelcomeMessageWhenNoUserIsLoggedIn() {
    @Shared(.auth) var auth = Auth()
    let model = HomePageModel()
    #expect(model.welcomeMessage == "Welcome to Playola")
  }

  @Test
  func testWelcomeMessageShowsPersonalizedWelcomeMessageWhenUserIsLoggedIn() {
    let mockJWT = createTestJWT(firstName: "John")
    @Shared(.auth) var auth = Auth(jwtToken: mockJWT)
    let model = HomePageModel()
    #expect(model.welcomeMessage == "Welcome, John")
  }

  @Test
  func testWelcomeMessageUpdatesWelcomeMessageWhenAuthChanges() {
    @Shared(.auth) var auth = Auth()
    let model = HomePageModel()
    #expect(model.welcomeMessage == "Welcome to Playola")

    let mockJWT = createTestJWT(firstName: "John")
    $auth.withLock { $0 = Auth(jwtToken: mockJWT) }
    #expect(model.welcomeMessage == "Welcome, John")
  }

  // MARK: - Tapping The P Tests

  @Test
  func testTappingThePTurnsOnTheSecretStations() {
    let homePage = HomePageModel()
    #expect(!homePage.showSecretStations)
    homePage.playolaIconTapped10Times()
    #expect(homePage.showSecretStations)
    #expect(homePage.presentedAlert == .secretStationsTurnedOnAlert)
  }

  @Test
  func testTappingThePHidesTheSecretStations() {
    @Shared(.showSecretStations) var showSecretStations = true
    let homePage = HomePageModel()
    #expect(homePage.showSecretStations)
    homePage.playolaIconTapped10Times()
    #expect(!homePage.showSecretStations)
    #expect(homePage.presentedAlert == .secretStationsHiddenAlert)
  }

  // MARK: - Listening Tile Navigation Tests

  @Test
  func testListeningTileNavigationToRewardsTracksAnalytics() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    @Shared(.activeTab) var activeTab = MainContainerModel.ActiveTab.home

    let homePageModel = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      HomePageModel()
    }

    await homePageModel.listeningTimeTileModel.buttonAction?()

    #expect(activeTab == .rewards)

    let events = capturedEvents.value
    #expect(events.count == 1)
    #expect(events.first == .navigatedToRewardsFromListeningTile)
  }

  // MARK: - Player Interaction Tests

  @Test
  func testPlayerInteractionPlaysAStationWhenItIsTapped() async {
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

    #expect(stationPlayerMock.callsToPlay.count == 1)
    #expect(stationPlayerMock.callsToPlay.first?.id == station.id)

    let events = capturedEvents.value
    #expect(events.count == 1)
    if case .startedStation(let stationInfo, let entryPoint) = events.first {
      #expect(stationInfo.id == station.id)
      #expect(stationInfo.name == station.name)
      #expect(entryPoint == "home_recommendations")
    } else {
      Issue.record("Expected startedStation event, got: \(String(describing: events.first))")
    }
  }

  @Test
  func testShowSecretStationsToggleUpdatesForYouStations() async {
    let artistList = StationList.mockArtistList(items: [
      .mockWith(sortOrder: 0, visibility: .visible, station: .mockWith(id: "visible-playola")),
      .mockWith(sortOrder: 1, visibility: .hidden, station: .mockWith(id: "hidden-playola")),
    ])
    @Shared(.stationLists) var stationLists = IdentifiedArray(uniqueElements: [artistList])
    @Shared(.showSecretStations) var showSecretStations = false

    let model = HomePageModel()
    await model.viewAppeared()

    #expect(model.forYouStations.count == 1)

    $showSecretStations.withLock { $0 = true }
    #expect(model.forYouStations.count == 2)

    $showSecretStations.withLock { $0 = false }
    #expect(model.forYouStations.count == 1)
  }

  // MARK: - Scheduled Shows Tests

  @Test
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

      #expect(model.hasScheduledShows)
    }
  }

  @Test
  func testViewAppearedSetsHasScheduledShowsToFalseWhenNoAirings() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.getAirings = { _, _ in [] }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      #expect(!model.hasScheduledShows)
    }
  }

  @Test
  func testViewAppearedSetsHasScheduledShowsToFalseOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.getAirings = { _, _ in
        throw APIError.dataNotValid
      }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      #expect(!model.hasScheduledShows)
    }
  }

  @Test
  func testScheduledShowsTileNavigatesToSeriesListPage() async {
    @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator =
      MainContainerNavigationCoordinator()

    let model = HomePageModel()

    await model.scheduledShowsTileModel.buttonAction?()

    #expect(navigationCoordinator.path.count == 1)
    if case .seriesListPage = navigationCoordinator.path.first {
      // Success
    } else {
      Issue.record(
        "Expected seriesListPage, got: \(String(describing: navigationCoordinator.path.first))")
    }
  }

  @Test
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

      #expect(!model.hasScheduledShows)
    }
  }

  // MARK: - Listener Question Airing Tests

  @Test
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

      #expect(model.upcomingQuestionAiring != nil)
      #expect(model.upcomingQuestionAiring?.id == expectedAiring.id)
      #expect(model.hasUpcomingQuestionAiring)
    }
  }

  @Test
  func testViewAppearedSetsUpcomingQuestionAiringToNilWhenNoAirings() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in [] }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      #expect(model.upcomingQuestionAiring == nil)
      #expect(!model.hasUpcomingQuestionAiring)
    }
  }

  @Test
  func testViewAppearedSetsUpcomingQuestionAiringToNilOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in
        throw APIError.dataNotValid
      }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      #expect(model.upcomingQuestionAiring == nil)
      #expect(!model.hasUpcomingQuestionAiring)
    }
  }

  @Test
  func testViewAppearedDoesNotCheckAiringsWhenNotLoggedIn() async {
    @Shared(.auth) var auth = Auth()
    let apiCalled = LockIsolated(false)

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in
        apiCalled.setValue(true)
        return []
      }
    } operation: {
      let model = HomePageModel()

      await model.viewAppeared()

      #expect(!apiCalled.value)
      #expect(model.upcomingQuestionAiring == nil)
    }
  }

  @Test
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

      #expect(model.questionAiringTileModel.content == "You're On Air Soon!")
      #expect(
        model.questionAiringTileModel.paragraph!.contains("DJ Awesome picked your question!"))
    }
  }

  // MARK: - Question Airing Share Tests

  private static let appStoreUrl = "https://apps.apple.com/us/app/playola-radio/id6480465361"

  @Test
  func testQuestionAiringShareButtonPresentsShareSheetWithAppStoreUrl() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator =
      MainContainerNavigationCoordinator()

    let futureDate = Date().addingTimeInterval(2 * 24 * 60 * 60)
    let airing = ListenerQuestionAiring.mockWith(
      airtime: futureDate,
      station: .mockWith(curatorName: "Jason Eady")
    )

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in [airing] }
    } operation: {
      let model = HomePageModel()
      await model.viewAppeared()

      await model.questionAiringTileModel.buttonAction?()

      if case .share(let shareModel) = navigationCoordinator.presentedSheet {
        #expect(shareModel.items[0].contains("Jason Eady's radio station"))
        #expect(shareModel.items[1] == Self.appStoreUrl)
      } else {
        Issue.record("Expected share sheet to be presented")
      }
    }
  }

  @Test
  func testQuestionAiringShareButtonUsesGenericMessageWhenNoCuratorName() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator =
      MainContainerNavigationCoordinator()

    let futureDate = Date().addingTimeInterval(2 * 24 * 60 * 60)
    let airing = ListenerQuestionAiring.mockWith(
      airtime: futureDate,
      station: nil
    )

    await withDependencies {
      $0.api.getMyListenerQuestionAirings = { _ in [airing] }
    } operation: {
      let model = HomePageModel()
      await model.viewAppeared()

      await model.questionAiringTileModel.buttonAction?()

      if case .share(let shareModel) = navigationCoordinator.presentedSheet {
        #expect(shareModel.items[0].contains("an internet radio station"))
        #expect(shareModel.items[1] == Self.appStoreUrl)
      } else {
        Issue.record("Expected share sheet to be presented")
      }
    }
  }

  // MARK: - Invite Friends Tile Tests

  @Test
  func testCanInviteFriendsIsTrueWhenUserHasTwoOrMoreHours() {
    let rewardsProfile = RewardsProfile(
      totalTimeListenedMS: 2 * 60 * 60 * 1000,  // 2 hours
      totalMSAvailableForRewards: 0,
      accurateAsOfTime: Date()
    )
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = ListeningTracker(
      rewardsProfile: rewardsProfile)

    let model = HomePageModel()

    #expect(model.canInviteFriends)
  }

  @Test
  func testCanInviteFriendsIsFalseWhenUserHasLessThanTwoHours() {
    let rewardsProfile = RewardsProfile(
      totalTimeListenedMS: 1 * 60 * 60 * 1000,  // 1 hour
      totalMSAvailableForRewards: 0,
      accurateAsOfTime: Date()
    )
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker? = ListeningTracker(
      rewardsProfile: rewardsProfile)

    let model = HomePageModel()

    #expect(!model.canInviteFriends)
  }

  @Test
  func testCanInviteFriendsIsFalseWhenListeningTrackerIsNil() {
    @Shared(.listeningTracker) var listeningTracker: ListeningTracker?

    let model = HomePageModel()

    #expect(!model.canInviteFriends)
  }

  @Test
  func testInviteFriendsTileHasCorrectContent() {
    let model = HomePageModel()

    #expect(model.inviteFriendsTileModel.label == "Power Listener Reward")
    #expect(model.inviteFriendsTileModel.content == "Invite Your Friends")
    #expect(model.inviteFriendsTileModel.buttonText == "Invite")
    #expect(model.inviteFriendsTileModel.paragraph != nil)
  }

  @Test
  func testInviteFriendsTilePresentsShareSheetWithAppStoreUrl() async {
    @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator =
      MainContainerNavigationCoordinator()

    let model = HomePageModel()

    await model.inviteFriendsTileModel.buttonAction?()

    if case .share(let shareModel) = navigationCoordinator.presentedSheet {
      #expect(shareModel.items.count == 1)
      #expect(shareModel.items[0] == Self.appStoreUrl)
    } else {
      Issue.record("Expected share sheet to be presented")
    }
  }

}

// swiftlint:enable force_try
