//
//  StationListPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/13/25.
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
struct StationListPageTests {
  // MARK: - View Appeared Tests

  @Test
  func testViewAppearedPopulatesFromInitialSharedStationLists() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.stationLists) var stationLists = StationList.mocks
    let expectedVisibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
    let model = StationListModel()
    await model.viewAppeared()
    #expect(model.stationListsForDisplay == expectedVisibleLists)
    #expect(model.segmentTitles == ["All"] + expectedVisibleLists.map { $0.title })
    #expect(model.selectedSegment == "All")
  }

  // MARK: - Segment Selection Tests

  @Test
  func testSegmentSelectionFiltersWhenSegmentSelected() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.stationLists) var stationLists = StationList.mocks
    let visibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
    guard let firstList = visibleLists.first else {
      Issue.record("StationList.mocks should have at least one non-development list")
      return
    }
    let model = StationListModel()
    await model.viewAppeared()
    await model.segmentSelected(firstList.title)
    #expect(model.selectedSegment == firstList.title)
    #expect(model.stationListsForDisplay == [firstList])
  }

  // MARK: - Shared stationLists Updates Tests

  @Test
  func testSharedStationListsUpdatesKeepsSelectedSegmentWhenStillPresent() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.stationLists) var stationLists = StationList.mocks
    let visibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
    guard let targetList = visibleLists.first else {
      Issue.record("StationList.mocks should have at least one non-development list")
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

    #expect(model.selectedSegment == targetList.title)
    #expect(model.stationListsForDisplay.count == 1)
    #expect(model.stationListsForDisplay.first?.title == targetList.title)
  }

  @Test
  func testSharedStationListsUpdatesResetsSelectedSegmentWhenSegmentMissing() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.stationLists) var stationLists = StationList.mocks
    let visibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
    guard let targetList = visibleLists.first else {
      Issue.record("StationList.mocks should have at least one non-development list")
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
    #expect(model.selectedSegment == "All")
    #expect(model.stationListsForDisplay == expectedVisibleAfterUpdate)
  }

  @Test
  func testViewAppearedIncludesHiddenListsWhenSecretsEnabled() async {
    @Shared(.showSecretStations) var showSecretStations = true
    @Shared(.stationLists) var stationLists = StationList.mocks
    let model = StationListModel()
    await model.viewAppeared()

    #expect(model.stationListsForDisplay == stationLists)
    #expect(model.segmentTitles == ["All"] + stationLists.map { $0.title })
  }

  // MARK: - Player Interaction Tests

  @Test
  func testPlayerInteractionPlaysAStationWhenItIsTapped() async {
    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let stationListModel = makeStationListModel(
      analyticsSink: capturedEvents, stationPlayer: stationPlayerMock)

    let item = makeVisibleItem()

    stationListModel.stationListsForDisplay =
      IdentifiedArray(uniqueElements: [makeList(with: [item])])

    await stationListModel.stationSelected(item)

    #expect(stationPlayerMock.callsToPlay.count == 1)
    #expect(stationPlayerMock.callsToPlay.first?.id == item.anyStation.id)
    assertPlayedEvents(capturedEvents.value, stationId: item.anyStation.id)
  }

  @Test
  func testComingSoonStationDoesNotPlayWhenSecretsHidden() async {
    @Shared(.showSecretStations) var showSecretStations = false

    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let stationListModel = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.stationPlayer = stationPlayerMock
    } operation: {
      StationListModel()
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

    #expect(stationPlayerMock.callsToPlay.isEmpty)
    #expect(capturedEvents.value.isEmpty)
  }

  @Test
  func testComingSoonStationPlaysWhenSecretsShown() async {
    @Shared(.showSecretStations) var showSecretStations = true

    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let stationListModel = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.stationPlayer = stationPlayerMock
    } operation: {
      StationListModel()
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

    #expect(stationPlayerMock.callsToPlay.count == 1)
    #expect(stationPlayerMock.callsToPlay.first?.id == comingSoonItem.anyStation.id)

    let events = capturedEvents.value
    #expect(events.count == 2)
    if case .tappedStationCard(let stationInfo, _, _) = events[0] {
      #expect(stationInfo.id == comingSoonItem.anyStation.id)
    } else {
      Issue.record("Expected tappedStationCard event")
    }
    if case .startedStation(let stationInfo, _) = events[1] {
      #expect(stationInfo.id == comingSoonItem.anyStation.id)
    } else {
      Issue.record("Expected startedStation event")
    }
  }

  @Test
  func testInactiveStationDoesNotPlay() async {
    @Shared(.showSecretStations) var showSecretStations = true

    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let stationListModel = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
      $0.stationPlayer = stationPlayerMock
    } operation: {
      StationListModel()
    }

    let now = Date()
    let inactiveItem = makeComingSoonItem(active: false, date: now)

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
          items: [inactiveItem]
        )
      ])

    await stationListModel.stationSelected(inactiveItem)

    #expect(stationPlayerMock.callsToPlay.isEmpty)
    #expect(capturedEvents.value.isEmpty)
  }

  // MARK: - Hidden Station Filtering

  @Test
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

    #expect(filteredItems.count == 1)
    #expect(filteredItems.first?.visibility == .visible)
  }

  @Test
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

    #expect(filteredItems.count == 2)
    #expect(filteredItems.last?.visibility == .hidden)
  }

  // MARK: - Live Station Tests

  @Test
  func testLiveStatusForStationReturnsNilWhenNotLive() async {
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

    let model = StationListModel()
    await model.viewAppeared()

    let status = model.liveStatusForStation("some-station-id")

    #expect(status == nil)
  }

  @Test
  func testLiveStatusForStationReturnsVoicetrackingStatus() async {
    let station = Station.mockWith(id: "live-station")
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = [
      LiveStationInfo(stationId: "live-station", liveStatus: .voicetracking, station: station)
    ]

    let model = StationListModel()
    await model.viewAppeared()

    let status = model.liveStatusForStation("live-station")

    #expect(status == .voicetracking)
  }

  @Test
  func testLiveStatusForStationReturnsShowAiringStatus() async {
    let station = Station.mockWith(id: "show-station")
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = [
      LiveStationInfo(stationId: "show-station", liveStatus: .showAiring, station: station)
    ]

    let model = StationListModel()
    await model.viewAppeared()

    let status = model.liveStatusForStation("show-station")

    #expect(status == .showAiring)
  }

  @Test
  func testSortedStationItemsPutsLiveStationsFirst() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let now = Date()

    let station1 = Station.mockWith(id: "station-1", name: "Station 1")
    let station2 = Station.mockWith(id: "station-2", name: "Station 2")
    let station3 = Station.mockWith(id: "station-3", name: "Station 3")

    @Shared(.liveStations) var liveStations: [LiveStationInfo] = [
      LiveStationInfo(stationId: "station-2", liveStatus: .voicetracking, station: station2)
    ]

    let list = StationList(
      id: "test-list",
      name: "Test List",
      slug: "test-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
        APIStationItem(sortOrder: 2, visibility: .visible, station: station3, urlStation: nil),
      ]
    )

    let model = StationListModel()
    await model.viewAppeared()

    let sortedItems = model.sortedStationItems(for: list)

    #expect(sortedItems.count == 3)
    #expect(sortedItems[0].anyStation.id == "station-2")
  }

  @Test
  func testSortedStationItemsPutsVoicetrackingBeforeShowAiring() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let now = Date()

    let station1 = Station.mockWith(id: "station-1", name: "Station 1")
    let station2 = Station.mockWith(id: "station-2", name: "Station 2")
    let station3 = Station.mockWith(id: "station-3", name: "Station 3")

    @Shared(.liveStations) var liveStations: [LiveStationInfo] = [
      LiveStationInfo(stationId: "station-1", liveStatus: .showAiring, station: station1),
      LiveStationInfo(stationId: "station-3", liveStatus: .voicetracking, station: station3),
    ]

    let list = StationList(
      id: "test-list",
      name: "Test List",
      slug: "test-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
        APIStationItem(sortOrder: 2, visibility: .visible, station: station3, urlStation: nil),
      ]
    )

    let model = StationListModel()
    await model.viewAppeared()

    let sortedItems = model.sortedStationItems(for: list)

    #expect(sortedItems.count == 3)
    #expect(sortedItems[0].anyStation.id == "station-3")  // voicetracking first
    #expect(sortedItems[1].anyStation.id == "station-1")  // showAiring second
    #expect(sortedItems[2].anyStation.id == "station-2")  // not live last
  }

  @Test
  func testSortedStationItemsPreservesOrderWhenNoLiveStations() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
    let now = Date()

    let station1 = Station.mockWith(id: "station-1", name: "Station 1")
    let station2 = Station.mockWith(id: "station-2", name: "Station 2")

    let list = StationList(
      id: "test-list",
      name: "Test List",
      slug: "test-list",
      hidden: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
        APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
      ]
    )

    let model = StationListModel()
    await model.viewAppeared()

    let sortedItems = model.sortedStationItems(for: list)

    #expect(sortedItems.count == 2)
    #expect(sortedItems[0].anyStation.id == "station-1")
    #expect(sortedItems[1].anyStation.id == "station-2")
  }

  // MARK: - Search Tests

  @Test
  func testSearchByCuratorNameFiltersStations() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

    let station1 = Station.mockWith(id: "s1", name: "Show One", curatorName: "Alice")
    let station2 = Station.mockWith(id: "s2", name: "Show Two", curatorName: "Bob")

    let list = makeList(with: [
      APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
      APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
    ])

    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [list]
    let model = StationListModel()
    await model.viewAppeared()

    model.searchText = "Alice"

    let items = model.sortedStationItems(for: model.stationListsForDisplay.first!)
    #expect(items.count == 1)
    #expect(items.first?.anyStation.id == "s1")
  }

  @Test
  func testSearchByStationNameFiltersStations() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

    let station1 = Station.mockWith(id: "s1", name: "Moondog Radio", curatorName: "Alice")
    let station2 = Station.mockWith(id: "s2", name: "Jazz Hour", curatorName: "Bob")

    let list = makeList(with: [
      APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
      APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
    ])

    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [list]
    let model = StationListModel()
    await model.viewAppeared()

    model.searchText = "Moondog"

    let items = model.sortedStationItems(for: model.stationListsForDisplay.first!)
    #expect(items.count == 1)
    #expect(items.first?.anyStation.id == "s1")
  }

  @Test
  func testSearchIsCaseInsensitive() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

    let station1 = Station.mockWith(id: "s1", name: "Moondog Radio", curatorName: "Alice")

    let list = makeList(with: [
      APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil)
    ])

    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [list]
    let model = StationListModel()
    await model.viewAppeared()

    model.searchText = "alice"

    let items = model.sortedStationItems(for: model.stationListsForDisplay.first!)
    #expect(items.count == 1)
    #expect(items.first?.anyStation.id == "s1")
  }

  @Test
  func testEmptySearchTextShowsAllStations() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

    let station1 = Station.mockWith(id: "s1", name: "Show One", curatorName: "Alice")
    let station2 = Station.mockWith(id: "s2", name: "Show Two", curatorName: "Bob")

    let list = makeList(with: [
      APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
      APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
    ])

    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [list]
    let model = StationListModel()
    await model.viewAppeared()

    model.searchText = ""

    let items = model.sortedStationItems(for: model.stationListsForDisplay.first!)
    #expect(items.count == 2)
  }

  @Test
  func testIsShowingNoResultsTrueWhenSearchHasNoMatches() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

    let station1 = Station.mockWith(id: "s1", name: "Show One", curatorName: "Alice")

    let list = makeList(with: [
      APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil)
    ])

    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [list]
    let model = StationListModel()
    await model.viewAppeared()

    model.searchText = "xyznonexistent"

    #expect(model.isShowingNoResults)
  }

  @Test
  func testIsShowingNoResultsFalseWhenSearchTextEmpty() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

    let station1 = Station.mockWith(id: "s1", name: "Show One", curatorName: "Alice")

    let list = makeList(with: [
      APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil)
    ])

    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [list]
    let model = StationListModel()
    await model.viewAppeared()

    model.searchText = ""

    #expect(!model.isShowingNoResults)
  }

  @Test
  func testSearchWorksWithinSelectedSegment() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
    let now = Date()

    let station1 = Station.mockWith(id: "s1", name: "Show One", curatorName: "Alice")
    let station2 = Station.mockWith(id: "s2", name: "Show Two", curatorName: "Alice Too")

    let list1 = StationList(
      id: "list-1", name: "Hip Hop", slug: "hip-hop",
      hidden: false, sortOrder: 0, createdAt: now, updatedAt: now,
      items: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil)
      ]
    )
    let list2 = StationList(
      id: "list-2", name: "Jazz", slug: "jazz",
      hidden: false, sortOrder: 1, createdAt: now, updatedAt: now,
      items: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station2, urlStation: nil)
      ]
    )

    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [list1, list2]
    let model = StationListModel()
    await model.viewAppeared()

    await model.segmentSelected("Hip Hop")
    model.searchText = "Alice"

    #expect(model.stationListsForDisplay.count == 1)
    let items = model.sortedStationItems(for: model.stationListsForDisplay.first!)
    #expect(items.count == 1)
    #expect(items.first?.anyStation.id == "s1")
  }

  @Test
  func testSearchTextClearedOnSegmentSwitch() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
    let now = Date()

    let station1 = Station.mockWith(id: "s1", name: "Show One", curatorName: "Alice")

    let list1 = StationList(
      id: "list-1", name: "Hip Hop", slug: "hip-hop",
      hidden: false, sortOrder: 0, createdAt: now, updatedAt: now,
      items: [
        APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil)
      ]
    )
    let list2 = StationList(
      id: "list-2", name: "Jazz", slug: "jazz",
      hidden: false, sortOrder: 1, createdAt: now, updatedAt: now,
      items: []
    )

    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [list1, list2]
    let model = StationListModel()
    await model.viewAppeared()

    model.searchText = "Alice"
    #expect(model.searchText == "Alice")

    await model.segmentSelected("Jazz")
    #expect(model.searchText == "")
  }

  @Test
  func testSearchMatchesEitherCuratorNameOrStationName() async {
    @Shared(.showSecretStations) var showSecretStations = false
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

    let station1 = Station.mockWith(id: "s1", name: "Moondog Radio", curatorName: "Alice")
    let station2 = Station.mockWith(id: "s2", name: "Jazz Hour", curatorName: "Bob Moondog")
    let station3 = Station.mockWith(id: "s3", name: "Rock Show", curatorName: "Charlie")

    let list = makeList(with: [
      APIStationItem(sortOrder: 0, visibility: .visible, station: station1, urlStation: nil),
      APIStationItem(sortOrder: 1, visibility: .visible, station: station2, urlStation: nil),
      APIStationItem(sortOrder: 2, visibility: .visible, station: station3, urlStation: nil),
    ])

    @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = [list]
    let model = StationListModel()
    await model.viewAppeared()

    model.searchText = "Moondog"

    let items = model.sortedStationItems(for: model.stationListsForDisplay.first!)
    #expect(items.count == 2)
    let ids = items.map { $0.anyStation.id }
    #expect(ids.contains("s1"))
    #expect(ids.contains("s2"))
  }
}

