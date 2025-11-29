//
//  ScheduledShowsListTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/8/25.
//

import Dependencies
import Foundation
import IdentifiedCollections
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class ScheduledShowsListTests: XCTestCase {
  // MARK: - Initialization Tests

  func testInitWithDefaultValues() {
    let model = ScheduledShowsListModel()

    XCTAssertNil(model.stationId)
    XCTAssertEqual(model.scheduledShows.count, 0)
    XCTAssertEqual(model.tileModels.count, 0)
    XCTAssertNil(model.presentedAlert)
  }

  func testInitWithProvidedValues() {
    let scheduledShows = [
      ScheduledShow.mockWith(id: "show1"),
      ScheduledShow.mockWith(id: "show2"),
      ScheduledShow.mockWith(id: "show3"),
    ]
    let stationId = "test-station-id"

    let model = ScheduledShowsListModel(stationId: stationId, scheduledShows: scheduledShows)

    XCTAssertEqual(model.stationId, stationId)
    XCTAssertEqual(model.scheduledShows.count, 3)
    XCTAssertEqual(model.scheduledShows[0].id, "show1")
    XCTAssertEqual(model.scheduledShows[1].id, "show2")
    XCTAssertEqual(model.scheduledShows[2].id, "show3")

    // Verify tileModels are created for each scheduledShow
    XCTAssertEqual(model.tileModels.count, 3)
    XCTAssertEqual(model.tileModels[0].scheduledShow.id, "show1")
    XCTAssertEqual(model.tileModels[1].scheduledShow.id, "show2")
    XCTAssertEqual(model.tileModels[2].scheduledShow.id, "show3")
  }

  // MARK: - loadScheduledShows Tests

  func testLoadScheduledShows_Success_NoFiltering() async {
    let mockShows = [
      ScheduledShow.mockWith(id: "show1"),
      ScheduledShow.mockWith(id: "show2"),
    ]

    var capturedToken: String?
    var capturedShowId: String??
    var capturedStationId: String??

    await withDependencies {
      $0.api.getScheduledShows = { jwtToken, showId, stationId in
        capturedToken = jwtToken
        capturedShowId = showId
        capturedStationId = stationId
        return mockShows
      }
    } operation: {
      let model = ScheduledShowsListModel()

      XCTAssertEqual(model.scheduledShows.count, 0)

      await model.loadScheduledShows(jwtToken: "test-token")

      XCTAssertEqual(capturedToken, "test-token")
      XCTAssertNil(capturedShowId!)
      XCTAssertNil(capturedStationId!)
      XCTAssertEqual(model.scheduledShows.count, 2)
      XCTAssertEqual(model.scheduledShows[0].id, "show1")
      XCTAssertEqual(model.scheduledShows[1].id, "show2")

      // Verify tileModels are updated
      XCTAssertEqual(model.tileModels.count, 2)
      XCTAssertEqual(model.tileModels[0].scheduledShow.id, "show1")
      XCTAssertEqual(model.tileModels[1].scheduledShow.id, "show2")
    }
  }

  func testLoadScheduledShows_Success_WithStationIdFiltering() async {
    let mockShows = [
      ScheduledShow.mockWith(id: "show1", stationId: "station-123"),
      ScheduledShow.mockWith(id: "show2", stationId: "station-123"),
    ]

    var capturedToken: String?
    var capturedShowId: String??
    var capturedStationId: String??

    await withDependencies {
      $0.api.getScheduledShows = { jwtToken, showId, stationId in
        capturedToken = jwtToken
        capturedShowId = showId
        capturedStationId = stationId
        return mockShows
      }
    } operation: {
      let model = ScheduledShowsListModel(stationId: "station-123")

      await model.loadScheduledShows(jwtToken: "test-token")

      XCTAssertEqual(capturedToken, "test-token")
      XCTAssertNil(capturedShowId!)
      XCTAssertEqual(capturedStationId, "station-123")
      XCTAssertEqual(model.scheduledShows.count, 2)
      XCTAssertEqual(model.scheduledShows[0].stationId, "station-123")
      XCTAssertEqual(model.scheduledShows[1].stationId, "station-123")
    }
  }

  func testLoadScheduledShows_ErrorHandling() async {
    struct TestError: Error {}

    let initialShows = [ScheduledShow.mockWith(id: "initial")]

    await withDependencies {
      $0.api.getScheduledShows = { _, _, _ in
        throw TestError()
      }
    } operation: {
      let model = ScheduledShowsListModel(scheduledShows: initialShows)

      XCTAssertEqual(model.scheduledShows.count, 1)

      await model.loadScheduledShows(jwtToken: "test-token")

      // scheduledShows should remain unchanged on error
      XCTAssertEqual(model.scheduledShows.count, 1)
      XCTAssertEqual(model.scheduledShows[0].id, "initial")
    }
  }

  // MARK: - Shared State Tests

  func testLoadScheduledShows_UpdatesSharedState() async {
    let mockShows = [
      ScheduledShow.mockWith(id: "show1"),
      ScheduledShow.mockWith(id: "show2"),
    ]

    @Shared(.scheduledShows) var sharedScheduledShows: IdentifiedArrayOf<ScheduledShow> = []

    await withDependencies {
      $0.api.getScheduledShows = { _, _, _ in
        return mockShows
      }
    } operation: {
      // Verify shared state starts empty
      XCTAssertEqual(sharedScheduledShows.count, 0)

      let model = ScheduledShowsListModel()
      await model.loadScheduledShows(jwtToken: "test-token")

      // Verify shared state is updated
      XCTAssertEqual(sharedScheduledShows.count, 2)
      XCTAssertEqual(sharedScheduledShows[0].id, "show1")
      XCTAssertEqual(sharedScheduledShows[1].id, "show2")
    }
  }
}
