//
//  StationListPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/13/25.
//

import Dependencies
import IdentifiedCollections
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class StationListPageTests: XCTestCase {
  // MARK: - View Appeared Tests

  func testViewAppeared_PopulatesFromInitialSharedStationLists() async {
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
            title: targetList.title,
            stations: targetList.stations.reversed()
          )
        ]
      )
    }

    XCTAssertEqual(model.selectedSegment, targetList.title)
    XCTAssertEqual(model.stationListsForDisplay.count, 1)
    XCTAssertEqual(model.stationListsForDisplay.first?.title, targetList.title)
  }

  func testSharedStationListsUpdates_ResetsSelectedSegmentWhenSegmentMissing() async {
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
          .map { StationList(id: $0.id, title: $0.title, stations: $0.stations) }
      )
    }

    let expectedVisibleAfterUpdate = stationLists.filter {
      $0.id != StationList.inDevelopmentListId
    }
    XCTAssertEqual(model.selectedSegment, "All")
    XCTAssertEqual(model.stationListsForDisplay, expectedVisibleAfterUpdate)
  }

  // MARK: - Player Interaction Tests

  func testPlayerInteraction_PlaysAStationWhenItIsTapped() async {
    let stationPlayerMock: StationPlayerMock = .mockStoppedPlayer()
    let station: RadioStation = .mock
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let stationListModel = withDependencies {
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      StationListModel(stationPlayer: stationPlayerMock)
    }

    await stationListModel.stationSelected(station)

    XCTAssertEqual(stationPlayerMock.callsToPlay.count, 1)
    XCTAssertEqual(stationPlayerMock.callsToPlay.first?.id, station.id)

    // Verify analytics events were tracked
    let events = capturedEvents.value
    XCTAssertEqual(events.count, 2)

    // First event should be tappedStationCard
    if case let .tappedStationCard(stationInfo, position, totalStations) = events[0] {
      XCTAssertEqual(stationInfo.id, station.id)
      XCTAssertEqual(position, 0)
      XCTAssertEqual(totalStations, 0)  // Empty list for this test
    } else {
      XCTFail("Expected tappedStationCard event, got: \(events[0])")
    }

    // Second event should be startedStation
    if case let .startedStation(stationInfo, entryPoint) = events[1] {
      XCTAssertEqual(stationInfo.id, station.id)
      XCTAssertEqual(entryPoint, "station_list")
    } else {
      XCTFail("Expected startedStation event, got: \(events[1])")
    }
  }
}