private func assertPlayedEvents(
  _ events: [AnalyticsEvent],
  stationId: String
) {
  #expect(events.count == 2)

  guard let firstEvent = events.first else {
    Issue.record("Expected tappedStationCard event, but events were empty")
    return
  }
  guard
    case .tappedStationCard(let stationInfo, let position, let totalStations) = firstEvent
  else {
    Issue.record("Expected tappedStationCard event, got: \(String(describing: firstEvent))")
    return
  }
  #expect(stationInfo.id == stationId)
  #expect(position == 0)
  #expect(totalStations == 1)

  guard let secondEvent = events.dropFirst().first else {
    Issue.record("Expected startedStation event, but only found one event")
    return
  }
  guard
    case .startedStation(let startedInfo, let entryPoint) = secondEvent
  else {
    Issue.record("Expected startedStation event, got: \(String(describing: secondEvent))")
    return
  }
  #expect(startedInfo.id == stationId)
  #expect(entryPoint == "station_list")
}

private func makeComingSoonItem(active: Bool, date: Date) -> APIStationItem {
  let station = PlayolaPlayer.Station(
    id: active ? "coming-soon" : "inactive-station",
    name: active ? "Moondog Radio" : "Dormant Station",
    curatorName: active ? "Jacob Stelly" : "Inactive DJ",
    imageUrl: URL(
      string: active ? "https://example.com/moondog.png" : "https://example.com/inactive.png"),
    description: active ? "Coming soon" : "This station is inactive",
    active: active,
    createdAt: date,
    updatedAt: date
  )

  return APIStationItem(
    sortOrder: 0,
    visibility: .comingSoon,
    station: station,
    urlStation: nil
  )
}

