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
    expectNoDifference(model.scheduleLinkTitle, "Schedule")
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
}

private enum ArtistStationTestError: Error {
  case failed
}
