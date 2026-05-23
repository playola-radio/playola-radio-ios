//
//  SeriesListPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct SeriesListPageModelTests {
  @Test
  func testViewAppearedCallsGetAiringsAPI() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let apiCalled = LockIsolated(false)
    let passedJwt = LockIsolated<String?>(nil)

    await withDependencies {
      $0.date.now = Date()
      $0.api.getAirings = { jwt, _ in
        apiCalled.setValue(true)
        passedJwt.setValue(jwt)
        return []
      }
    } operation: {
      let model = SeriesListPageModel()

      await model.viewAppeared()

      #expect(apiCalled.value)
      #expect(passedJwt.value == "test-jwt")
    }
  }

  @Test
  func testViewAppearedPopulatesShowsGroupedByShow() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()
    let show1 = Show.mockWith(id: "show-1", title: "Morning Show")
    let show2 = Show.mockWith(id: "show-2", title: "Evening Show")

    let airings = [
      Airing.mockWith(
        id: "airing-1",
        airtime: now.addingTimeInterval(86400),
        episode: .mockWith(id: "ep-1", durationMS: 3_600_000, show: show1)
      ),
      Airing.mockWith(
        id: "airing-2",
        airtime: now.addingTimeInterval(86400 * 2),
        episode: .mockWith(id: "ep-2", durationMS: 3_600_000, show: show1)
      ),
      Airing.mockWith(
        id: "airing-3",
        airtime: now.addingTimeInterval(86400 * 3),
        episode: .mockWith(id: "ep-3", durationMS: 3_600_000, show: show2)
      ),
    ]

    await withDependencies {
      $0.date.now = now
      $0.api.getAirings = { _, _ in airings }
    } operation: {
      let model = SeriesListPageModel()

      await model.viewAppeared()

      #expect(model.shows.count == 2)
      let show1Group = model.shows.first { $0.show.id == "show-1" }
      let show2Group = model.shows.first { $0.show.id == "show-2" }
      #expect(show1Group?.airings.count == 2)
      #expect(show2Group?.airings.count == 1)
    }
  }

  @Test
  func testViewAppearedShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.api.getAirings = { _, _ in
        throw APIError.dataNotValid
      }
    } operation: {
      let model = SeriesListPageModel()

      await model.viewAppeared()

      #expect(model.presentedAlert != nil)
    }
  }

  @Test
  func testViewAppearedDoesNotCallAPIWithoutJWT() async {
    @Shared(.auth) var auth = Auth(jwt: nil)
    let apiCalled = LockIsolated(false)

    await withDependencies {
      $0.api.getAirings = { _, _ in
        apiCalled.setValue(true)
        return []
      }
    } operation: {
      let model = SeriesListPageModel()

      await model.viewAppeared()

      #expect(!apiCalled.value)
    }
  }

  @Test
  func testViewAppearedFiltersOutEndedAirings() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date()
    let show = Show.mockWith(id: "show-1", title: "Test Show")

    let airings = [
      // Ended airing (started 2 hours ago, 1 hour duration)
      Airing.mockWith(
        id: "ended-airing",
        airtime: now.addingTimeInterval(-7200),
        episode: .mockWith(id: "ep-1", durationMS: 3_600_000, show: show)
      ),
      // Currently live (started 30 min ago, 1 hour duration)
      Airing.mockWith(
        id: "live-airing",
        airtime: now.addingTimeInterval(-1800),
        episode: .mockWith(id: "ep-2", durationMS: 3_600_000, show: show)
      ),
      // Upcoming airing (starts in 1 hour)
      Airing.mockWith(
        id: "upcoming-airing",
        airtime: now.addingTimeInterval(3600),
        episode: .mockWith(id: "ep-3", durationMS: 3_600_000, show: show)
      ),
    ]

    await withDependencies {
      $0.date.now = now
      $0.api.getAirings = { _, _ in airings }
    } operation: {
      let model = SeriesListPageModel()

      await model.viewAppeared()

      #expect(model.shows.count == 1)
      let showGroup = model.shows.first
      #expect(showGroup?.airings.count == 2)
      #expect(showGroup?.airings.contains { $0.id == "live-airing" } ?? false)
      #expect(showGroup?.airings.contains { $0.id == "upcoming-airing" } ?? false)
      #expect(!(showGroup?.airings.contains { $0.id == "ended-airing" } ?? true))
    }
  }
}