private func makeVisibleItem(date: Date = Date()) -> APIStationItem {
  let station = PlayolaPlayer.Station(
    id: "playable-station",
    name: "Moondog Radio",
    curatorName: "Jacob Stelly",
    imageUrl: URL(string: "https://example.com/moondog.png"),
    description: "A playable station",
    active: true,
    createdAt: date,
    updatedAt: date
  )

  return APIStationItem(
    sortOrder: 0,
    visibility: .visible,
    station: station,
    urlStation: nil
  )
}

private func makeList(with items: [APIStationItem], date: Date = Date()) -> StationList {
  StationList(
    id: "test-list",
    name: "Test List",
    slug: "test-list",
    hidden: false,
    sortOrder: 0,
    createdAt: date,
    updatedAt: date,
    items: items
  )
}

@MainActor
private func makeStationListModel(
  analyticsSink: LockIsolated<[AnalyticsEvent]>,
  stationPlayer: StationPlayerMock
) -> StationListModel {
  withDependencies {
    $0.analytics.track = { event in analyticsSink.withValue { $0.append(event) } }
    $0.stationPlayer = stationPlayer
  } operation: {
    StationListModel()
  }
}

// MARK: - Notification Permission Prompt Tests

@MainActor
struct StationListNotificationPromptTests {

