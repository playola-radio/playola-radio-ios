//
//  ArtistDashboardTabRootTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ArtistDashboardTabRootTests {

  // MARK: - Test Helpers

  private let testStationId = "station-abc"

  private nonisolated static func testStation(active: Bool?) -> PlayolaPlayer.Station {
    PlayolaPlayer.Station(
      id: "station-abc",
      name: "Southern Lines Radio",
      curatorName: "Curator",
      imageUrl: String?.none,
      description: "",
      active: active,
      createdAt: Date(timeIntervalSince1970: 0),
      updatedAt: Date(timeIntervalSince1970: 0))
  }

  private func routeCase(_ route: ArtistDashboardTabRootModel.Route) -> String {
    switch route {
    case .loading: return "loading"
    case .active: return "active"
    case .setup: return "setup"
    case .failed: return "failed"
    }
  }

  // MARK: - Routing By Active Flag

  @Test func inactiveStationRoutesToSetupWithoutLoadingActiveDashboardData() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let healthCalls = LockIsolated(0)
    let listenerCalls = LockIsolated(0)
    let countsCalls = LockIsolated(0)

    let model = await withDependencies {
      $0.api.fetchStation = { _, _ in Self.testStation(active: false) }
      $0.api.getStationHealthScore = { _, _ in
        healthCalls.withValue { $0 += 1 }
        throw TestError.shouldNotBeCalled
      }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        listenerCalls.withValue { $0 += 1 }
        throw TestError.shouldNotBeCalled
      }
      $0.api.getListenerCounts = { _, _ in
        countsCalls.withValue { $0 += 1 }
        throw TestError.shouldNotBeCalled
      }
    } operation: {
      let model = ArtistDashboardTabRootModel()
      await model.viewAppeared()
      return model
    }

    expectNoDifference(routeCase(model.route), "setup")
    expectNoDifference(healthCalls.value, 0)
    expectNoDifference(listenerCalls.value, 0)
    expectNoDifference(countsCalls.value, 0)
  }

  @Test func activeStationRoutesToActiveDashboardWithoutLoadingSetupData() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let setupCalls = LockIsolated(0)
    let categoryCalls = LockIsolated(0)

    let model = await withDependencies {
      $0.api.fetchStation = { _, _ in Self.testStation(active: true) }
      $0.api.getStationSetupProgress = { _, _ in
        setupCalls.withValue { $0 += 1 }
        throw TestError.shouldNotBeCalled
      }
      $0.api.getDraftStationCategoryProgress = { _, _ in
        categoryCalls.withValue { $0 += 1 }
        throw TestError.shouldNotBeCalled
      }
    } operation: {
      let model = ArtistDashboardTabRootModel()
      await model.viewAppeared()
      return model
    }

    expectNoDifference(routeCase(model.route), "active")
    expectNoDifference(setupCalls.value, 0)
    expectNoDifference(categoryCalls.value, 0)
  }

  @Test func nilActiveTreatedAsActiveDashboard() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let model = await withDependencies {
      $0.api.fetchStation = { _, _ in Self.testStation(active: nil) }
    } operation: {
      let model = ArtistDashboardTabRootModel()
      await model.viewAppeared()
      return model
    }

    expectNoDifference(routeCase(model.route), "active")
  }

  // MARK: - Fetch Failure Handling

  @Test func missingStationRoutesToFailed() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let model = await withDependencies {
      $0.api.fetchStation = { _, _ in nil }
    } operation: {
      let model = ArtistDashboardTabRootModel()
      await model.viewAppeared()
      return model
    }

    expectNoDifference(routeCase(model.route), "failed")
  }

  @Test func fetchFailureRoutesToFailed() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let model = await withDependencies {
      $0.api.fetchStation = { _, _ in throw TestError.networkError }
    } operation: {
      let model = ArtistDashboardTabRootModel()
      await model.viewAppeared()
      return model
    }

    expectNoDifference(routeCase(model.route), "failed")
  }

  // MARK: - Preconditions

  @Test func missingAuthRoutesToFailedWithoutFetching() async {
    @Shared(.auth) var auth = Auth()
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let called = LockIsolated(false)
    let model = await withDependencies {
      $0.api.fetchStation = { _, _ in
        called.setValue(true)
        return Self.testStation(active: true)
      }
    } operation: {
      let model = ArtistDashboardTabRootModel()
      await model.viewAppeared()
      return model
    }

    expectNoDifference(routeCase(model.route), "failed")
    expectNoDifference(called.value, false)
  }

  @Test func notBroadcastingRoutesToFailedWithoutFetching() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let called = LockIsolated(false)
    let model = await withDependencies {
      $0.api.fetchStation = { _, _ in
        called.setValue(true)
        return Self.testStation(active: true)
      }
    } operation: {
      let model = ArtistDashboardTabRootModel()
      await model.viewAppeared()
      return model
    }

    expectNoDifference(routeCase(model.route), "failed")
    expectNoDifference(called.value, false)
  }

  // MARK: - Reload Staleness

  @Test func staleInFlightFetchDoesNotClobberNewerRoute() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let releaseFirst = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let callCount = LockIsolated(0)

    let model = withDependencies {
      $0.api.fetchStation = { _, _ in
        let isFirst = callCount.withValue { count in
          count += 1
          return count == 1
        }
        if isFirst {
          firstStarted.continuation.yield()
          await withCheckedContinuation { releaseFirst.setValue($0) }
          return Self.testStation(active: false)
        }
        return Self.testStation(active: true)
      }
    } operation: {
      ArtistDashboardTabRootModel()
    }

    let taskA = Task { await model.viewAppeared() }
    var iterator = firstStarted.stream.makeAsyncIterator()
    await iterator.next()

    await model.viewAppeared()
    expectNoDifference(routeCase(model.route), "active")

    releaseFirst.value?.resume()
    await taskA.value

    expectNoDifference(routeCase(model.route), "active")
  }

  @Test func staleInFlightFetchDoesNotClobberFailedFromNoAuthReappearance() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let releaseFirst = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
    let firstStarted = AsyncStream.makeStream(of: Void.self)

    let model = withDependencies {
      $0.api.fetchStation = { _, _ in
        firstStarted.continuation.yield()
        await withCheckedContinuation { releaseFirst.setValue($0) }
        return Self.testStation(active: false)
      }
    } operation: {
      ArtistDashboardTabRootModel()
    }

    // First appearance starts a slow fetch while auth is present.
    let taskA = Task { await model.viewAppeared() }
    var iterator = firstStarted.stream.makeAsyncIterator()
    await iterator.next()

    // Auth is cleared, then a second appearance early-returns to `.failed`. The fix bumps
    // `loadGeneration` before the guard, so the still-in-flight first fetch is now stale.
    $auth.withLock { $0 = Auth() }
    await model.viewAppeared()
    expectNoDifference(routeCase(model.route), "failed")

    // Releasing the stale fetch must not resurrect `.setup` over `.failed`.
    releaseFirst.value?.resume()
    await taskA.value
    expectNoDifference(routeCase(model.route), "failed")
  }
}

private enum TestError: Error {
  case networkError
  case shouldNotBeCalled
}
