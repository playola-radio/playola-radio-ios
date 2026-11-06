//
//  SeriesListPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct SeriesListPageModelTests {
  @Test
  func testViewAppearedReportsNonNetworkLoadFailure() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let reportCount = LockIsolated(0)

    await withDependencies {
      $0.api.getAirings = { _, _ in throw APIError.dataNotValid }
      $0.errorReporting.reportError = { _, _ in reportCount.withValue { $0 += 1 } }
    } operation: {
      let model = SeriesListPageModel()
      await model.viewAppeared()
    }

    expectNoDifference(reportCount.value, 1)
  }

  @Test
  func testViewAppearedDoesNotReportNetworkLoadFailure() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let reportCount = LockIsolated(0)

    await withDependencies {
      $0.api.getAirings = { _, _ in throw URLError(.notConnectedToInternet) }
      $0.errorReporting.reportError = { _, _ in reportCount.withValue { $0 += 1 } }
    } operation: {
      let model = SeriesListPageModel()
      await model.viewAppeared()
    }

    expectNoDifference(reportCount.value, 0)
  }

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
  func testViewAppearedShowsToastOnError() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let shownToasts = LockIsolated<[PlayolaToast]>([])

    await withDependencies {
      $0.api.getAirings = { _, _ in
        throw APIError.dataNotValid
      }
      $0.toast.show = { toast in shownToasts.withValue { $0.append(toast) } }
    } operation: {
      let model = SeriesListPageModel()

      await model.viewAppeared()

      expectNoDifference(shownToasts.value.map(\.message), ["The radio shows couldn't load."])
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

  @Test
  func testOlderLoadFinishingLastDoesNotReplaceNewerShows() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date(timeIntervalSince1970: 1_000_000)
    let (loadStarted, loadStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseOlderLoad, releaseOlderLoadContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseNewerLoad, releaseNewerLoadContinuation) = AsyncStream.makeStream(of: Void.self)
    let loadCount = LockIsolated(0)

    let model = withDependencies {
      $0.date.now = now
      $0.api.getAirings = { _, _ in
        let isOlderLoad = loadCount.withValue {
          $0 += 1
          return $0 == 1
        }
        loadStartedContinuation.yield(())
        var releaseIterator =
          (isOlderLoad ? releaseOlderLoad : releaseNewerLoad).makeAsyncIterator()
        _ = await releaseIterator.next()
        return [Self.upcomingAiring(showId: isOlderLoad ? "older-show" : "newer-show", now: now)]
      }
    } operation: {
      SeriesListPageModel()
    }

    let olderLoad = Task { await model.viewAppeared() }
    var loadStartedIterator = loadStarted.makeAsyncIterator()
    _ = await loadStartedIterator.next()
    let newerLoad = Task { await model.viewAppeared() }
    _ = await loadStartedIterator.next()
    releaseNewerLoadContinuation.yield(())
    releaseNewerLoadContinuation.finish()
    await newerLoad.value
    releaseOlderLoadContinuation.yield(())
    releaseOlderLoadContinuation.finish()
    await olderLoad.value

    expectNoDifference(model.shows.map(\.show.id), ["newer-show"])
    expectNoDifference(model.isLoading, false)
  }

  @Test
  func testOlderLoadFinishingFirstKeepsLoadingUntilNewerLoadFinishes() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date(timeIntervalSince1970: 1_000_000)
    let (loadStarted, loadStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseOlderLoad, releaseOlderLoadContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseNewerLoad, releaseNewerLoadContinuation) = AsyncStream.makeStream(of: Void.self)
    let loadCount = LockIsolated(0)

    let model = withDependencies {
      $0.date.now = now
      $0.api.getAirings = { _, _ in
        let isOlderLoad = loadCount.withValue {
          $0 += 1
          return $0 == 1
        }
        loadStartedContinuation.yield(())
        var releaseIterator =
          (isOlderLoad ? releaseOlderLoad : releaseNewerLoad).makeAsyncIterator()
        _ = await releaseIterator.next()
        return isOlderLoad ? [Self.upcomingAiring(showId: "older-show", now: now)] : []
      }
    } operation: {
      SeriesListPageModel()
    }

    let olderLoad = Task { await model.viewAppeared() }
    var loadStartedIterator = loadStarted.makeAsyncIterator()
    _ = await loadStartedIterator.next()
    let newerLoad = Task { await model.viewAppeared() }
    _ = await loadStartedIterator.next()
    releaseOlderLoadContinuation.yield(())
    releaseOlderLoadContinuation.finish()
    await olderLoad.value

    expectNoDifference(model.isLoading, true)
    expectNoDifference(model.shows.map(\.show.id), [])

    releaseNewerLoadContinuation.yield(())
    releaseNewerLoadContinuation.finish()
    await newerLoad.value

    expectNoDifference(model.isLoading, false)
  }

  @Test
  func testOlderLoadFailingLastShowsNoToast() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date(timeIntervalSince1970: 1_000_000)
    let (loadStarted, loadStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseOlderLoad, releaseOlderLoadContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseNewerLoad, releaseNewerLoadContinuation) = AsyncStream.makeStream(of: Void.self)
    let loadCount = LockIsolated(0)
    let shownToasts = LockIsolated<[PlayolaToast]>([])

    let model = withDependencies {
      $0.date.now = now
      $0.api.getAirings = { _, _ in
        let isOlderLoad = loadCount.withValue {
          $0 += 1
          return $0 == 1
        }
        loadStartedContinuation.yield(())
        var releaseIterator =
          (isOlderLoad ? releaseOlderLoad : releaseNewerLoad).makeAsyncIterator()
        _ = await releaseIterator.next()
        if isOlderLoad { throw APIError.dataNotValid }
        return [Self.upcomingAiring(showId: "newer-show", now: now)]
      }
      $0.toast.show = { toast in shownToasts.withValue { $0.append(toast) } }
    } operation: {
      SeriesListPageModel()
    }

    let olderLoad = Task { await model.viewAppeared() }
    var loadStartedIterator = loadStarted.makeAsyncIterator()
    _ = await loadStartedIterator.next()
    let newerLoad = Task { await model.viewAppeared() }
    _ = await loadStartedIterator.next()
    releaseNewerLoadContinuation.yield(())
    releaseNewerLoadContinuation.finish()
    await newerLoad.value
    releaseOlderLoadContinuation.yield(())
    releaseOlderLoadContinuation.finish()
    await olderLoad.value

    expectNoDifference(model.shows.map(\.show.id), ["newer-show"])
    expectNoDifference(shownToasts.value.map(\.message), [])
  }

  nonisolated private static func upcomingAiring(showId: String, now: Date) -> Airing {
    Airing.mockWith(
      id: "airing-\(showId)",
      airtime: now.addingTimeInterval(3600),
      episode: .mockWith(
        id: "ep-\(showId)", durationMS: 3_600_000, show: .mockWith(id: showId, title: showId))
    )
  }
}
