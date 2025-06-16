//
//  StationListPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/13/25.
//

@testable import PlayolaRadio
import Sharing
import Testing
import IdentifiedCollections

enum StationListPageTests {
  // -------------------------------------------------------------
  // MARK: - View Appeared
  // -------------------------------------------------------------
  @MainActor @Suite("ViewAppeared")
  struct ViewAppeared {
    @Test("Populates stationListsForDisplay, segmentTitles & selectedSegment based on initial shared stationLists")
    func testPopulatesFromInitialSharedStationLists() async {
      @Shared(.stationLists) var stationLists = StationList.mocks
      let expectedVisibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
      let model = StationListModel()
      await model.viewAppeared()
      #expect(model.stationListsForDisplay == expectedVisibleLists)
      #expect(model.segmentTitles == ["All"] + expectedVisibleLists.map { $0.title })
      #expect(model.selectedSegment == "All")
    }
  }

  // -------------------------------------------------------------
  // MARK: - Segment Selection
  // -------------------------------------------------------------
  @MainActor @Suite("SegmentSelection")
  struct SegmentSelection {
    @Test("Filters stationListsForDisplay when a segment is selected")
    func testFiltersWhenSegmentSelected() async {
      @Shared(.stationLists) var stationLists = StationList.mocks
      let visibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
      guard let firstList = visibleLists.first else {
        #expect(true, "StationList.mocks should have at least one non-development list")
        return
      }
      let model = StationListModel()
      await model.viewAppeared()
      model.segmentSelected(firstList.title)
      #expect(model.selectedSegment == firstList.title)
      #expect(model.stationListsForDisplay == [firstList])
    }
  }

  // -------------------------------------------------------------
  // MARK: - Shared stationLists Updates
  // -------------------------------------------------------------
  @MainActor @Suite("SharedStationListsUpdates")
  struct SharedStationListsUpdates {
    @Test("Keeps selected segment when updated lists still contain that segment")
    func testKeepsSelectedSegmentWhenStillPresent() async {
      @Shared(.stationLists) var stationLists = StationList.mocks
      let visibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
      guard let targetList = visibleLists.first else {
        #expect(true, "StationList.mocks should have at least one non-development list")
        return
      }

      let model = StationListModel()
      await model.viewAppeared()
      model.segmentSelected(targetList.title)

      // mutate shared lists but keep a list with the same title
      $stationLists.withLock { lists in
        lists = IdentifiedArray(
          uniqueElements: [StationList(
            id: targetList.id,
            title: targetList.title,
            stations: targetList.stations.reversed()
          )]
        )
      }

      #expect(model.selectedSegment == targetList.title)
      #expect(model.stationListsForDisplay.count == 1)
      #expect(model.stationListsForDisplay.first?.title == targetList.title)
    }

    @Test("Resets selected segment to All when updated lists no longer contain the segment")
    func testResetsSelectedSegmentWhenSegmentMissing() async {
      @Shared(.stationLists) var stationLists = StationList.mocks
      let visibleLists = stationLists.filter { $0.id != StationList.inDevelopmentListId }
      guard let targetList = visibleLists.first else {
        #expect(true, "StationList.mocks should have at least one non-development list")
        return
      }

      let model = StationListModel()
      await model.viewAppeared()
      model.segmentSelected(targetList.title)

      // mutate shared lists and remove the previously selected segment
      $stationLists.withLock { lists in
        lists = IdentifiedArray(
          uniqueElements: visibleLists
            .filter { $0.id != targetList.id }
            .map { StationList(id: $0.id, title: $0.title, stations: $0.stations) }
        )
      }

      let expectedVisibleAfterUpdate = stationLists.filter { $0.id != StationList.inDevelopmentListId }
      #expect(model.selectedSegment == "All")
      #expect(model.stationListsForDisplay == expectedVisibleAfterUpdate)
    }
  }

  // -------------------------------------------------------------
  // MARK: - Player interaction
  // -------------------------------------------------------------
  @MainActor @Suite("PlayerInteraction")
  struct StationPlayerInteraction {
    @Test("Plays a station when it is tapped")
    func testPlaysAStationWhenItIsTapped() {
      let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
      let station: RadioStation = .mock

      let stationListModel = StationListModel(stationPlayer: stationPlayerMock)
      stationListModel.stationSelected(station)

      #expect(stationPlayerMock.callsToPlay.count == 1)
      #expect(stationPlayerMock.callsToPlay.first?.id == station.id)

    }
  }
}