  @Test
  func testViewAppearedShowsNotificationAlertOnFirstVisit() async {
    @Shared(.hasAskedForNotificationPermission) var hasAsked = false

    let model = withDependencies {
      $0.pushNotifications.requestAuthorization = { true }
      $0.pushNotifications.registerForRemoteNotifications = {}
    } operation: {
      StationListModel()
    }

    await model.viewAppeared()

    #expect(model.presentedAlert != nil)
    #expect(model.presentedAlert?.title == "Stay in the Loop?")
  }

  @Test
  func testViewAppearedDoesNotShowAlertIfAlreadyAsked() async {
    @Shared(.hasAskedForNotificationPermission) var hasAsked = true

    let model = withDependencies {
      $0.pushNotifications.requestAuthorization = { true }
      $0.pushNotifications.registerForRemoteNotifications = {}
    } operation: {
      StationListModel()
    }

    await model.viewAppeared()

    #expect(model.presentedAlert == nil)
  }

  @Test
  func testNotificationAlertYesTappedRequestsPermission() async {
    @Shared(.hasAskedForNotificationPermission) var hasAsked = false
    let authorizationRequested = LockIsolated(false)
    let registrationCalled = LockIsolated(false)

    let model = withDependencies {
      $0.pushNotifications.requestAuthorization = {
        authorizationRequested.setValue(true)
        return true
      }
      $0.pushNotifications.registerForRemoteNotifications = {
        registrationCalled.setValue(true)
      }
    } operation: {
      StationListModel()
    }

    await model.notificationAlertYesTapped()

    #expect(authorizationRequested.value)
    #expect(registrationCalled.value)
    #expect(hasAsked)
    #expect(model.presentedAlert == nil)
  }

  @Test
  func testNotificationAlertNoTappedSetsHasAskedWithoutRequesting() async {
    @Shared(.hasAskedForNotificationPermission) var hasAsked = false
    let authorizationRequested = LockIsolated(false)

    let model = withDependencies {
      $0.pushNotifications.requestAuthorization = {
        authorizationRequested.setValue(true)
        return true
      }
      $0.pushNotifications.registerForRemoteNotifications = {}
    } operation: {
      StationListModel()
    }

    await model.notificationAlertNoTapped()

    #expect(!authorizationRequested.value)
    #expect(hasAsked)
    #expect(model.presentedAlert == nil)
  }

  @Test
  func testNotificationAlertDoesNotRegisterIfPermissionDenied() async {
    @Shared(.hasAskedForNotificationPermission) var hasAsked = false
    let registrationCalled = LockIsolated(false)

    let model = withDependencies {
      $0.pushNotifications.requestAuthorization = {
        return false
      }
      $0.pushNotifications.registerForRemoteNotifications = {
        registrationCalled.setValue(true)
      }
    } operation: {
      StationListModel()
    }

    await model.notificationAlertYesTapped()

    #expect(!registrationCalled.value)
    #expect(hasAsked)
  }
}
