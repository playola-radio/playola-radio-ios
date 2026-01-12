//
//  SeriesCardTests.swift
//  PlayolaRadio
//

import Dependencies
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class SeriesCardModelTests: XCTestCase {
  func testRemindMeTappedCallsSubscribeAPI() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var subscribeCalled = false
    var subscribedStationId: String?

    await withDependencies {
      $0.api.subscribeToStationNotifications = { _, stationId in
        subscribeCalled = true
        subscribedStationId = stationId
        return self.mockSubscription(stationId: stationId)
      }
    } operation: {
      let model = SeriesCardModel(
        showWithAirings: mockShowWithAirings(stationId: "station-123"),
        subscriptionStatus: .notSubscribed
      )

      await model.remindMeTapped()

      XCTAssertTrue(subscribeCalled)
      XCTAssertEqual(subscribedStationId, "station-123")
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
    var subscribeCalled = false

    await withDependencies {
      $0.api.subscribeToStationNotifications = { _, _ in
        subscribeCalled = true
        throw APIError.dataNotValid
      }
    } operation: {
      let model = SeriesCardModel(
        showWithAirings: mockShowWithAirings(stationId: "station-123"),
        subscriptionStatus: .notSubscribed
      )

      await model.remindMeTapped()

      XCTAssertFalse(subscribeCalled)
    }
  }

  func testRemindMeTappedDoesNotCallAPIWithoutStation() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var subscribeCalled = false

    await withDependencies {
      $0.api.subscribeToStationNotifications = { _, _ in
        subscribeCalled = true
        throw APIError.dataNotValid
      }
    } operation: {
      let model = SeriesCardModel(
        showWithAirings: mockShowWithAirings(stationId: nil),
        subscriptionStatus: .notSubscribed
      )

      await model.remindMeTapped()

      XCTAssertFalse(subscribeCalled)
    }
  }

  func testRemindMeTappedSetsIsSubscribingDuringRequest() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    var wasSubscribingDuringCall = false

    await withDependencies {
      $0.api.subscribeToStationNotifications = { _, stationId in
        await MainActor.run {
          wasSubscribingDuringCall = true
        }
        return self.mockSubscription(stationId: stationId)
      }
    } operation: {
      let model = SeriesCardModel(
        showWithAirings: mockShowWithAirings(stationId: "station-123"),
        subscriptionStatus: .notSubscribed
      )

      await model.remindMeTapped()

      XCTAssertTrue(wasSubscribingDuringCall)
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

  private func mockSubscription(stationId: String) -> PushNotificationSubscription {
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
