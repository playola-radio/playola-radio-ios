//
//  AiringsListTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//

import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class AiringsListTests: XCTestCase {
  // MARK: - Initialization Tests

  func testInitWithDefaultValues() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let model = AiringsListModel()

      XCTAssertNil(model.stationId)
      XCTAssertEqual(model.airings.count, 0)
      XCTAssertEqual(model.tileModels.count, 0)
      XCTAssertNil(model.presentedAlert)
    }
  }

  func testInitWithProvidedValues() {
    withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    } operation: {
      let airings = [
        Airing.mockWith(id: "airing1"),
        Airing.mockWith(id: "airing2"),
        Airing.mockWith(id: "airing3"),
      ]
      let stationId = "test-station-id"

      let model = AiringsListModel(stationId: stationId, airings: airings)

      XCTAssertEqual(model.stationId, stationId)
      XCTAssertEqual(model.airings.count, 3)
      XCTAssertEqual(model.airings[0].id, "airing1")
      XCTAssertEqual(model.airings[1].id, "airing2")
      XCTAssertEqual(model.airings[2].id, "airing3")

      XCTAssertEqual(model.tileModels.count, 3)
      XCTAssertEqual(model.tileModels[0].airing.id, "airing1")
      XCTAssertEqual(model.tileModels[1].airing.id, "airing2")
      XCTAssertEqual(model.tileModels[2].airing.id, "airing3")
    }
  }

  // MARK: - loadAirings Tests

  func testLoadAiringsSuccessNoFiltering() async {
    let mockAirings = [
      Airing.mockWith(id: "airing1"),
      Airing.mockWith(id: "airing2"),
    ]

    var capturedToken: String?
    var capturedStationId: String??

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.getAirings = { jwtToken, stationId in
        capturedToken = jwtToken
        capturedStationId = stationId
        return mockAirings
      }
    } operation: {
      let model = AiringsListModel()

      XCTAssertEqual(model.airings.count, 0)

      await model.loadAirings(jwtToken: "test-token")

      XCTAssertEqual(capturedToken, "test-token")
      XCTAssertNil(capturedStationId!)
      XCTAssertEqual(model.airings.count, 2)
      XCTAssertEqual(model.airings[0].id, "airing1")
      XCTAssertEqual(model.airings[1].id, "airing2")

      XCTAssertEqual(model.tileModels.count, 2)
      XCTAssertEqual(model.tileModels[0].airing.id, "airing1")
      XCTAssertEqual(model.tileModels[1].airing.id, "airing2")
    }
  }

  func testLoadAiringsSuccessWithStationIdFiltering() async {
    let mockAirings = [
      Airing.mockWith(id: "airing1", stationId: "station-123"),
      Airing.mockWith(id: "airing2", stationId: "station-123"),
    ]

    var capturedToken: String?
    var capturedStationId: String??

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.getAirings = { jwtToken, stationId in
        capturedToken = jwtToken
        capturedStationId = stationId
        return mockAirings
      }
    } operation: {
      let model = AiringsListModel(stationId: "station-123")

      await model.loadAirings(jwtToken: "test-token")

      XCTAssertEqual(capturedToken, "test-token")
      XCTAssertEqual(capturedStationId, "station-123")
      XCTAssertEqual(model.airings.count, 2)
      XCTAssertEqual(model.airings[0].stationId, "station-123")
      XCTAssertEqual(model.airings[1].stationId, "station-123")
    }
  }

  func testLoadAiringsErrorHandling() async {
    struct TestError: Error {}

    let initialAirings = [Airing.mockWith(id: "initial")]

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.getAirings = { _, _ in
        throw TestError()
      }
    } operation: {
      let model = AiringsListModel(airings: initialAirings)

      XCTAssertEqual(model.airings.count, 1)

      await model.loadAirings(jwtToken: "test-token")

      XCTAssertEqual(model.airings.count, 1)
      XCTAssertEqual(model.airings[0].id, "initial")
    }
  }

  // MARK: - Shared State Tests

  func testLoadAiringsUpdatesSharedState() async {
    let mockAirings = [
      Airing.mockWith(id: "airing1"),
      Airing.mockWith(id: "airing2"),
    ]

    @Shared(.airings) var sharedAirings: IdentifiedArrayOf<Airing> = []

    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.getAirings = { _, _ in
        return mockAirings
      }
    } operation: {
      XCTAssertEqual(sharedAirings.count, 0)

      let model = AiringsListModel()
      await model.loadAirings(jwtToken: "test-token")

      XCTAssertEqual(sharedAirings.count, 2)
      XCTAssertEqual(sharedAirings[0].id, "airing1")
      XCTAssertEqual(sharedAirings[1].id, "airing2")
    }
  }

  // MARK: - Subscription Tests

  func testLoadSubscriptionsUpdatesSubscribedStationIds() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let mockSubscriptions = [
      PushNotificationSubscriptionWithStation(
        id: "sub-1", userId: "user-1", stationId: "station-1", isSubscribed: true,
        optedOutAt: nil, autoSubscribedAt: nil, manualSubscribedAt: nil,
        createdAt: now, updatedAt: now, station: .mock
      ),
      PushNotificationSubscriptionWithStation(
        id: "sub-2", userId: "user-1", stationId: "station-2", isSubscribed: false,
        optedOutAt: nil, autoSubscribedAt: nil, manualSubscribedAt: nil,
        createdAt: now, updatedAt: now, station: .mock
      ),
      PushNotificationSubscriptionWithStation(
        id: "sub-3", userId: "user-1", stationId: "station-3", isSubscribed: true,
        optedOutAt: nil, autoSubscribedAt: nil, manualSubscribedAt: nil,
        createdAt: now, updatedAt: now, station: .mock
      ),
    ]

    await withDependencies {
      $0.date.now = now
      $0.api.getPushNotificationSubscriptions = { _ in
        return mockSubscriptions
      }
    } operation: {
      let model = AiringsListModel()

      XCTAssertTrue(model.subscribedStationIds.isEmpty)

      await model.loadSubscriptions(jwtToken: "test-token")

      XCTAssertEqual(model.subscribedStationIds.count, 2)
      XCTAssertTrue(model.subscribedStationIds.contains("station-1"))
      XCTAssertFalse(model.subscribedStationIds.contains("station-2"))
      XCTAssertTrue(model.subscribedStationIds.contains("station-3"))
    }
  }

  func testTileModelsReflectSubscriptionState() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let mockAirings = [
      Airing.mockWith(id: "airing1", stationId: "station-1"),
      Airing.mockWith(id: "airing2", stationId: "station-2"),
    ]

    let mockSubscriptions = [
      PushNotificationSubscriptionWithStation(
        id: "sub-1", userId: "user-1", stationId: "station-1", isSubscribed: true,
        optedOutAt: nil, autoSubscribedAt: nil, manualSubscribedAt: nil,
        createdAt: now, updatedAt: now, station: .mock
      ),
      PushNotificationSubscriptionWithStation(
        id: "sub-2", userId: "user-1", stationId: "station-2", isSubscribed: false,
        optedOutAt: nil, autoSubscribedAt: nil, manualSubscribedAt: nil,
        createdAt: now, updatedAt: now, station: .mock
      ),
    ]

    await withDependencies {
      $0.date.now = now
      $0.api.getAirings = { _, _ in mockAirings }
      $0.api.getPushNotificationSubscriptions = { _ in mockSubscriptions }
    } operation: {
      let model = AiringsListModel()

      await model.loadAirings(jwtToken: "test-token")
      await model.loadSubscriptions(jwtToken: "test-token")

      XCTAssertEqual(model.tileModels.count, 2)
      XCTAssertTrue(model.tileModels[0].isSubscribedToStationNotifications)
      XCTAssertFalse(model.tileModels[1].isSubscribedToStationNotifications)
    }
  }
}
