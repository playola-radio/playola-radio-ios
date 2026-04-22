//
//  NotificationsSettingsPageTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/2/26.
//

import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class NotificationsSettingsPageTests: XCTestCase {
  func testViewAppearedLoadsSubscriptions() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.stationLists) var stationLists = mockStationLists()
    let mockSubs = [
      mockSubscriptionWithStation(stationId: "station-1", isSubscribed: true)
    ]

    await withDependencies {
      $0.api.getPushNotificationSubscriptions = { _ in mockSubs }
    } operation: {
      let model = NotificationsSettingsPageModel()

      await model.viewAppeared()

      XCTAssertEqual(model.stationItems.count, 2)
      XCTAssertTrue(model.isSubscribed(stationId: "station-1"))
      XCTAssertFalse(model.isSubscribed(stationId: "station-2"))
    }
  }

  func testViewAppearedShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.stationLists) var stationLists = mockStationLists()

    await withDependencies {
      $0.api.getPushNotificationSubscriptions = { _ in
        throw APIError.dataNotValid
      }
    } operation: {
      let model = NotificationsSettingsPageModel()

      await model.viewAppeared()

      XCTAssertNotNil(model.presentedAlert)
    }
  }

  func testStationItemsShowsAllStations() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.stationLists) var stationLists = mockStationLists()
    let mockSubs = [
      mockSubscriptionWithStation(stationId: "station-1", isSubscribed: true)
    ]

    await withDependencies {
      $0.api.getPushNotificationSubscriptions = { _ in mockSubs }
    } operation: {
      let model = NotificationsSettingsPageModel()
      await model.viewAppeared()

      XCTAssertEqual(model.stationItems.count, 2)

      let station1Item = model.stationItems.first { $0.station.id == "station-1" }
      let station2Item = model.stationItems.first { $0.station.id == "station-2" }

      XCTAssertNotNil(station1Item)
      XCTAssertNotNil(station2Item)
      XCTAssertTrue(station1Item?.isSubscribed ?? false)
      XCTAssertFalse(station2Item?.isSubscribed ?? true)
    }
  }

  func testStationItemStatusTextForNotSubscribed() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.stationLists) var stationLists = mockStationLists()

    await withDependencies {
      $0.api.getPushNotificationSubscriptions = { _ in [] }
    } operation: {
      let model = NotificationsSettingsPageModel()
      await model.viewAppeared()

      let item = model.stationItems.first
      XCTAssertEqual(item?.statusText, "Not subscribed")
      XCTAssertFalse(item?.isSubscribed ?? true)
    }
  }

  func testAllNotificationsEnabledWhenAllSubscribed() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.stationLists) var stationLists = mockStationLists()
    let mockSubs = [
      mockSubscriptionWithStation(stationId: "station-1", isSubscribed: true),
      mockSubscriptionWithStation(stationId: "station-2", isSubscribed: true),
    ]

    await withDependencies {
      $0.api.getPushNotificationSubscriptions = { _ in mockSubs }
    } operation: {
      let model = NotificationsSettingsPageModel()
      await model.viewAppeared()

      XCTAssertTrue(model.allNotificationsEnabled)
    }
  }

  func testAllNotificationsDisabledWhenSomeUnsubscribed() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.stationLists) var stationLists = mockStationLists()
    let mockSubs = [
      mockSubscriptionWithStation(stationId: "station-1", isSubscribed: true),
      mockSubscriptionWithStation(stationId: "station-2", isSubscribed: false),
    ]

    await withDependencies {
      $0.api.getPushNotificationSubscriptions = { _ in mockSubs }
    } operation: {
      let model = NotificationsSettingsPageModel()
      await model.viewAppeared()

      XCTAssertFalse(model.allNotificationsEnabled)
      XCTAssertTrue(model.someNotificationsEnabled)
    }
  }

  func testToggleSubscriptionCallsUnsubscribeWhenSubscribed() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.stationLists) var stationLists = mockStationLists()
    let mockSubs = [
      mockSubscriptionWithStation(stationId: "station-1", isSubscribed: true)
    ]
    var unsubscribeCalled = false
    var unsubscribedStationId: String?

    await withDependencies {
      $0.api.getPushNotificationSubscriptions = { _ in mockSubs }
      $0.api.unsubscribeFromStationNotifications = { _, stationId in
        unsubscribeCalled = true
        unsubscribedStationId = stationId
        return self.mockSubscription(stationId: stationId, isSubscribed: false)
      }
    } operation: {
      let model = NotificationsSettingsPageModel()
      await model.viewAppeared()

      await model.toggleSubscription(for: "station-1")

      XCTAssertTrue(unsubscribeCalled)
      XCTAssertEqual(unsubscribedStationId, "station-1")
    }
  }

  func testToggleSubscriptionCallsSubscribeWhenNotSubscribed() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.stationLists) var stationLists = mockStationLists()
    var subscribeCalled = false
    var subscribedStationId: String?

    await withDependencies {
      $0.api.getPushNotificationSubscriptions = { _ in [] }
      $0.api.subscribeToStationNotifications = { _, stationId in
        subscribeCalled = true
        subscribedStationId = stationId
        return self.mockSubscription(stationId: stationId, isSubscribed: true)
      }
    } operation: {
      let model = NotificationsSettingsPageModel()
      await model.viewAppeared()

      await model.toggleSubscription(for: "station-1")

      XCTAssertTrue(subscribeCalled)
      XCTAssertEqual(subscribedStationId, "station-1")
    }
  }

  func testToggleSubscriptionShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.stationLists) var stationLists = mockStationLists()
    let mockSubs = [
      mockSubscriptionWithStation(stationId: "station-1", isSubscribed: true)
    ]

    await withDependencies {
      $0.api.getPushNotificationSubscriptions = { _ in mockSubs }
      $0.api.unsubscribeFromStationNotifications = { _, _ in
        throw APIError.dataNotValid
      }
    } operation: {
      let model = NotificationsSettingsPageModel()
      await model.viewAppeared()
      model.presentedAlert = nil

      await model.toggleSubscription(for: "station-1")

      XCTAssertNotNil(model.presentedAlert)
    }
  }

  func testInactiveStationsAreFilteredOut() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.stationLists) var stationLists = mockStationListsWithInactiveStation()

    await withDependencies {
      $0.api.getPushNotificationSubscriptions = { _ in [] }
    } operation: {
      let model = NotificationsSettingsPageModel()
      await model.viewAppeared()

      XCTAssertEqual(model.stationItems.count, 2)
      XCTAssertNotNil(model.stationItems.first { $0.station.id == "station-1" })
      XCTAssertNotNil(model.stationItems.first { $0.station.id == "station-2" })
      XCTAssertNil(model.stationItems.first { $0.station.id == "inactive-station" })
    }
  }

  func testStationsAreSortedByCuratorName() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.stationLists) var stationLists = mockStationListsUnsorted()

    await withDependencies {
      $0.api.getPushNotificationSubscriptions = { _ in [] }
    } operation: {
      let model = NotificationsSettingsPageModel()
      await model.viewAppeared()

      XCTAssertEqual(model.stationItems.count, 3)
      XCTAssertEqual(model.stationItems[0].station.curatorName, "Alice")
      XCTAssertEqual(model.stationItems[1].station.curatorName, "Bob")
      XCTAssertEqual(model.stationItems[2].station.curatorName, "Charlie")
    }
  }

  // MARK: - Helper Methods

  private func mockStationLists() -> IdentifiedArrayOf<StationList> {
    let now = Date()
    return IdentifiedArray(uniqueElements: [
      StationList(
        id: "test-list",
        name: "Test List",
        slug: "test-list",
        hidden: false,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
        items: [
          APIStationItem(
            sortOrder: 0,
            visibility: .visible,
            station: Station.mockWith(id: "station-1", name: "Station 1"),
            urlStation: nil
          ),
          APIStationItem(
            sortOrder: 1,
            visibility: .visible,
            station: Station.mockWith(id: "station-2", name: "Station 2"),
            urlStation: nil
          ),
        ]
      )
    ])
  }

  private func mockStationListsUnsorted() -> IdentifiedArrayOf<StationList> {
    let now = Date()
    return IdentifiedArray(uniqueElements: [
      StationList(
        id: "test-list",
        name: "Test List",
        slug: "test-list",
        hidden: false,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
        items: [
          APIStationItem(
            sortOrder: 0,
            visibility: .visible,
            station: Station.mockWith(
              id: "station-charlie", name: "Charlie's Station", curatorName: "Charlie"),
            urlStation: nil
          ),
          APIStationItem(
            sortOrder: 1,
            visibility: .visible,
            station: Station.mockWith(
              id: "station-alice", name: "Alice's Station", curatorName: "Alice"),
            urlStation: nil
          ),
          APIStationItem(
            sortOrder: 2,
            visibility: .visible,
            station: Station.mockWith(id: "station-bob", name: "Bob's Station", curatorName: "Bob"),
            urlStation: nil
          ),
        ]
      )
    ])
  }

  private func mockStationListsWithInactiveStation() -> IdentifiedArrayOf<StationList> {
    let now = Date()
    return IdentifiedArray(uniqueElements: [
      StationList(
        id: "test-list",
        name: "Test List",
        slug: "test-list",
        hidden: false,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
        items: [
          APIStationItem(
            sortOrder: 0,
            visibility: .visible,
            station: Station.mockWith(id: "station-1", name: "Station 1"),
            urlStation: nil
          ),
          APIStationItem(
            sortOrder: 1,
            visibility: .visible,
            station: Station.mockWith(id: "station-2", name: "Station 2"),
            urlStation: nil
          ),
          APIStationItem(
            sortOrder: 2,
            visibility: .visible,
            station: Station(
              id: "inactive-station",
              name: "Inactive Station",
              curatorName: "Inactive Curator",
              imageUrl: "https://example.com/image.jpg",
              description: "An inactive station",
              active: false,
              createdAt: now,
              updatedAt: now
            ),
            urlStation: nil
          ),
        ]
      )
    ])
  }

  nonisolated private func mockSubscription(stationId: String, isSubscribed: Bool)
    -> PushNotificationSubscription
  {
    PushNotificationSubscription(
      id: "sub-\(stationId)",
      userId: "user-1",
      stationId: stationId,
      isSubscribed: isSubscribed,
      optedOutAt: isSubscribed ? nil : Date(),
      autoSubscribedAt: nil,
      manualSubscribedAt: isSubscribed ? Date() : nil,
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  private func mockSubscriptionWithStation(stationId: String, isSubscribed: Bool)
    -> PushNotificationSubscriptionWithStation
  {
    PushNotificationSubscriptionWithStation(
      id: "sub-\(stationId)",
      userId: "user-1",
      stationId: stationId,
      isSubscribed: isSubscribed,
      optedOutAt: isSubscribed ? nil : Date(),
      autoSubscribedAt: nil,
      manualSubscribedAt: isSubscribed ? Date() : nil,
      createdAt: Date(),
      updatedAt: Date(),
      station: Station.mockWith(id: stationId, name: "Station \(stationId)")
    )
  }
}
