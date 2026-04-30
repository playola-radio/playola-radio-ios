//
//  SeriesCardTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class SeriesCardModelTests: XCTestCase {
  func testRemindMeTappedCallsSubscribeAPI() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let subscribeCalled = LockIsolated(false)
    let subscribedStationId = LockIsolated<String?>(nil)

    await withDependencies {
      $0.api.subscribeToStationNotifications = { _, stationId in
        subscribeCalled.setValue(true)
        subscribedStationId.setValue(stationId)
        return self.mockSubscription(stationId: stationId)
      }
    } operation: {
      let model = SeriesCardModel(
        showWithAirings: mockShowWithAirings(stationId: "station-123"),
        subscriptionStatus: .notSubscribed
      )

      await model.remindMeTapped()

      XCTAssertTrue(subscribeCalled.value)
      XCTAssertEqual(subscribedStationId.value, "station-123")
    }
  }

  func testRemindMeTappedUpdatesStatusToSubscribed() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.subscribeToStationNotifications = { _, stationId in
        return self.mockSubscription(stationId: stationId)
      }
    } operation: {
      let model = SeriesCardModel(
        showWithAirings: mockShowWithAirings(stationId: "station-123"),
        subscriptionStatus: .notSubscribed
      )

      await model.remindMeTapped()

      XCTAssertEqual(model.subscriptionStatus, .subscribed)
    }
  }

  func testRemindMeTappedShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.subscribeToStationNotifications = { _, _ in
        throw APIError.dataNotValid
      }
    } operation: {
      let model = SeriesCardModel(
        showWithAirings: mockShowWithAirings(stationId: "station-123"),
        subscriptionStatus: .notSubscribed
      )

      await model.remindMeTapped()

      XCTAssertNotNil(model.presentedAlert)
    }
  }

  func testRemindMeTappedDoesNotCallAPIWithoutJWT() async {
    @Shared(.auth) var auth = Auth(jwt: nil)
    let subscribeCalled = LockIsolated(false)

    await withDependencies {
      $0.api.subscribeToStationNotifications = { _, _ in
        subscribeCalled.setValue(true)
        throw APIError.dataNotValid
      }
    } operation: {
      let model = SeriesCardModel(
        showWithAirings: mockShowWithAirings(stationId: "station-123"),
        subscriptionStatus: .notSubscribed
      )

      await model.remindMeTapped()

      XCTAssertFalse(subscribeCalled.value)
    }
  }

  func testRemindMeTappedDoesNotCallAPIWithoutStation() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let subscribeCalled = LockIsolated(false)

    await withDependencies {
      $0.api.subscribeToStationNotifications = { _, _ in
        subscribeCalled.setValue(true)
        throw APIError.dataNotValid
      }
    } operation: {
      let model = SeriesCardModel(
        showWithAirings: mockShowWithAirings(stationId: nil),
        subscriptionStatus: .notSubscribed
      )

      await model.remindMeTapped()

      XCTAssertFalse(subscribeCalled.value)
    }
  }

  func testRemindMeTappedSetsIsSubscribingDuringRequest() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let wasSubscribingDuringCall = LockIsolated(false)

    await withDependencies {
      $0.api.subscribeToStationNotifications = { _, stationId in
        wasSubscribingDuringCall.setValue(true)
        return self.mockSubscription(stationId: stationId)
      }
    } operation: {
      let model = SeriesCardModel(
        showWithAirings: mockShowWithAirings(stationId: "station-123"),
        subscriptionStatus: .notSubscribed
      )

      await model.remindMeTapped()

      XCTAssertTrue(wasSubscribingDuringCall.value)
      XCTAssertFalse(model.isSubscribing)
    }
  }

  // MARK: - Helpers

  private func mockShowWithAirings(stationId: String?) -> ShowWithAirings {
    ShowWithAirings(
      show: .mockWith(title: "Test Show"),
      station: stationId != nil ? .mockWith(id: stationId!) : nil,
      airings: [.mockWith()]
    )
  }

  nonisolated private func mockSubscription(stationId: String) -> PushNotificationSubscription {
    PushNotificationSubscription(
      id: "sub-\(stationId)",
      userId: "user-1",
      stationId: stationId,
      isSubscribed: true,
      optedOutAt: nil,
      autoSubscribedAt: nil,
      manualSubscribedAt: Date(),
      createdAt: Date(),
      updatedAt: Date()
    )
  }
}
