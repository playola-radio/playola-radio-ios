//
//  ShowsPageTests.swift
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
struct ShowsPageTests {

  private let testStationId = "station-abc"

  @Test func displaysIntroCopy() {
    let model = ShowsPageModel(stationId: testStationId)

    expectNoDifference(model.navigationTitle, "Shows")
    expectNoDifference(model.introTitle, "Go live on your station")
    expectNoDifference(model.introBody, "Start a new show now.")
    expectNoDifference(model.sectionLabel, "GET STARTED")
  }

  @Test func offersAskMeAnythingAsTheOnlyShowType() {
    let model = ShowsPageModel(stationId: testStationId)

    expectNoDifference(
      model.showTypes,
      [
        ShowTypeRow(
          id: .askMeAnything,
          title: "Ask Me Anything",
          description: "Take questions from your listeners live.",
          iconSystemName: "bubble.left.and.bubble.right.fill")
      ])
  }

  @Test func askMeAnythingRowTappedPushesSetupAfterNoActiveShowCheck() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.fetchSchedule = { _, _ in [] }
    } operation: {
      let model = ShowsPageModel(stationId: testStationId)
      coordinator.push(.showsPage(model))
      await model.viewAppeared()
      #expect(model.canChooseShow)
      model.showTypeRowTapped(model.showTypes[0])
      guard case .askMeAnythingLivePage(let pushedModel) = coordinator.path.last else {
        Issue.record("Expected an askMeAnythingLivePage to be pushed")
        return
      }
      expectNoDifference(pushedModel.stationId, testStationId)
    }
  }

  @Test(arguments: [(-30.0, false), (300.0, false), (300.0, true)])
  func activeShowReplacesChooserAndPreservesBackDestination(offset: Double, filler: Bool) async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let date = Date(timeIntervalSince1970: 1_000_000)
    let calls = LockIsolated(0)
    await withDependencies {
      $0.date.now = date
      $0.api.fetchSchedule = { stationId, extended in
        expectNoDifference(stationId, testStationId)
        #expect(extended)
        calls.withValue { $0 += 1 }
        return [
          .mockWith(
            airtime: date.addingTimeInterval(offset),
            audioBlock: .mockWith(endOfMessageMS: 180_000),
            liveShowId: "active-show", isFiller: filler)
        ]
      }
    } operation: {
      let parent = BroadcastPageModel(stationId: testStationId)
      let model = ShowsPageModel(stationId: testStationId)
      coordinator.path = [.broadcastPage(parent), .showsPage(model)]
      await model.viewAppeared()
      expectNoDifference(coordinator.path.count, 2)
      guard case .askMeAnythingLivePage(let live) = coordinator.path.last else {
        Issue.record("Expected automatic forwarding to the active show")
        return
      }
      expectNoDifference(live.broadcast.liveShowId, "active-show")
      expectNoDifference(live.stationId, testStationId)
      #expect(live.broadcast.schedule != nil)
      coordinator.pop()
      await model.viewAppeared()
      expectNoDifference(coordinator.path, [.broadcastPage(parent)])
      expectNoDifference(calls.value, 1)
    }
  }

  @Test func chooserStaysUnavailableDuringCheckAndConcurrentAppearDoesNotDuplicateIt() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let started = AsyncStream<Void>.makeStream()
    let finish = AsyncStream<Void>.makeStream()
    let calls = LockIsolated(0)
    await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.fetchSchedule = { _, _ in
        calls.withValue { $0 += 1 }
        started.continuation.yield(())
        for await _ in finish.stream { break }
        return []
      }
    } operation: {
      let model = ShowsPageModel(stationId: testStationId)
      coordinator.push(.showsPage(model))
      #expect(!model.canChooseShow)
      let check = Task { await model.viewAppeared() }
      for await _ in started.stream { break }
      model.showTypeRowTapped(model.showTypes[0])
      await model.viewAppeared()
      expectNoDifference(coordinator.path, [.showsPage(model)])
      expectNoDifference(calls.value, 1)
      finish.continuation.yield(())
      await check.value
      #expect(model.canChooseShow)
    }
  }

  @Test func failedCheckKeepsChooserLockedAndRetryCanForwardToShow() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let calls = LockIsolated(0)
    let date = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = date
      $0.api.fetchSchedule = { _, _ in
        let count = calls.withValue {
          $0 += 1
          return $0
        }
        if count == 1 { throw APIError.dataNotValid }
        return [.mockWith(airtime: date.addingTimeInterval(300), liveShowId: "show")]
      }
    } operation: {
      let model = ShowsPageModel(stationId: testStationId)
      coordinator.push(.showsPage(model))
      await model.viewAppeared()
      #expect(!model.canChooseShow)
      expectNoDifference(model.retryTitles, ["Retry"])
      model.showTypeRowTapped(model.showTypes[0])
      expectNoDifference(coordinator.path, [.showsPage(model)])
      await model.viewAppeared()
      guard case .askMeAnythingLivePage = coordinator.path.last else {
        Issue.record("Expected retry to forward to the active show")
        return
      }
    }
  }

  @Test(arguments: ["back", "tab", "cancel"])
  func lateCheckDoesNotNavigateAfterLeavingOrCancellation(action: String) async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    @Shared(.activeTab) var tab = MainContainerModel.ActiveTab.home
    let started = AsyncStream<Void>.makeStream()
    let reply = LockIsolated<CheckedContinuation<[Spin], Never>?>(nil)
    let date = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = date
      $0.api.fetchSchedule = { _, _ in
        await withCheckedContinuation { continuation in
          reply.setValue(continuation)
          started.continuation.yield(())
        }
      }
    } operation: {
      let model = ShowsPageModel(stationId: testStationId)
      coordinator.push(.showsPage(model))
      let check = Task { await model.viewAppeared() }
      for await _ in started.stream { break }
      switch action {
      case "back": coordinator.pop()
      case "tab": $tab.withLock { $0 = .profile }
      default: check.cancel()
      }
      let expectedPath = coordinator.path
      reply.value?.resume(returning: [
        .mockWith(airtime: date.addingTimeInterval(300), liveShowId: "show")
      ])
      await check.value
      expectNoDifference(coordinator.path, expectedPath)
      if action == "cancel" { expectNoDifference(model.retryTitles, ["Retry"]) }
    }
  }
  @Test func chooserIgnoresFinishedShowsAndRechecksWhenItAppearsAgain() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let date = Date(timeIntervalSince1970: 1_000_000)
    let response = LockIsolated<[Spin]>([
      .mockWith(
        airtime: date.addingTimeInterval(-300), audioBlock: .mockWith(endOfMessageMS: 30_000),
        liveShowId: "finished")
    ])
    await withDependencies {
      $0.date.now = date
      $0.api.fetchSchedule = { _, _ in response.value }
    } operation: {
      let model = ShowsPageModel(stationId: testStationId)
      coordinator.push(.showsPage(model))
      await model.viewAppeared()
      #expect(model.canChooseShow)
      expectNoDifference(coordinator.path, [.showsPage(model)])
      response.setValue([
        .mockWith(airtime: date.addingTimeInterval(300), liveShowId: "new-show")
      ])
      await model.viewAppeared()
      guard case .askMeAnythingLivePage(let live) = coordinator.path.last else {
        Issue.record("Expected a new check to find the newly started show")
        return
      }
      expectNoDifference(live.broadcast.liveShowId, "new-show")
    }
  }

  @Test func returningBeforeCancelledCheckFinishesStartsFreshAndIgnoresOldResponse() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    @Shared(.activeTab) var tab = MainContainerModel.ActiveTab.home
    let started = AsyncStream<Void>.makeStream()
    let reply = LockIsolated<CheckedContinuation<[Spin], Never>?>(nil)
    let calls = LockIsolated(0)
    let date = Date(timeIntervalSince1970: 1_000_000)
    await withDependencies {
      $0.date.now = date
      $0.api.fetchSchedule = { _, _ in
        let count = calls.withValue {
          $0 += 1
          return $0
        }
        guard count == 1 else { return [] }
        return await withCheckedContinuation { continuation in
          reply.setValue(continuation)
          started.continuation.yield(())
        }
      }
    } operation: {
      let model = ShowsPageModel(stationId: testStationId)
      coordinator.push(.showsPage(model))
      let oldCheck = Task { await model.viewAppeared() }
      for await _ in started.stream { break }
      $tab.withLock { $0 = .profile }
      model.viewDisappeared()
      oldCheck.cancel()
      await model.viewAppeared()
      $tab.withLock { $0 = .home }
      await model.viewAppeared()
      expectNoDifference(calls.value, 2)
      #expect(model.canChooseShow)
      reply.value?.resume(returning: [
        .mockWith(airtime: date.addingTimeInterval(300), liveShowId: "stale-show")
      ])
      await oldCheck.value
      #expect(model.canChooseShow)
      expectNoDifference(coordinator.path, [.showsPage(model)])
    }
  }

}
