//
//  BroadcastPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/30/25.
//

import Dependencies
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class BroadcastPageTests: XCTestCase {
  func testViewAppeared_LoadsScheduleSuccessfully() async {
    let stationId = "test-station-id"
    let mockSpins = [
      Spin.mockWith(id: "spin-1", stationId: stationId),
      Spin.mockWith(id: "spin-2", stationId: stationId),
      Spin.mockWith(id: "spin-3", stationId: stationId),
    ]

    await withDependencies {
      $0.date.now = Date()
      $0.api.fetchSchedule = { requestedStationId, extended in
        XCTAssertEqual(requestedStationId, stationId)
        XCTAssertTrue(extended)
        return mockSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      XCTAssertNotNil(model.schedule)
      XCTAssertNil(model.presentedAlert)
      XCTAssertFalse(model.isLoading)
    }
  }

  func testViewAppeared_ShowsErrorAlertOnFailure() async {
    let stationId = "test-station-id"

    await withDependencies {
      $0.api.fetchSchedule = { _, _ in
        throw TestError.networkError
      }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      XCTAssertNil(model.schedule)
      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Error")
      XCTAssertFalse(model.isLoading)
    }
  }

  func testNowPlaying_ReturnsCurrentSpin() async {
    let stationId = "test-station-id"
    let fixedNow = Date(timeIntervalSince1970: 1_000_000)
    // Create audioBlock with 180 second (3 min) duration so spin is still playing
    let longAudioBlock = AudioBlock.mockWith(endOfMessageMS: 180_000)
    let mockSpins = [
      Spin.mockWith(
        id: "spin-1",
        airtime: fixedNow.addingTimeInterval(-60),
        stationId: stationId,
        audioBlock: longAudioBlock
      ),
      Spin.mockWith(
        id: "spin-2",
        airtime: fixedNow.addingTimeInterval(120),
        stationId: stationId
      ),
    ]

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in mockSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()
      XCTAssertEqual(model.nowPlaying?.id, "spin-1")
    }
  }

  func testUpcomingSpins_ExcludesNowPlaying() async {
    let stationId = "test-station-id"
    let fixedNow = Date(timeIntervalSince1970: 1_000_000)
    let mockSpins = [
      Spin.mockWith(
        id: "spin-1",
        airtime: fixedNow.addingTimeInterval(-60),
        stationId: stationId
      ),
      Spin.mockWith(
        id: "spin-2",
        airtime: fixedNow.addingTimeInterval(120),
        stationId: stationId
      ),
      Spin.mockWith(
        id: "spin-3",
        airtime: fixedNow.addingTimeInterval(300),
        stationId: stationId
      ),
    ]

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in mockSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      let upcomingIds = model.upcomingSpins.map { $0.id }
      XCTAssertFalse(upcomingIds.contains("spin-1"))
      XCTAssertTrue(upcomingIds.contains("spin-2"))
      XCTAssertTrue(upcomingIds.contains("spin-3"))
    }
  }

  func testTick_UpdatesCurrentNowPlayingIdWhenSpinChanges() async {
    let stationId = "test-station-id"
    let initialTime = Date(timeIntervalSince1970: 1_000_000)

    // spin-1: started 60s ago, 90s duration (ends in 30s)
    // spin-2: starts in 30s
    let spin1AudioBlock = AudioBlock.mockWith(endOfMessageMS: 90000)
    let spin2AudioBlock = AudioBlock.mockWith(endOfMessageMS: 180_000)
    let mockSpins = [
      Spin.mockWith(
        id: "spin-1",
        airtime: initialTime.addingTimeInterval(-60),
        stationId: stationId,
        audioBlock: spin1AudioBlock
      ),
      Spin.mockWith(
        id: "spin-2",
        airtime: initialTime.addingTimeInterval(30),
        stationId: stationId,
        audioBlock: spin2AudioBlock
      ),
    ]

    await withDependencies {
      $0.date.now = initialTime
      $0.api.fetchSchedule = { _, _ in mockSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      // Initially spin-1 is playing
      XCTAssertEqual(model.currentNowPlayingId, "spin-1")
      XCTAssertEqual(model.upcomingSpins.first?.id, "spin-2")
    }

    // Advance time past spin-1's end
    let laterTime = initialTime.addingTimeInterval(35)

    await withDependencies {
      $0.date.now = laterTime
      $0.api.fetchSchedule = { _, _ in mockSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      // Call tick - should detect spin change and update currentNowPlayingId
      model.tick()

      XCTAssertEqual(model.currentNowPlayingId, "spin-2")
    }
  }

  func testTick_DoesNotChangeIdWhenNowPlayingUnchanged() async {
    let stationId = "test-station-id"
    let initialTime = Date(timeIntervalSince1970: 1_000_000)

    // spin-1: started 10s ago, 180s duration (plenty of time left)
    let spin1AudioBlock = AudioBlock.mockWith(endOfMessageMS: 180_000)
    let mockSpins = [
      Spin.mockWith(
        id: "spin-1",
        airtime: initialTime.addingTimeInterval(-10),
        stationId: stationId,
        audioBlock: spin1AudioBlock
      )
    ]

    await withDependencies {
      $0.date.now = initialTime
      $0.api.fetchSchedule = { _, _ in mockSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      XCTAssertEqual(model.currentNowPlayingId, "spin-1")

      // Tick should not change the ID since spin hasn't changed
      model.tick()

      XCTAssertEqual(model.currentNowPlayingId, "spin-1")
    }
  }

  // MARK: - Station Name Tests

  func testNavigationTitle_UsesStationNameWhenProvided() async {
    let stationId = "test-station-id"
    let stationName = "My Awesome Station"

    withDependencies {
      $0.date.now = Date()
      $0.api.fetchSchedule = { _, _ in [] }
      $0.api.fetchStation = { _, _ in nil }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId, stationName: stationName)

      XCTAssertEqual(model.navigationTitle, stationName)
    }
  }

  func testNavigationTitle_FetchesStationNameOnLoad() async {
    let stationId = "test-station-id"
    let fetchedStationName = "Fetched Station Name"
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = Date()
      $0.api.fetchSchedule = { _, _ in [] }
      $0.api.fetchStation = { _, requestedId in
        XCTAssertEqual(requestedId, stationId)
        return Station.mockWith(name: fetchedStationName)
      }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      XCTAssertEqual(model.navigationTitle, "My Station")  // Default before load

      await model.viewAppeared()

      XCTAssertEqual(model.navigationTitle, fetchedStationName)
    }
  }

  func testNavigationTitle_FallsBackToDefaultWhenFetchFails() async {
    let stationId = "test-station-id"
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = Date()
      $0.api.fetchSchedule = { _, _ in [] }
      $0.api.fetchStation = { _, _ in nil }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      XCTAssertEqual(model.navigationTitle, "My Station")
    }
  }

  // MARK: - Grouped Spin Tests

  func testMoveSpins_MovesUngroupedSpinNormally() async {
    let stationId = "test-station-id"
    let fixedNow = Date(timeIntervalSince1970: 1_000_000)
    let mockSpins = [
      Spin.mockWith(id: "spin-1", airtime: fixedNow.addingTimeInterval(60), stationId: stationId),
      Spin.mockWith(id: "spin-2", airtime: fixedNow.addingTimeInterval(120), stationId: stationId),
      Spin.mockWith(id: "spin-3", airtime: fixedNow.addingTimeInterval(180), stationId: stationId),
    ]

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in mockSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      // Move spin-1 to position 2 (after spin-2)
      model.moveSpins(from: IndexSet(integer: 0), to: 2)

      let ids = model.upcomingSpins.map { $0.id }
      XCTAssertEqual(ids, ["spin-2", "spin-1", "spin-3"])
    }
  }

  func testMoveSpins_MovesEntireGroupTogether() async {
    let stationId = "test-station-id"
    let fixedNow = Date(timeIntervalSince1970: 1_000_000)
    let groupId = "group-1"
    let mockSpins = [
      Spin.mockWith(
        id: "spin-1", airtime: fixedNow.addingTimeInterval(60), stationId: stationId,
        spinGroupId: groupId),
      Spin.mockWith(
        id: "spin-2", airtime: fixedNow.addingTimeInterval(120), stationId: stationId,
        spinGroupId: groupId),
      Spin.mockWith(id: "spin-3", airtime: fixedNow.addingTimeInterval(180), stationId: stationId),
      Spin.mockWith(id: "spin-4", airtime: fixedNow.addingTimeInterval(240), stationId: stationId),
    ]

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in mockSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      // Move spin-1 (part of group) to position 3 (after spin-3)
      // Should move both spin-1 and spin-2 together
      model.moveSpins(from: IndexSet(integer: 0), to: 3)

      let ids = model.upcomingSpins.map { $0.id }
      XCTAssertEqual(ids, ["spin-3", "spin-1", "spin-2", "spin-4"])
    }
  }

  func testMoveSpins_PreservesRelativeOrderWithinGroup() async {
    let stationId = "test-station-id"
    let fixedNow = Date(timeIntervalSince1970: 1_000_000)
    let groupId = "group-1"
    let mockSpins = [
      Spin.mockWith(id: "spin-A", airtime: fixedNow.addingTimeInterval(60), stationId: stationId),
      Spin.mockWith(
        id: "spin-1", airtime: fixedNow.addingTimeInterval(120), stationId: stationId,
        spinGroupId: groupId),
      Spin.mockWith(
        id: "spin-2", airtime: fixedNow.addingTimeInterval(180), stationId: stationId,
        spinGroupId: groupId),
      Spin.mockWith(
        id: "spin-3", airtime: fixedNow.addingTimeInterval(240), stationId: stationId,
        spinGroupId: groupId),
      Spin.mockWith(id: "spin-B", airtime: fixedNow.addingTimeInterval(300), stationId: stationId),
    ]

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in mockSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      // Move spin-2 (middle of group) to the end
      // Should move entire group (spin-1, spin-2, spin-3) and preserve their order
      model.moveSpins(from: IndexSet(integer: 2), to: 5)

      let ids = model.upcomingSpins.map { $0.id }
      XCTAssertEqual(ids, ["spin-A", "spin-B", "spin-1", "spin-2", "spin-3"])
    }
  }

  // MARK: - Coming Soon Alert Tests

  func testOnAddVoiceTrackTapped_ShowsComingSoonAlert() {
    let model = BroadcastPageModel(stationId: "test-station")

    XCTAssertNil(model.presentedAlert)

    model.onAddVoiceTrackTapped()

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Coming Soon")
  }

  func testOnAddSongTapped_ShowsComingSoonAlert() {
    let model = BroadcastPageModel(stationId: "test-station")

    XCTAssertNil(model.presentedAlert)

    model.onAddSongTapped()

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Coming Soon")
  }

  // MARK: - Grouped Spin Tests

  func testMoveSpins_MovesGroupToBeginning() async {
    let stationId = "test-station-id"
    let fixedNow = Date(timeIntervalSince1970: 1_000_000)
    let groupId = "group-1"
    let mockSpins = [
      Spin.mockWith(id: "spin-A", airtime: fixedNow.addingTimeInterval(60), stationId: stationId),
      Spin.mockWith(id: "spin-B", airtime: fixedNow.addingTimeInterval(120), stationId: stationId),
      Spin.mockWith(
        id: "spin-1", airtime: fixedNow.addingTimeInterval(180), stationId: stationId,
        spinGroupId: groupId),
      Spin.mockWith(
        id: "spin-2", airtime: fixedNow.addingTimeInterval(240), stationId: stationId,
        spinGroupId: groupId),
    ]

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in mockSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      // Move spin-1 (part of group) to position 0
      model.moveSpins(from: IndexSet(integer: 2), to: 0)

      let ids = model.upcomingSpins.map { $0.id }
      XCTAssertEqual(ids, ["spin-1", "spin-2", "spin-A", "spin-B"])
    }
  }

}

private enum TestError: Error {
  case networkError
}
