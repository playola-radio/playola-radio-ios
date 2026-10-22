//
//  ArtistStationPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Observation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ArtistStationPageTests {

  // MARK: - Test Helpers

  private let testStationId = "station-abc"
  private let fixedNow = Date(timeIntervalSince1970: 1_000_000)

  private func spin(
    id: String,
    airtimeOffset: TimeInterval,
    title: String,
    artist: String,
    endOfMessageMS: Int = 180_000
  ) -> Spin {
    Spin.mockWith(
      id: id,
      airtime: fixedNow.addingTimeInterval(airtimeOffset),
      stationId: testStationId,
      audioBlock: .mockWith(title: title, artist: artist, endOfMessageMS: endOfMessageMS)
    )
  }

  private func makeModel(
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) async -> ArtistStationPageModel {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    return await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [] }
      configure(&$0)
    } operation: {
      let model = ArtistStationPageModel()
      await model.viewAppeared()
      return model
    }
  }

  // MARK: - Static Placeholder Content

  @Test func displaysPlaceholderHeader() {
    let model = ArtistStationPageModel()

    expectNoDifference(model.navigationTitle, "Station")
    expectNoDifference(model.stationName, "Reckless Radio")
  }

  @Test func displaysPlaceholderBroadcastChrome() {
    let model = ArtistStationPageModel()

    expectNoDifference(model.onAirLabel, "ON AIR NOW")
    expectNoDifference(model.broadcastStatusLabel, "Auto DJ")
    expectNoDifference(model.lastWentLiveLabel, "Last went live 4 days ago")
    expectNoDifference(model.viewFullScheduleLabel, "View Full Schedule")
  }

  @Test func displaysPlaceholderLinks() {
    let model = ArtistStationPageModel()

    expectNoDifference(model.showsLinkTitle, "Shows")
    expectNoDifference(model.musicLibraryLinkTitle, "Music Library")
    expectNoDifference(model.breakersLibraryLinkTitle, "Breakers Library")
  }

  // MARK: - Now Playing / Up Next Wiring

  @Test func nowPlayingReflectsScheduleWhenBroadcasting() async {
    let spins = [
      spin(id: "now", airtimeOffset: -60, title: "Cheat On Your Man", artist: "Bri Bagwell"),
      spin(id: "next", airtimeOffset: 120, title: "My Boots", artist: "Bri Bagwell"),
    ]
    let model = await makeModel { $0.api.fetchSchedule = { _, _ in spins } }

    expectNoDifference(model.nowPlayingTitle, "Cheat On Your Man")
    expectNoDifference(model.nowPlayingSubtitle, "Bri Bagwell · up next: My Boots")
    #expect(model.nowPlayingProgress > 0 && model.nowPlayingProgress <= 1)
  }

  @Test func subtitleOmitsUpNextWhenNoFutureSpin() async {
    let spins = [
      spin(id: "now", airtimeOffset: -60, title: "Cheat On Your Man", artist: "Bri Bagwell")
    ]
    let model = await makeModel { $0.api.fetchSchedule = { _, _ in spins } }

    expectNoDifference(model.nowPlayingTitle, "Cheat On Your Man")
    expectNoDifference(model.nowPlayingSubtitle, "Bri Bagwell")
  }

  @Test func nothingPlayingWhenScheduleEmpty() async {
    let model = await makeModel { $0.api.fetchSchedule = { _, _ in [] } }

    expectNoDifference(model.nowPlayingTitle, "Nothing playing right now")
    expectNoDifference(model.nowPlayingSubtitle, "")
    expectNoDifference(model.nowPlayingProgress, 0)
  }

  @Test func showsErrorWhenScheduleFailsToLoad() async {
    let model = await makeModel {
      $0.api.fetchSchedule = { _, _ in throw ArtistStationTestError.failed }
    }

    #expect(model.hasLoadError)
    expectNoDifference(model.nowPlayingTitle, "Unable to load broadcast")
    expectNoDifference(model.nowPlayingSubtitle, "")
  }

  @Test func doesNotLoadWhenNotBroadcasting() async {
    let capturedFetch = LockIsolated(false)
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in
        capturedFetch.setValue(true)
        return []
      }
    } operation: {
      let model = ArtistStationPageModel()
      await model.viewAppeared()
      return model
    }

    #expect(!capturedFetch.value)
    #expect(model.schedule == nil)
  }

  @Test func nowPlayingTitleNotifiesObserversWhenTheSongChanges() async {
    await withMainSerialExecutor {
      let spins = [
        spin(id: "now", airtimeOffset: -60, title: "Cheat On Your Man", artist: "Bri Bagwell"),
        spin(id: "next", airtimeOffset: 120, title: "My Boots", artist: "Bri Bagwell"),
      ]
      let currentDate = LockIsolated(fixedNow)
      let clock = TestClock()
      let model = await makeModel {
        $0.api.fetchSchedule = { _, _ in spins }
        $0.date = DateGenerator { currentDate.value }
        $0.continuousClock = clock
      }
      let ticking = Task { await model.stationTabVisible() }
      await Task.megaYield()
      let didChange = LockIsolated(false)
      withObservationTracking {
        _ = model.nowPlayingTitle
      } onChange: {
        didChange.setValue(true)
      }

      currentDate.setValue(fixedNow.addingTimeInterval(130))
      await clock.advance(by: .seconds(1))

      #expect(didChange.value)
      expectNoDifference(model.nowPlayingTitle, "My Boots")
      ticking.cancel()
      await ticking.value
    }
  }

  @Test func nowPlayingProgressNotifiesObserversAsTimePasses() async {
    await withMainSerialExecutor {
      let spins = [
        spin(id: "now", airtimeOffset: -60, title: "Cheat On Your Man", artist: "Bri Bagwell")
      ]
      let currentDate = LockIsolated(fixedNow)
      let clock = TestClock()
      let model = await makeModel {
        $0.api.fetchSchedule = { _, _ in spins }
        $0.date = DateGenerator { currentDate.value }
        $0.continuousClock = clock
      }
      let ticking = Task { await model.stationTabVisible() }
      await Task.megaYield()
      let initialProgress = model.nowPlayingProgress
      let didChange = LockIsolated(false)
      withObservationTracking {
        _ = model.nowPlayingProgress
      } onChange: {
        didChange.setValue(true)
      }

      currentDate.setValue(fixedNow.addingTimeInterval(60))
      await clock.advance(by: .seconds(1))

      #expect(didChange.value)
      #expect(model.nowPlayingProgress > initialProgress)
      ticking.cancel()
      await ticking.value
    }
  }

  @Test func staleScheduleResponseDoesNotOverwriteNewerData() async {
    let oldSpins = [
      spin(id: "old", airtimeOffset: -60, title: "Old Song", artist: "Old Artist")
    ]
    let newSpins = [
      spin(id: "new", airtimeOffset: -60, title: "New Song", artist: "New Artist")
    ]

    let pendingRequests = AsyncStream.makeStream(of: CheckedContinuation<[Spin], Never>.self)

    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in
        await withCheckedContinuation { pendingRequests.continuation.yield($0) }
      }
    } operation: {
      let model = ArtistStationPageModel()
      var requests = pendingRequests.stream.makeAsyncIterator()

      // Start the loads one at a time: `fetchSchedule` runs off the main actor, so two
      // concurrent calls can reach the stub in either order.
      async let firstLoad: Void = model.viewAppeared()
      guard let firstRequest = await requests.next() else {
        Issue.record("Expected a first schedule request")
        return
      }
      async let secondLoad: Void = model.viewAppeared()
      guard let secondRequest = await requests.next() else {
        Issue.record("Expected a second schedule request")
        return
      }

      secondRequest.resume(returning: newSpins)
      firstRequest.resume(returning: oldSpins)

      _ = await (firstLoad, secondLoad)

      expectNoDifference(model.nowPlayingTitle, "New Song")
    }
  }

  // MARK: - Navigation

  @Test func broadcastCardTappedPushesBroadcastPage() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let model = withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [] }
    } operation: {
      ArtistStationPageModel()
    }

    model.broadcastCardTapped()

    guard case .broadcastPage(let pushedModel) = coordinator.path.last else {
      Issue.record("Expected a broadcastPage to be pushed")
      return
    }
    expectNoDifference(pushedModel.stationId, testStationId)
  }

  @Test func broadcastCardTappedIsNoOpWhenNotBroadcasting() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [] }
    } operation: {
      ArtistStationPageModel()
    }

    model.broadcastCardTapped()

    #expect(coordinator.path.isEmpty)
  }

  @Test func showsRowTappedPushesShowsPage() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let model = withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [] }
    } operation: {
      ArtistStationPageModel()
    }

    model.showsRowTapped()

    guard case .showsPage(let pushedModel) = coordinator.path.last else {
      Issue.record("Expected a showsPage to be pushed")
      return
    }
    expectNoDifference(pushedModel.stationId, testStationId)
  }

  @Test func showsRowTappedIsNoOpWhenNotBroadcasting() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [] }
    } operation: {
      ArtistStationPageModel()
    }

    model.showsRowTapped()

    #expect(coordinator.path.isEmpty)
  }

  @Test func breakersLibraryRowTappedPushesBreakersLibraryPage() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let model = withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [] }
    } operation: {
      ArtistStationPageModel()
    }

    model.breakersLibraryRowTapped()

    guard case .breakersLibraryPage(let pushedModel) = coordinator.path.last else {
      Issue.record("Expected a breakersLibraryPage to be pushed")
      return
    }
    expectNoDifference(pushedModel.stationId, testStationId)
  }

  @Test func breakersLibraryRowTappedIsNoOpWhenNotBroadcasting() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [] }
    } operation: {
      ArtistStationPageModel()
    }

    model.breakersLibraryRowTapped()

    #expect(coordinator.path.isEmpty)
  }

  @Test func musicLibraryRowTappedPushesMusicLibraryPage() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)

    let model = withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [] }
    } operation: {
      ArtistStationPageModel()
    }

    model.musicLibraryRowTapped()

    guard case .musicLibraryPage(let pushedModel) = coordinator.path.last else {
      Issue.record("Expected a musicLibraryPage to be pushed")
      return
    }
    expectNoDifference(pushedModel.stationId, testStationId)
  }

  @Test func musicLibraryRowTappedIsNoOpWhenNotBroadcasting() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [] }
    } operation: {
      ArtistStationPageModel()
    }

    model.musicLibraryRowTapped()

    #expect(coordinator.path.isEmpty)
  }
}

