//
//  StationListPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/13/25.
//

import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class StationListPageTests: XCTestCase {
  // MARK: - View Appeared Tests

  func testViewAppeared_PopulatesFromInitialSharedStationLists() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.stationLists) var stationLists = StationList.mocks
    let expectedVisibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
    let model = StationListModel()
    await model.viewAppeared()
    XCTAssertEqual(model.stationListsForDisplay, expectedVisibleLists)
    XCTAssertEqual(model.segmentTitles, ["All"] + expectedVisibleLists.map { $0.title })
    XCTAssertEqual(model.selectedSegment, "All")
  }

  // MARK: - Segment Selection Tests

  func testSegmentSelection_FiltersWhenSegmentSelected() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.stationLists) var stationLists = StationList.mocks
    let visibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
    guard let firstList = visibleLists.first else {
      XCTFail("StationList.mocks should have at least one non-development list")
      return
    }
    let model = StationListModel()
    await model.viewAppeared()
    await model.segmentSelected(firstList.title)
    XCTAssertEqual(model.selectedSegment, firstList.title)
    XCTAssertEqual(model.stationListsForDisplay, [firstList])
  }

  // MARK: - Shared stationLists Updates Tests

  func testSharedStationListsUpdates_KeepsSelectedSegmentWhenStillPresent() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.stationLists) var stationLists = StationList.mocks
    let visibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
    guard let targetList = visibleLists.first else {
      XCTFail("StationList.mocks should have at least one non-development list")
      return
    }

    let model = StationListModel()
    await model.viewAppeared()
    await model.segmentSelected(targetList.title)

    // mutate shared lists but keep a list with the same title
    $stationLists.withLock { lists in
      lists = IdentifiedArray(
        uniqueElements: [
          StationList(
            id: targetList.id,
            name: targetList.title,
            slug: targetList.id,
            hidden: false,
            sortOrder: 0,
            createdAt: Date(),
            updatedAt: Date(),
            items: []
          )
        ]
      )
    }

    XCTAssertEqual(model.selectedSegment, targetList.title)
    XCTAssertEqual(model.stationListsForDisplay.count, 1)
    XCTAssertEqual(model.stationListsForDisplay.first?.title, targetList.title)
  }

  func testSharedStationListsUpdates_ResetsSelectedSegmentWhenSegmentMissing() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.stationLists) var stationLists = StationList.mocks
    let visibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
    guard let targetList = visibleLists.first else {
      XCTFail("StationList.mocks should have at least one non-development list")
      return
    }

    let model = StationListModel()
    await model.viewAppeared()
    await model.segmentSelected(targetList.title)

    // mutate shared lists and remove the previously selected segment
    $stationLists.withLock { lists in
      lists = IdentifiedArray(
        uniqueElements:
          visibleLists
          .filter { $0.id != targetList.id }
          .map {
            StationList(
              id: $0.id,
              name: $0.title,
              slug: $0.id,
              hidden: false,
              sortOrder: 0,
              createdAt: Date(),
              updatedAt: Date(),
              items: []
            )
          }
      )
    }

    let expectedVisibleAfterUpdate = stationLists.filter {
      $0.id != StationList.inDevelopmentListId
    }
    XCTAssertEqual(model.selectedSegment, "All")
    XCTAssertEqual(model.stationListsForDisplay, expectedVisibleAfterUpdate)
  }

  func testViewAppeared_IncludesHiddenListsWhenSecretsEnabled() async {
    @Shared(.showSecretStations) var showSecretStations = true
    @Shared(.stationLists) var stationLists = StationList.mocks
    let model = StationListModel()
    await model.viewAppeared()

    XCTAssertEqual(model.stationListsForDisplay, stationLists)
    XCTAssertEqual(model.segmentTitles, ["All"] + stationLists.map { $0.title })
  }

  // MARK: - Player Interaction Tests

  func testPlayerInteraction_PlaysAStationWhenItIsTapped() async {
    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let stationListModel = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      StationListModel(stationPlayer: stationPlayerMock)
    }

    let now = Date()
    let visibleStation = PlayolaPlayer.Station(
      id: "visible-station",
      name: "Visible Station",
      curatorName: "DJ Visible",
      imageUrl: URL(string: "https://example.com/visible.png"),
      description: "Visible description",
      active: true,
      createdAt: now,
      updatedAt: now
    )

    let item = APIStationItem(
      sortOrder: 0,
      visibility: .visible,
      station: visibleStation,
      urlStation: nil
    )

    stationListModel.stationListsForDisplay = IdentifiedArray(
      uniqueElements: [
        StationList(
          id: StationList.KnownIDs.artistList.rawValue,
          name: "Artists",
          slug: StationList.artistListSlug,
          hidden: false,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
          items: [item]
        )
      ])

    await stationListModel.stationSelected(item)

    XCTAssertEqual(stationPlayerMock.callsToPlay.count, 1)
    XCTAssertEqual(stationPlayerMock.callsToPlay.first?.id, item.anyStation.id)

    // Verify analytics events were tracked
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 2)

    // First event should be tappedStationCard
    if case .tappedStationCard(let stationInfo, let position, let totalStations) = events[0] {
      XCTAssertEqual(stationInfo.id, item.anyStation.id)
      XCTAssertEqual(position, 0)
      XCTAssertEqual(totalStations, 1)
    } else {
      XCTFail("Expected tappedStationCard event, got: \(events[0])")
    }

    // Second event should be startedStation
    if case .startedStation(let stationInfo, let entryPoint) = events[1] {
      XCTAssertEqual(stationInfo.id, item.anyStation.id)
      XCTAssertEqual(entryPoint, "station_list")
    } else {
      XCTFail("Expected startedStation event, got: \(events[1])")
    }
  }

  func testComingSoonStationDoesNotPlayWhenSecretsHidden() async {
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let stationListModel = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      StationListModel(stationPlayer: stationPlayerMock)
    }

    let now = Date()
    let comingSoonItem = makeComingSoonItem(active: true, date: now)

    stationListModel.stationListsForDisplay = IdentifiedArray(
      uniqueElements: [
        StationList(
          id: StationList.KnownIDs.artistList.rawValue,
          name: "Artists",
          slug: StationList.artistListSlug,
          hidden: false,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
          items: [comingSoonItem]
        )
      ])

    await stationListModel.stationSelected(comingSoonItem)

    XCTAssertTrue(stationPlayerMock.callsToPlay.isEmpty)
    XCTAssertTrue(capturedEvents.value.isEmpty)
  }

  func testComingSoonStationPlaysWhenSecretsShown() async {
    @Shared(.showSecretStations) var showSecretStations = true

    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let stationListModel = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      StationListModel(stationPlayer: stationPlayerMock)
    }

    let now = Date()
    let comingSoonItem = makeComingSoonItem(active: true, date: now)

    stationListModel.stationListsForDisplay = IdentifiedArray(
      uniqueElements: [
        StationList(
          id: StationList.KnownIDs.artistList.rawValue,
          name: "Artists",
          slug: StationList.artistListSlug,
          hidden: false,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
          items: [comingSoonItem]
        )
      ])

    await stationListModel.stationSelected(comingSoonItem)

    XCTAssertEqual(stationPlayerMock.callsToPlay.count, 1)
    XCTAssertEqual(stationPlayerMock.callsToPlay.first?.id, comingSoonItem.anyStation.id)

    let events = capturedEvents.value
    XCTAssertEqual(events.count, 2)
    if case .tappedStationCard(let stationInfo, _, _) = events[0] {
      XCTAssertEqual(stationInfo.id, comingSoonItem.anyStation.id)
    } else {
      XCTFail("Expected tappedStationCard event")
    }
    if case .startedStation(let stationInfo, _) = events[1] {
      XCTAssertEqual(stationInfo.id, comingSoonItem.anyStation.id)
    } else {
      XCTFail("Expected startedStation event")
    }
  }

  // MARK: - Hidden Station Filtering

  func testHiddenStationsFilteredWhenSecretsOff() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let now = Date()
    let visibleStation = PlayolaPlayer.Station(
      id: "visible-playola",
      name: "Visible Playola",
      curatorName: "DJ Visible",
      imageUrl: URL(string: "https://example.com/visible.png"),
      description: "Visible station",
      active: true,
      createdAt: now,
      updatedAt: now
    )

    let hiddenStation = PlayolaPlayer.Station(
      id: "hidden-playola",
      name: "Hidden Playola",
      curatorName: "DJ Hidden",
      imageUrl: URL(string: "https://example.com/hidden.png"),
      description: "Hidden station",
      active: true,
      createdAt: now,
      updatedAt: now
    )

    let secretList = StationList(
      id: "secret-list",
      name: "Secret Stations",
      slug: "secret-list",
      hidden: true,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(
          sortOrder: 0, visibility: .visible, station: visibleStation, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .hidden, station: hiddenStation, urlStation: nil),
      ]
    )

    let model = StationListModel()
    await model.viewAppeared()

    model.stationListsForDisplay = IdentifiedArray(uniqueElements: [secretList])

    let includeHidden = model.showSecretStations || !secretList.hidden
    let filteredItems = secretList.stationItems(includeHidden: includeHidden)

    XCTAssertEqual(filteredItems.count, 1)
    XCTAssertEqual(filteredItems.first?.visibility, .visible)
  }

  func testHiddenStationsIncludedWhenSecretsOn() async {
    @Shared(.showSecretStations) var showSecretStations = true
    let now = Date()
    let visibleStation = PlayolaPlayer.Station(
      id: "visible-playola",
      name: "Visible Playola",
      curatorName: "DJ Visible",
      imageUrl: URL(string: "https://example.com/visible.png"),
      description: "Visible station",
      active: true,
      createdAt: now,
      updatedAt: now
    )

    let hiddenStation = PlayolaPlayer.Station(
      id: "hidden-playola",
      name: "Hidden Playola",
      curatorName: "DJ Hidden",
      imageUrl: URL(string: "https://example.com/hidden.png"),
      description: "Hidden station",
      active: true,
      createdAt: now,
      updatedAt: now
    )

    let secretList = StationList(
      id: "secret-list",
      name: "Secret Stations",
      slug: "secret-list",
      hidden: true,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(
          sortOrder: 0, visibility: .visible, station: visibleStation, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .hidden, station: hiddenStation, urlStation: nil),
      ]
    )

    let model = StationListModel()
    await model.viewAppeared()

    model.stationListsForDisplay = IdentifiedArray(uniqueElements: [secretList])

    let includeHidden = model.showSecretStations || !secretList.hidden
    let filteredItems = secretList.stationItems(includeHidden: includeHidden)

    XCTAssertEqual(filteredItems.count, 2)
    XCTAssertEqual(filteredItems.last?.visibility, .hidden)
  }
}
