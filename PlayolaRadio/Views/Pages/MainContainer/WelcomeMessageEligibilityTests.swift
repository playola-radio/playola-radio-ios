//
//  WelcomeMessageEligibilityTests.swift
//  PlayolaRadio
//
//  Welcome-message eligibility wiring: the server-computed flag rides on the rewards
//  profile and is plumbed into @Shared(.welcomeMessageEligible) on launch.
//

import ConcurrencyExtras
import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct WelcomeMessageEligibilityTests {
  @Test
  func testLoadListeningTrackerSetsWelcomeMessageEligibleWhenServerSaysShow() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.welcomeMessageEligible) var welcomeMessageEligible = false

    let model = withDependencies {
      $0.api.getRewardsProfile = { _ in
        RewardsProfile(
          totalTimeListenedMS: 0,
          totalMSAvailableForRewards: 0,
          accurateAsOfTime: Date(),
          shouldShowWelcomeMessage: true
        )
      }
    } operation: {
      MainContainerModel()
    }

    await model.loadListeningTracker()

    #expect(welcomeMessageEligible == true)
  }

  @Test
  func testLoadListeningTrackerClearsWelcomeMessageEligibleWhenServerSaysNo() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.welcomeMessageEligible) var welcomeMessageEligible = true

    let model = withDependencies {
      $0.api.getRewardsProfile = { _ in
        RewardsProfile(
          totalTimeListenedMS: 999_999,
          totalMSAvailableForRewards: 0,
          accurateAsOfTime: Date(),
          shouldShowWelcomeMessage: false
        )
      }
    } operation: {
      MainContainerModel()
    }

    await model.loadListeningTracker()

    #expect(welcomeMessageEligible == false)
  }

  // Guards against the Codable footgun where a `let` property with a default is excluded
  // from synthesis: an optional `var` is still decoded, defaulting to nil when absent.
  @Test
  func testRewardsProfileDecodesWelcomeFlagAndDefaultsToNilWhenAbsent() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let withFlag = """
      {"totalTimeListenedMS":0,"totalMSAvailableForRewards":0,\
      "accurateAsOfTime":"2026-01-01T00:00:00Z","shouldShowWelcomeMessage":true}
      """.data(using: .utf8)!
    #expect(
      try decoder.decode(RewardsProfile.self, from: withFlag).shouldShowWelcomeMessage == true)

    let withoutFlag = """
      {"totalTimeListenedMS":0,"totalMSAvailableForRewards":0,\
      "accurateAsOfTime":"2026-01-01T00:00:00Z"}
      """.data(using: .utf8)!
    #expect(
      try decoder.decode(RewardsProfile.self, from: withoutFlag).shouldShowWelcomeMessage == nil)
  }

  // MARK: - Trigger (StationListModel)

  @Test
  func testStationSelectedPresentsWelcomeForEligiblePlayolaStation() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.welcomeMessageEligible) var welcomeMessageEligible = true
    @Shared(.welcomeMessageShownThisSession) var shown = false
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let seen = LockIsolated<[String]>([])
    let player = StationPlayerMock.mockStoppedPlayer()
    let model = withDependencies {
      $0.analytics.track = { _ in }
      $0.stationPlayer = player
      $0.api.markWelcomeMessageSeen = { _, stationId in seen.withValue { $0.append(stationId) } }
    } operation: {
      StationListModel()
    }

    let item = makeEligibleWelcomePlayolaItem()
    await model.stationSelected(item)

    #expect(player.callsToPlay.isEmpty)
    #expect(shown == true)
    // The server "seen" stamp belongs to the page (fires only once playback starts).
    #expect(seen.value.isEmpty)
    #expect(isWelcomeMessageSheet(coordinator.presentedSheet))
  }

  @Test
  func testStationSelectedPlaysNormallyWhenNotEligible() async {
    @Shared(.welcomeMessageEligible) var welcomeMessageEligible = false
    @Shared(.welcomeMessageShownThisSession) var shown = false
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let player = StationPlayerMock.mockStoppedPlayer()
    let model = withDependencies {
      $0.analytics.track = { _ in }
      $0.stationPlayer = player
    } operation: {
      StationListModel()
    }

    let item = makeEligibleWelcomePlayolaItem()
    await model.stationSelected(item)

    #expect(player.callsToPlay.map(\.id) == [item.anyStation.id])
    #expect(isWelcomeMessageSheet(coordinator.presentedSheet) == false)
  }

  // Eligible user, but the station has NO welcome-message recording → plays normally and
  // stays eligible for a later station that does have one (the Jason/Bri-before-Radney case).
  @Test
  func testStationSelectedPlaysNormallyWhenStationHasNoWelcomeRecording() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.welcomeMessageEligible) var welcomeMessageEligible = true
    @Shared(.welcomeMessageShownThisSession) var shown = false
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let player = StationPlayerMock.mockStoppedPlayer()
    let model = withDependencies {
      $0.analytics.track = { _ in }
      $0.stationPlayer = player
    } operation: {
      StationListModel()
    }

    let item = makeEligibleWelcomePlayolaItem(welcomeMessageAudioBlockId: nil)
    await model.stationSelected(item)

    #expect(player.callsToPlay.map(\.id) == [item.anyStation.id])
    #expect(isWelcomeMessageSheet(coordinator.presentedSheet) == false)
    #expect(shown == false)
    #expect(welcomeMessageEligible == true)
  }

  @Test
  func testAPIStationItemDecodesWelcomeMessageAudioBlockIdFromNestedStation() throws {
    let json = """
      {"sortOrder":0,"visibility":"visible","station":{"id":"s1","name":"Radney Radio",\
      "curatorName":"Radney Foster","description":"d","createdAt":"2026-01-01T00:00:00Z",\
      "updatedAt":"2026-01-01T00:00:00Z","welcomeMessageAudioBlockId":"ab-123"}}
      """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let item = try decoder.decode(APIStationItem.self, from: json)
    #expect(item.welcomeMessageAudioBlockId == "ab-123")
    #expect(item.station?.id == "s1")

    let withoutId = """
      {"sortOrder":0,"visibility":"visible","station":{"id":"s1","name":"Radney Radio",\
      "curatorName":"Radney Foster","description":"d","createdAt":"2026-01-01T00:00:00Z",\
      "updatedAt":"2026-01-01T00:00:00Z"}}
      """.data(using: .utf8)!
    #expect(
      try decoder.decode(APIStationItem.self, from: withoutId).welcomeMessageAudioBlockId == nil)
  }

  // MARK: - Trigger (HomePageModel "For You")

  @Test
  func testHomeStationTappedPresentsWelcomeForEligiblePlayolaStation() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.welcomeMessageEligible) var welcomeMessageEligible = true
    @Shared(.welcomeMessageShownThisSession) var shown = false
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let item = makeEligibleWelcomePlayolaItem()
    @Shared(.stationLists) var stationLists = makeWelcomeTestStationLists(items: [item])

    let player = StationPlayerMock.mockStoppedPlayer()
    let model = withDependencies {
      $0.analytics.track = { _ in }
      $0.stationPlayer = player
    } operation: {
      HomePageModel()
    }

    await model.stationTapped(item.anyStation)

    #expect(player.callsToPlay.isEmpty)
    #expect(shown == true)
    #expect(isWelcomeMessageSheet(coordinator.presentedSheet))
  }

  @Test
  func testHomeStationTappedPlaysNormallyWhenStationHasNoWelcomeRecording() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.welcomeMessageEligible) var welcomeMessageEligible = true
    @Shared(.welcomeMessageShownThisSession) var shown = false
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let item = makeEligibleWelcomePlayolaItem(welcomeMessageAudioBlockId: nil)
    @Shared(.stationLists) var stationLists = makeWelcomeTestStationLists(items: [item])

    let player = StationPlayerMock.mockStoppedPlayer()
    let model = withDependencies {
      $0.analytics.track = { _ in }
      $0.stationPlayer = player
    } operation: {
      HomePageModel()
    }

    await model.stationTapped(item.anyStation)

    #expect(player.callsToPlay.map(\.id) == [item.anyStation.id])
    #expect(isWelcomeMessageSheet(coordinator.presentedSheet) == false)
    #expect(welcomeMessageEligible == true)
  }

  // A rewards-profile refresh can leave welcomeMessageEligible == true before the server
  // records "seen". The separate session flag must still prevent a second presentation.
  @Test
  func testStationSelectedDoesNotReshowWhenAlreadyShownThisSession() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.welcomeMessageEligible) var welcomeMessageEligible = true
    @Shared(.welcomeMessageShownThisSession) var shown = true
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let player = StationPlayerMock.mockStoppedPlayer()
    let model = withDependencies {
      $0.analytics.track = { _ in }
      $0.stationPlayer = player
    } operation: {
      StationListModel()
    }

    let item = makeEligibleWelcomePlayolaItem()
    await model.stationSelected(item)

    #expect(player.callsToPlay.map(\.id) == [item.anyStation.id])
    #expect(isWelcomeMessageSheet(coordinator.presentedSheet) == false)
  }
}

private func isWelcomeMessageSheet(_ sheet: PlayolaSheet?) -> Bool {
  if case .welcomeMessage = sheet { return true }
  return false
}

private func makeWelcomeTestStationLists(items: [APIStationItem])
  -> IdentifiedArrayOf<StationList>
{
  [
    StationList(
      id: "artist-list-id",
      name: "Artist Stations",
      slug: StationList.artistListSlug,
      createdAt: Date(),
      updatedAt: Date(),
      items: items
    )
  ]
}

private func makeEligibleWelcomePlayolaItem(
  welcomeMessageAudioBlockId: String? = "welcome-audio-block-1"
) -> APIStationItem {
  let station = PlayolaPlayer.Station(
    id: "welcome-station",
    name: "Moondog Radio",
    curatorName: "Jacob Stelly",
    imageUrl: URL(string: "https://example.com/moondog.png"),
    description: "A playable station",
    active: true,
    createdAt: Date(),
    updatedAt: Date()
  )
  return APIStationItem(
    sortOrder: 0,
    visibility: .visible,
    station: station,
    urlStation: nil,
    welcomeMessageAudioBlockId: welcomeMessageAudioBlockId
  )
}