private enum ArtistStationTestError: Error {
  case failed
}

extension ArtistStationPageTests {
  @Test(arguments: [0, 1, 2], [false, true])
  func cancellationDoesNotPublishScheduleErrors(kind: Int, notification: Bool) async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)
    await withMainSerialExecutor {
      let entered = AsyncStream<Void>.makeStream()
      let release = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
      let reports = LockIsolated(0)
      let model = withDependencies {
        $0.date.now = Date(timeIntervalSince1970: 1_000_000)
        $0.api.fetchSchedule = { _, _ in
          await withCheckedContinuation {
            release.setValue($0)
            entered.continuation.yield()
          }
          if kind == 0 { throw CancellationError() }
          if kind == 1 { throw URLError(.cancelled) }
          throw URLError(.badServerResponse)
        }
        $0.errorReporting.reportError = { _, _ in reports.withValue { $0 += 1 } }
      } operation: {
        ArtistStationPageModel()
      }
      let task = Task {
        if notification { await model.observeScheduleUpdates() } else { await model.viewAppeared() }
      }
      if notification {
        await Task.yield()
        NotificationCenter.default.post(
          name: .scheduleUpdated, object: nil, userInfo: ["stationId": testStationId])
      }
      var iterator = entered.stream.makeAsyncIterator()
      await iterator.next()
      if kind == 2 { task.cancel() }
      release.value?.resume()
      if notification {
        await Task.yield()
        await Task.yield()
        task.cancel()
      }
      await task.value
      expectNoDifference(model.hasLoadError, false)
      expectNoDifference(model.presentedAlert, nil)
      expectNoDifference(model.isLoading, false)
      expectNoDifference(reports.value, 0)
    }
  }

  @Test func successfulReloadClearsScheduleError() async {
    let fail = LockIsolated(true)
    let model = await makeModel {
      $0.api.fetchSchedule = { _, _ in
        if fail.value { throw URLError(.badServerResponse) }
        return []
      }
    }
    expectNoDifference(model.hasLoadError, true)
    expectNoDifference(model.presentedAlert, .errorLoadingSchedule)
    fail.setValue(false)
    await model.viewAppeared()
    expectNoDifference(model.hasLoadError, false)
    expectNoDifference(model.presentedAlert, nil)
  }

  @Test func oldCancellationDoesNotFinishNewerLoading() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    coordinator.switchToBroadcastMode(stationId: testStationId)
    let entered = AsyncStream<Void>.makeStream()
    let releases = LockIsolated<[CheckedContinuation<Void, Never>]>([])
    let model = withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.fetchSchedule = { _, _ in
        await withCheckedContinuation { continuation in
          releases.withValue { $0.append(continuation) }
          entered.continuation.yield()
        }
        throw CancellationError()
      }
    } operation: {
      ArtistStationPageModel()
    }
    let first = Task { await model.viewAppeared() }
    var iterator = entered.stream.makeAsyncIterator()
    await iterator.next()
    let second = Task { await model.viewAppeared() }
    await iterator.next()
    releases.value[0].resume()
    await first.value
    expectNoDifference(model.isLoading, true)
    releases.value[1].resume()
    await second.value
    expectNoDifference(model.isLoading, false)
    expectNoDifference(model.hasLoadError, false)
  }
}
