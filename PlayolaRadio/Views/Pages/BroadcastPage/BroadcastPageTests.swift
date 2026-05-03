// swiftlint:disable file_length
//
//  BroadcastPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/30/25.
//

import ConcurrencyExtras
import Dependencies
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class BroadcastPageTests: XCTestCase {
  // MARK: - Test Helpers

  private let testStationId = "test-station-id"
  private let fixedNow = Date(timeIntervalSince1970: 1_000_000)

  private func makeSpins(
    ids: [String],
    startOffset: TimeInterval = 60,
    interval: TimeInterval = 60,
    groupId: String? = nil,
    audioBlock: AudioBlock? = nil
  ) -> [Spin] {
    ids.enumerated().map { index, id in
      Spin.mockWith(
        id: id,
        airtime: fixedNow.addingTimeInterval(startOffset + TimeInterval(index) * interval),
        stationId: testStationId,
        audioBlock: audioBlock ?? .mockWith(),
        spinGroupId: groupId
      )
    }
  }

  private func makeStagingVoicetrack(
    id: UUID = UUID(),
    audioBlockId: String = "audio-block-id"
  ) -> LocalVoicetrack {
    LocalVoicetrack(
      id: id,
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .completed,
      title: "Test Voicetrack",
      audioBlockId: audioBlockId
    )
  }

  // MARK: - Schedule Loading Tests

  func testViewAppeared_LoadsScheduleSuccessfully() async {
    let mockSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { requestedStationId, extended in
        XCTAssertEqual(requestedStationId, self.testStationId)
        XCTAssertTrue(extended)
        return mockSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertNotNil(model.schedule)
      XCTAssertNil(model.presentedAlert)
      XCTAssertFalse(model.isLoading)
    }
  }

  func testViewAppeared_ShowsErrorAlertOnFailure() async {
    await withDependencies {
      $0.api.fetchSchedule = { _, _ in
        throw TestError.networkError
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
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
    let mockSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    let reorderedSpins = makeSpins(ids: ["spin-2", "spin-1", "spin-3"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in mockSpins }
      $0.api.moveSpin = { _, _, _ in reorderedSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      // Move spin-1 to position 2 (after spin-2)
      await model.moveSpins(from: IndexSet(integer: 0), to: 2)

      let ids = model.upcomingSpins.map { $0.id }
      XCTAssertEqual(ids, ["spin-2", "spin-1", "spin-3"])
    }
  }

  func testMoveSpins_MovesEntireGroupTogether() async {
    let groupId = "group-1"
    let mockSpins =
      makeSpins(ids: ["spin-1", "spin-2"], groupId: groupId)
      + makeSpins(ids: ["spin-3", "spin-4"], startOffset: 180)
    let reorderedSpins =
      [makeSpins(ids: ["spin-3"]).first!]
      + makeSpins(ids: ["spin-1", "spin-2"], startOffset: 120, groupId: groupId)
      + [makeSpins(ids: ["spin-4"], startOffset: 240).first!]
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in mockSpins }
      $0.api.moveSpin = { _, _, _ in reorderedSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      // Move spin-1 (part of group) to position 3 (after spin-3)
      // Should move both spin-1 and spin-2 together
      await model.moveSpins(from: IndexSet(integer: 0), to: 3)

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
    let reorderedSpins = [
      Spin.mockWith(id: "spin-A", airtime: fixedNow.addingTimeInterval(60), stationId: stationId),
      Spin.mockWith(id: "spin-B", airtime: fixedNow.addingTimeInterval(120), stationId: stationId),
      Spin.mockWith(
        id: "spin-1", airtime: fixedNow.addingTimeInterval(180), stationId: stationId,
        spinGroupId: groupId),
      Spin.mockWith(
        id: "spin-2", airtime: fixedNow.addingTimeInterval(240), stationId: stationId,
        spinGroupId: groupId),
      Spin.mockWith(
        id: "spin-3", airtime: fixedNow.addingTimeInterval(300), stationId: stationId,
        spinGroupId: groupId),
    ]
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in mockSpins }
      $0.api.moveSpin = { _, _, _ in reorderedSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      // Move spin-2 (middle of group) to the end
      // Should move entire group (spin-1, spin-2, spin-3) and preserve their order
      await model.moveSpins(from: IndexSet(integer: 2), to: 5)

      let ids = model.upcomingSpins.map { $0.id }
      XCTAssertEqual(ids, ["spin-A", "spin-B", "spin-1", "spin-2", "spin-3"])
    }
  }

  // MARK: - Coming Soon Alert Tests

  func testOnAddVoiceTrackTapped_PresentsRecordPageSheet() {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    let model = BroadcastPageModel(stationId: "test-station")

    XCTAssertNil(mainContainerNavigationCoordinator.presentedSheet)

    model.onAddVoiceTrackTapped()

    XCTAssertNotNil(model.recordPageModel)
    if case .recordPage = mainContainerNavigationCoordinator.presentedSheet {
      // Success - presented record page sheet
    } else {
      XCTFail("Expected recordPage sheet presentation")
    }
  }

  func testOnAddSongTappedPresentsSongSearchPageSheet() async {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    let model = BroadcastPageModel(stationId: "test-station")

    XCTAssertNil(mainContainerNavigationCoordinator.presentedSheet)
    XCTAssertNil(model.songSearchPageModel)

    await model.onAddSongTapped()

    XCTAssertNotNil(model.songSearchPageModel)
    if case .songSearchPage = mainContainerNavigationCoordinator.presentedSheet {
    } else {
      XCTFail("Expected songSearchPage sheet presentation")
    }
  }

  func testOnAddSongTappedUsesAllSearchMode() async {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    let model = BroadcastPageModel(stationId: "test-station")

    await model.onAddSongTapped()

    XCTAssertEqual(model.songSearchPageModel?.searchMode, .all)
  }

  func testOnAddSongTappedSongSelectedCallbackAddsSongToStaging() async {
    await withMainSerialExecutor {
      @Shared(.mainContainerNavigationCoordinator)
      var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

      let model = BroadcastPageModel(stationId: "test-station")
      XCTAssertTrue(model.stagingItems.isEmpty)

      await model.onAddSongTapped()

      let testSong = AudioBlock.mockWith(
        id: "test-song-123", title: "Test Song", artist: "Test Artist")
      model.songSearchPageModel?.onSongSelected?(testSong)
      await Task.yield()

      XCTAssertEqual(model.stagingItems.count, 1)
      XCTAssertEqual(model.stagingItems.first?.stagingId, "test-song-123")
      XCTAssertEqual(model.stagingItems.first?.titleText, "Test Song")
    }
  }

  func testOnAddSongTappedSongSelectedCallbackDismissesSheet() async {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator: MainContainerNavigationCoordinator

    let model = BroadcastPageModel(stationId: "test-station")
    await model.onAddSongTapped()

    XCTAssertNotNil(mainContainerNavigationCoordinator.presentedSheet)

    let testSong = AudioBlock.mockWith(id: "test-song-123")
    model.songSearchPageModel?.onSongSelected?(testSong)

    XCTAssertNil(mainContainerNavigationCoordinator.presentedSheet)
  }

  func testAddSongToStagingDoesNotAddDuplicates() async {
    let model = BroadcastPageModel(stationId: "test-station")
    let testSong = AudioBlock.mockWith(id: "test-song-123")

    await model.addSongToStaging(testSong)
    await model.addSongToStaging(testSong)

    XCTAssertEqual(model.stagingItems.count, 1)
  }

  func testAddSongToStagingAddsMultipleDifferentSongs() async {
    let model = BroadcastPageModel(stationId: "test-station")
    let song1 = AudioBlock.mockWith(id: "song-1", title: "First Song")
    let song2 = AudioBlock.mockWith(id: "song-2", title: "Second Song")

    await model.addSongToStaging(song1)
    await model.addSongToStaging(song2)

    XCTAssertEqual(model.stagingItems.count, 2)
    XCTAssertEqual(model.stagingItems[0].stagingId, "song-1")
    XCTAssertEqual(model.stagingItems[1].stagingId, "song-2")
  }

  func testRecordingAcceptedAddsToStagingArea() async {
    let calendar = Calendar.current
    let components = DateComponents(year: 2023, month: 12, day: 13, hour: 11, minute: 0)
    let fixedDate = calendar.date(from: components)!
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedDate
      $0.voicetrackUploadService.processVoicetrack = { _, _, _, onStatusChange in
        await onStatusChange(.converting)
        await onStatusChange(.completed)
        return AudioBlock.mockWith()
      }
    } operation: {
      let model = BroadcastPageModel(stationId: "test-station")
      XCTAssertTrue(model.stagingItems.isEmpty)

      model.onAddVoiceTrackTapped()
      let recordingURL = URL(fileURLWithPath: "/tmp/test-recording.wav")
      await model.recordPageModel?.onRecordingAccepted?(recordingURL)

      XCTAssertEqual(model.stagingItems.count, 1)
      let voicetrack = model.stagingItems.first as? LocalVoicetrack
      XCTAssertEqual(voicetrack?.originalURL, recordingURL)
      XCTAssertEqual(voicetrack?.title, "Voice Track 11:00am")
      XCTAssertEqual(voicetrack?.status, .completed)
    }
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
    let reorderedSpins = [
      Spin.mockWith(
        id: "spin-1", airtime: fixedNow.addingTimeInterval(60), stationId: stationId,
        spinGroupId: groupId),
      Spin.mockWith(
        id: "spin-2", airtime: fixedNow.addingTimeInterval(120), stationId: stationId,
        spinGroupId: groupId),
      Spin.mockWith(id: "spin-A", airtime: fixedNow.addingTimeInterval(180), stationId: stationId),
      Spin.mockWith(id: "spin-B", airtime: fixedNow.addingTimeInterval(240), stationId: stationId),
    ]
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in mockSpins }
      $0.api.moveSpin = { _, _, _ in reorderedSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      // Move spin-1 (part of group) to position 0
      await model.moveSpins(from: IndexSet(integer: 2), to: 0)

      let ids = model.upcomingSpins.map { $0.id }
      XCTAssertEqual(ids, ["spin-1", "spin-2", "spin-A", "spin-B"])
    }
  }

}

private enum TestError: Error, LocalizedError {
  case networkError

  var errorDescription: String? {
    switch self {
    case .networkError:
      return "Network error occurred"
    }
  }
}

// MARK: - canDeleteSpin Tests

extension BroadcastPageTests {
  func testCanDeleteSpinReturnsTrueForSpinMoreThanTwoMinutesAway() async {
    let spinMoreThanTwoMinutesAway = makeSpins(ids: ["spin-1"], startOffset: 121).first!

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [spinMoreThanTwoMinutesAway] }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertTrue(model.canDeleteSpin(spinMoreThanTwoMinutesAway))
    }
  }

  func testCanDeleteSpinReturnsFalseForSpinExactlyTwoMinutesAway() async {
    let spinExactlyTwoMinutesAway = makeSpins(ids: ["spin-1"], startOffset: 120).first!

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [spinExactlyTwoMinutesAway] }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertFalse(model.canDeleteSpin(spinExactlyTwoMinutesAway))
    }
  }

  func testCanDeleteSpinReturnsFalseForSpinLessThanTwoMinutesAway() async {
    let spinLessThanTwoMinutesAway = makeSpins(ids: ["spin-1"]).first!

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [spinLessThanTwoMinutesAway] }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertFalse(model.canDeleteSpin(spinLessThanTwoMinutesAway))
    }
  }
}

// MARK: - Move Spin Tests

extension BroadcastPageTests {
  func testMoveSpinSuccessUpdatesScheduleWithReturnedSpins() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    let updatedSpins = makeSpins(ids: ["spin-2", "spin-1", "spin-3"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.moveSpin = { _, spinId, placeAfterSpinId in
        XCTAssertEqual(spinId, "spin-1")
        XCTAssertEqual(placeAfterSpinId, "spin-2")
        return updatedSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertEqual(model.upcomingSpins.map { $0.id }, ["spin-1", "spin-2", "spin-3"])

      // Move spin-1 to after spin-2
      await model.moveSpins(from: IndexSet(integer: 0), to: 2)

      XCTAssertEqual(model.upcomingSpins.map { $0.id }, ["spin-2", "spin-1", "spin-3"])
      XCTAssertTrue(model.spinIdsBeingRescheduled.isEmpty)
      XCTAssertNil(model.presentedAlert)
    }
  }

  func testMoveSpinToBeginningCallsAPIWithNilPlaceAfterSpinId() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    let updatedSpins = makeSpins(ids: ["spin-3", "spin-1", "spin-2"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.moveSpin = { _, spinId, placeAfterSpinId in
        XCTAssertEqual(spinId, "spin-3")
        XCTAssertNil(placeAfterSpinId)
        return updatedSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      // Move spin-3 to beginning
      await model.moveSpins(from: IndexSet(integer: 2), to: 0)

      XCTAssertEqual(model.upcomingSpins.map { $0.id }, ["spin-3", "spin-1", "spin-2"])
    }
  }

  func testMoveSpinMarksAllSpinsAsReschedulingDuringCall() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let moveStarted = LockIsolated(false)
    let moveContinuation = LockIsolated<CheckedContinuation<Void, Never>?>(nil)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.moveSpin = { _, _, _ in
        moveStarted.setValue(true)
        await withCheckedContinuation { continuation in
          moveContinuation.setValue(continuation)
        }
        return initialSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertTrue(model.spinIdsBeingRescheduled.isEmpty)

      let moveTask = Task {
        await model.moveSpins(from: IndexSet(integer: 0), to: 2)
      }

      while !moveStarted.value {
        await Task.yield()
      }

      // During the call, all spins should be marked as rescheduling
      XCTAssertEqual(model.spinIdsBeingRescheduled, ["spin-1", "spin-2", "spin-3"])

      moveContinuation.withValue { continuation in
        continuation?.resume()
        continuation = nil
      }

      await moveTask.value

      // After the call completes, the set should be cleared
      XCTAssertTrue(model.spinIdsBeingRescheduled.isEmpty)
    }
  }

  func testMoveSpinErrorRestoresOriginalSchedule() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.moveSpin = { _, _, _ in
        throw TestError.networkError
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      let originalIds = model.upcomingSpins.map { $0.id }
      XCTAssertEqual(originalIds, ["spin-1", "spin-2", "spin-3"])

      await model.moveSpins(from: IndexSet(integer: 0), to: 2)

      let restoredIds = model.upcomingSpins.map { $0.id }
      XCTAssertEqual(restoredIds, ["spin-1", "spin-2", "spin-3"])
      XCTAssertTrue(model.spinIdsBeingRescheduled.isEmpty)
    }
  }

  func testMoveSpinErrorShowsErrorAlert() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.moveSpin = { _, _, _ in
        throw TestError.networkError
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertNil(model.presentedAlert)

      await model.moveSpins(from: IndexSet(integer: 0), to: 2)

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Error")
    }
  }
}

// MARK: - Delete Spin Tests

extension BroadcastPageTests {
  func testDeleteSpinSuccessUpdatesScheduleWithReturnedSpins() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    let updatedSpins = makeSpins(ids: ["spin-1", "spin-3"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.deleteSpin = { _, spinId in
        XCTAssertEqual(spinId, "spin-2")
        return updatedSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertEqual(model.upcomingSpins.map { $0.id }, ["spin-1", "spin-2", "spin-3"])

      let spinToDelete = initialSpins[1]
      await model.deleteSpin(spinToDelete)

      XCTAssertEqual(model.upcomingSpins.map { $0.id }, ["spin-1", "spin-3"])
      XCTAssertTrue(model.spinIdsBeingRescheduled.isEmpty)
      XCTAssertNil(model.presentedAlert)
    }
  }

  func testDeleteSpinMarksSpinsAfterDeletedAsReschedulingDuringCall() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let deleteStarted = LockIsolated(false)
    let deleteContinuation = LockIsolated<CheckedContinuation<Void, Never>?>(nil)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.deleteSpin = { _, _ in
        deleteStarted.setValue(true)
        await withCheckedContinuation { continuation in
          deleteContinuation.setValue(continuation)
        }
        return [initialSpins[0], initialSpins[2]]
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertTrue(model.spinIdsBeingRescheduled.isEmpty)

      let deleteTask = Task {
        await model.deleteSpin(initialSpins[1])
      }

      while !deleteStarted.value {
        await Task.yield()
      }

      // During the call, spin-3 should have been marked as rescheduling (it comes after spin-2)
      XCTAssertEqual(model.spinIdsBeingRescheduled, ["spin-3"])

      deleteContinuation.withValue { continuation in
        continuation?.resume()
        continuation = nil
      }

      await deleteTask.value

      // After the call completes, the set should be cleared
      XCTAssertTrue(model.spinIdsBeingRescheduled.isEmpty)
    }
  }

  func testDeleteSpinErrorRestoresOriginalSchedule() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.deleteSpin = { _, _ in
        throw TestError.networkError
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      let originalIds = model.upcomingSpins.map { $0.id }
      XCTAssertEqual(originalIds, ["spin-1", "spin-2", "spin-3"])

      await model.deleteSpin(initialSpins[1])

      let restoredIds = model.upcomingSpins.map { $0.id }
      XCTAssertEqual(restoredIds, ["spin-1", "spin-2", "spin-3"])
      XCTAssertTrue(model.spinIdsBeingRescheduled.isEmpty)
    }
  }

  func testDeleteSpinErrorShowsErrorAlert() async {
    let initialSpins = makeSpins(ids: ["spin-1"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.deleteSpin = { _, _ in
        throw TestError.networkError
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertNil(model.presentedAlert)

      await model.deleteSpin(initialSpins[0])

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Error")
    }
  }
}

// MARK: - Insert Voicetrack Tests

extension BroadcastPageTests {
  func testInsertVoicetrackCallsAPIWithCorrectParameters() async {
    let voicetrackAudioBlockId = "voicetrack-audio-block-id"
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let capturedAudioBlockId = LockIsolated<String?>(nil)
    let capturedPlaceAfterSpinId = LockIsolated<String?>(nil)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.insertSpin = { _, audioBlockId, placeAfterSpinId in
        capturedAudioBlockId.setValue(audioBlockId)
        capturedPlaceAfterSpinId.setValue(placeAfterSpinId)
        return initialSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      let voicetrackId = UUID()
      model.stagingItems = [
        makeStagingVoicetrack(id: voicetrackId, audioBlockId: voicetrackAudioBlockId)
      ]

      // Drop voicetrack before spin-2 (should insert after spin-1)
      await model.insertStagingItem(stagingId: voicetrackId.uuidString, beforeSpinId: "spin-2")

      XCTAssertEqual(capturedAudioBlockId.value, voicetrackAudioBlockId)
      XCTAssertEqual(capturedPlaceAfterSpinId.value, "spin-1")
    }
  }

  func testInsertStagingItemRemovesFromStagingOnSuccess() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.insertSpin = { _, _, _ in initialSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      let voicetrackId = UUID()
      model.stagingItems = [makeStagingVoicetrack(id: voicetrackId)]

      XCTAssertEqual(model.stagingItems.count, 1)

      await model.insertStagingItem(stagingId: voicetrackId.uuidString, beforeSpinId: "spin-2")

      XCTAssertEqual(model.stagingItems.count, 0)
    }
  }

  func testInsertStagingItemUpdatesScheduleWithResponse() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2"], interval: 120)
    let updatedSpins = makeSpins(ids: ["spin-1", "new-spin", "spin-2"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.insertSpin = { _, _, _ in updatedSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      let voicetrackId = UUID()
      model.stagingItems = [makeStagingVoicetrack(id: voicetrackId)]

      await model.insertStagingItem(stagingId: voicetrackId.uuidString, beforeSpinId: "spin-2")

      XCTAssertEqual(model.upcomingSpins.map { $0.id }, ["spin-1", "new-spin", "spin-2"])
    }
  }

  func testInsertStagingItemAtTopUsesNowPlayingAsPlaceAfter() async {
    let nowPlayingAudioBlock = AudioBlock.mockWith(endOfMessageMS: 180_000)
    let nowPlayingSpin = Spin.mockWith(
      id: "now-playing",
      airtime: fixedNow.addingTimeInterval(-60),
      stationId: testStationId,
      audioBlock: nowPlayingAudioBlock
    )
    let upcomingSpins = makeSpins(ids: ["spin-1", "spin-2"])
    let allSpins = [nowPlayingSpin] + upcomingSpins
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let capturedPlaceAfterSpinId = LockIsolated<String?>(nil)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in allSpins }
      $0.api.insertSpin = { _, _, placeAfterSpinId in
        capturedPlaceAfterSpinId.setValue(placeAfterSpinId)
        return allSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertEqual(model.nowPlaying?.id, "now-playing")
      XCTAssertEqual(model.upcomingSpins.first?.id, "spin-1")

      let voicetrackId = UUID()
      model.stagingItems = [makeStagingVoicetrack(id: voicetrackId)]

      await model.insertStagingItem(stagingId: voicetrackId.uuidString, beforeSpinId: "spin-1")

      XCTAssertEqual(capturedPlaceAfterSpinId.value, "now-playing")
      XCTAssertNil(model.presentedAlert)
    }
  }

  func testInsertStagingItemAtTopWithNoNowPlayingShowsError() async {
    let upcomingSpins = makeSpins(ids: ["spin-1", "spin-2"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let apiWasCalled = LockIsolated(false)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in upcomingSpins }
      $0.api.insertSpin = { _, _, _ in
        apiWasCalled.setValue(true)
        return upcomingSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertNil(model.nowPlaying)

      let voicetrackId = UUID()
      model.stagingItems = [makeStagingVoicetrack(id: voicetrackId)]

      await model.insertStagingItem(stagingId: voicetrackId.uuidString, beforeSpinId: "spin-1")

      XCTAssertFalse(apiWasCalled.value)
      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Cannot Place Here")
    }
  }
}

// MARK: - Notify Listeners Tests

extension BroadcastPageTests {
  func testOnNotifyListenersTappedShowsSheet() {
    let model = BroadcastPageModel(stationId: testStationId)

    XCTAssertFalse(model.showNotifyListenersSheet)

    model.onNotifyListenersTapped()

    XCTAssertTrue(model.showNotifyListenersSheet)
  }

  func testCancelNotifyListenersDismissesSheet() {
    let model = BroadcastPageModel(stationId: testStationId)
    model.showNotifyListenersSheet = true
    model.notifyMessage = "Some message"

    model.cancelNotifyListeners()

    XCTAssertFalse(model.showNotifyListenersSheet)
    XCTAssertEqual(model.notifyMessage, "")
  }

  func testSendNotificationCallsAPIWithMessage() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let capturedStationId = LockIsolated<String?>(nil)
    let capturedMessage = LockIsolated<String?>(nil)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.sendStationNotification = { _, stationId, message in
        capturedStationId.setValue(stationId)
        capturedMessage.setValue(message)
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      model.notifyMessage = "I'm going live from the van!"

      await model.sendNotification()

      XCTAssertEqual(capturedStationId.value, testStationId)
      XCTAssertEqual(capturedMessage.value, "I'm going live from the van!")
    }
  }

  func testSendNotificationDismissesSheetAndClearsMessage() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.sendStationNotification = { _, _, _ in }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      model.showNotifyListenersSheet = true
      model.notifyMessage = "Test message"

      await model.sendNotification()

      XCTAssertFalse(model.showNotifyListenersSheet)
      XCTAssertEqual(model.notifyMessage, "")
    }
  }

  func testSendNotificationUpdatesLastSentTime() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [:]

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.sendStationNotification = { _, _, _ in }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      model.notifyMessage = "Test"

      await model.sendNotification()

      XCTAssertEqual(lastSent[testStationId], fixedNow)
    }
  }

  func testCanSendNotificationReturnsTrueWhenNeverSent() {
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [:]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      XCTAssertTrue(model.canSendNotification)
    }
  }

  func testCanSendNotificationReturnsFalseWithin12Hours() {
    let elevenHoursAgo = fixedNow.addingTimeInterval(-11 * 60 * 60)
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [testStationId: elevenHoursAgo]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      XCTAssertFalse(model.canSendNotification)
    }
  }

  func testCanSendNotificationReturnsTrueAfter12Hours() {
    let thirteenHoursAgo = fixedNow.addingTimeInterval(-13 * 60 * 60)
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [
      testStationId: thirteenHoursAgo
    ]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      XCTAssertTrue(model.canSendNotification)
    }
  }

  func testTimeUntilNextNotificationReturnsNilWhenCanSend() {
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [:]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      XCTAssertNil(model.timeUntilNextNotification)
    }
  }

  func testTimeUntilNextNotificationReturnsRemainingTime() {
    let elevenHoursAgo = fixedNow.addingTimeInterval(-11 * 60 * 60)
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [testStationId: elevenHoursAgo]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      // Should be approximately 1 hour (3600 seconds) remaining
      XCTAssertNotNil(model.timeUntilNextNotification)
      XCTAssertEqual(model.timeUntilNextNotification!, 3600, accuracy: 1)
    }
  }

  func testSendNotificationShowsErrorAlertOnFailure() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.sendStationNotification = { _, _, _ in
        throw TestError.networkError
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      model.notifyMessage = "Test"

      XCTAssertNil(model.presentedAlert)

      await model.sendNotification()

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Error")
    }
  }

  func testSendNotificationDoesNotUpdateLastSentOnFailure() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [:]

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.sendStationNotification = { _, _, _ in
        throw TestError.networkError
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      model.notifyMessage = "Test"

      await model.sendNotification()

      XCTAssertNil(lastSent[testStationId])
    }
  }

  func testSendNotificationDoesNothingWhenMessageIsEmpty() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let apiWasCalled = LockIsolated(false)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.sendStationNotification = { _, _, _ in
        apiWasCalled.setValue(true)
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      model.showNotifyListenersSheet = true
      model.notifyMessage = ""

      await model.sendNotification()

      XCTAssertFalse(apiWasCalled.value)
      XCTAssertTrue(model.showNotifyListenersSheet)
    }
  }

  func testSendNotificationDoesNothingWhenMessageIsWhitespaceOnly() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let apiWasCalled = LockIsolated(false)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.sendStationNotification = { _, _, _ in
        apiWasCalled.setValue(true)
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      model.showNotifyListenersSheet = true
      model.notifyMessage = "   \n\t  "

      await model.sendNotification()

      XCTAssertFalse(apiWasCalled.value)
      XCTAssertTrue(model.showNotifyListenersSheet)
    }
  }

  func testNotificationRestTimeRemainingStringReturnsNilWhenCanSend() {
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [:]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      XCTAssertNil(model.notificationRestTimeRemainingString)
    }
  }

  func testNotificationRestTimeRemainingStringShowsHoursAndMinutes() {
    let elevenHoursAgo = fixedNow.addingTimeInterval(-11 * 60 * 60)
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [testStationId: elevenHoursAgo]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      XCTAssertEqual(model.notificationRestTimeRemainingString, "1h 0m")
    }
  }

  func testNotificationRestTimeRemainingStringShowsOnlyMinutesWhenUnderOneHour() {
    let elevenAndAHalfHoursAgo = fixedNow.addingTimeInterval(-11.5 * 60 * 60)
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [
      testStationId: elevenAndAHalfHoursAgo
    ]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      XCTAssertEqual(model.notificationRestTimeRemainingString, "30m")
    }
  }

  func testIsSendingNotificationTracksLoadingState() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let requestStarted = LockIsolated(false)
    let requestContinuation = LockIsolated<CheckedContinuation<Void, Never>?>(nil)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.sendStationNotification = { _, _, _ in
        requestStarted.setValue(true)
        await withCheckedContinuation { continuation in
          requestContinuation.setValue(continuation)
        }
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      model.notifyMessage = "Test"

      XCTAssertFalse(model.isSendingNotification)

      let sendTask = Task {
        await model.sendNotification()
      }

      while !requestStarted.value {
        await Task.yield()
      }

      XCTAssertTrue(model.isSendingNotification)

      requestContinuation.withValue { continuation in
        continuation?.resume()
        continuation = nil
      }

      await sendTask.value

      XCTAssertFalse(model.isSendingNotification)
    }
  }
}

// MARK: - Voicetrack Upload Tests

extension BroadcastPageTests {
  func testVoicetrackStatusUpdatesAsUploadProgresses() async {
    let stationId = "test-station-id"
    let fixedDate = Date(timeIntervalSince1970: 1_702_486_800)
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    let capturedStatuses = LockIsolated<[LocalVoicetrackStatus]>([])

    await withDependencies {
      $0.date.now = fixedDate
      $0.voicetrackUploadService.processVoicetrack = { _, _, _, onStatusChange in
        let statuses: [LocalVoicetrackStatus] = [
          .converting,
          .uploading(progress: 0.0),
          .uploading(progress: 0.5),
          .uploading(progress: 1.0),
          .finalizing,
          .completed,
        ]
        for status in statuses {
          await onStatusChange(status)
          capturedStatuses.withValue { $0.append(status) }
        }
        return AudioBlock.mockWith()
      }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)

      model.onAddVoiceTrackTapped()
      let recordingURL = URL(fileURLWithPath: "/tmp/test-recording.wav")
      await model.recordPageModel?.onRecordingAccepted?(recordingURL)

      let statuses = capturedStatuses.value
      XCTAssertEqual(statuses.count, 6)
      XCTAssertEqual(statuses[0], .converting)
      XCTAssertEqual(statuses[1], .uploading(progress: 0.0))
      XCTAssertEqual(statuses[2], .uploading(progress: 0.5))
      XCTAssertEqual(statuses[3], .uploading(progress: 1.0))
      XCTAssertEqual(statuses[4], .finalizing)
      XCTAssertEqual(statuses[5], .completed)
      let voicetrack = model.stagingItems.first as? LocalVoicetrack
      XCTAssertEqual(voicetrack?.status, .completed)
    }
  }

  func testVoicetrackUploadSuccessStoresAudioBlockId() async {
    let stationId = "test-station-id"
    let fixedDate = Date(timeIntervalSince1970: 1_702_486_800)
    let expectedAudioBlockId = "server-audio-block-id-123"
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedDate
      $0.voicetrackUploadService.processVoicetrack = { _, _, _, onStatusChange in
        await onStatusChange(.converting)
        await onStatusChange(.uploading(progress: 0.5))
        await onStatusChange(.finalizing)
        await onStatusChange(.completed)
        return AudioBlock.mockWith(id: expectedAudioBlockId)
      }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)

      model.onAddVoiceTrackTapped()
      let recordingURL = URL(fileURLWithPath: "/tmp/test-recording.wav")
      await model.recordPageModel?.onRecordingAccepted?(recordingURL)

      XCTAssertEqual(model.stagingItems.count, 1)
      let voicetrack = model.stagingItems.first as? LocalVoicetrack
      XCTAssertEqual(voicetrack?.audioBlockId, expectedAudioBlockId)
      XCTAssertEqual(voicetrack?.status, .completed)
    }
  }

  func testVoicetrackUploadErrorShowsAlertWithServerErrorMessage() async {
    let stationId = "test-station-id"
    let fixedDate = Date(timeIntervalSince1970: 1_702_486_800)
    let serverErrorMessage = "Station has reached voicetrack limit"
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedDate
      $0.voicetrackUploadService.processVoicetrack = { _, _, _, onStatusChange in
        await onStatusChange(.converting)
        throw APIError.validationError(serverErrorMessage)
      }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)

      XCTAssertNil(model.presentedAlert)

      model.onAddVoiceTrackTapped()
      let recordingURL = URL(fileURLWithPath: "/tmp/test-recording.wav")
      await model.recordPageModel?.onRecordingAccepted?(recordingURL)

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Upload Failed")
      XCTAssertEqual(model.presentedAlert?.message, serverErrorMessage)
    }
  }

  // MARK: - Analytics Tests

  func testViewAppearedTracksViewedBroadcastScreen() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let loggedInUser = LoggedInUser(
      id: "user-123",
      firstName: "Test",
      lastName: "User",
      email: "test@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [] }
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId, stationName: "Test Station")
      await model.viewAppeared()

      let events = capturedEvents.value
      let hasViewedEvent = events.contains { event in
        if case .viewedBroadcastScreen(let stationId, let stationName, let userName) = event {
          return stationId == testStationId
            && stationName == "Test Station"
            && userName == "Test User"
        }
        return false
      }
      XCTAssertTrue(hasViewedEvent)
    }
  }

  func testSendNotificationTracksNotificationSent() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let loggedInUser = LoggedInUser(
      id: "user-123",
      firstName: "Test",
      lastName: "User",
      email: "test@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.sendStationNotification = { _, _, _ in }
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId, stationName: "Test Station")
      model.notifyMessage = "Hello listeners!"
      await model.sendNotification()

      let events = capturedEvents.value
      let hasNotificationEvent = events.contains { event in
        if case .broadcastNotificationSent(
          let stationId, let stationName, let userName, let messageLength
        ) = event {
          return stationId == testStationId
            && stationName == "Test Station"
            && userName == "Test User"
            && messageLength == 16
        }
        return false
      }
      XCTAssertTrue(hasNotificationEvent)
    }
  }

  func testHandleAcceptedRecordingTracksVoicetrackRecorded() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let loggedInUser = LoggedInUser(
      id: "user-123",
      firstName: "Test",
      lastName: "User",
      email: "test@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    await withDependencies {
      $0.date.now = fixedNow
      $0.voicetrackUploadService.processVoicetrack = { _, _, _, _ in
        AudioBlock.mockWith()
      }
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId, stationName: "Test Station")
      let recordingURL = URL(fileURLWithPath: "/tmp/test-recording.wav")
      await model.handleAcceptedRecording(recordingURL)

      let events = capturedEvents.value
      let hasRecordedEvent = events.contains { event in
        if case .broadcastVoicetrackRecorded(
          let stationId, let stationName, let userName
        ) = event {
          return stationId == testStationId
            && stationName == "Test Station"
            && userName == "Test User"
        }
        return false
      }
      XCTAssertTrue(hasRecordedEvent)
    }
  }

  func testVoicetrackUploadCompletedTracksVoicetrackUploaded() async {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
    let loggedInUser = LoggedInUser(
      id: "user-123",
      firstName: "Test",
      lastName: "User",
      email: "test@example.com"
    )
    @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

    await withDependencies {
      $0.date.now = fixedNow
      $0.voicetrackUploadService.processVoicetrack = { _, _, _, onStatusChange in
        await onStatusChange(.completed)
        return AudioBlock.mockWith()
      }
      $0.analytics.track = { event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId, stationName: "Test Station")
      let recordingURL = URL(fileURLWithPath: "/tmp/test-recording.wav")
      await model.handleAcceptedRecording(recordingURL)

      let events = capturedEvents.value
      let hasUploadedEvent = events.contains { event in
        if case .broadcastVoicetrackUploaded(
          let stationId, let stationName, let userName
        ) = event {
          return stationId == testStationId
            && stationName == "Test Station"
            && userName == "Test User"
        }
        return false
      }
      XCTAssertTrue(hasUploadedEvent)
    }
  }

  func testOnAddSongTappedTracksSongSearchTapped() async {
    await withMainSerialExecutor {
      let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
      let searchTappedExpectation = XCTestExpectation(description: "songSearchTapped tracked")
      let loggedInUser = LoggedInUser(
        id: "user-123",
        firstName: "Test",
        lastName: "User",
        email: "test@example.com"
      )
      @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

      await withDependencies {
        $0.date.now = fixedNow
        $0.analytics.track = { event in
          capturedEvents.withValue { $0.append(event) }
          if case .broadcastSongSearchTapped = event {
            searchTappedExpectation.fulfill()
          }
        }
      } operation: {
        let model = BroadcastPageModel(stationId: testStationId, stationName: "Test Station")
        await model.onAddSongTapped()

        await fulfillment(of: [searchTappedExpectation], timeout: 1.0)

        let events = capturedEvents.value
        let hasSearchEvent = events.contains { event in
          if case .broadcastSongSearchTapped(
            let stationId, let stationName, let userName
          ) = event {
            return stationId == testStationId
              && stationName == "Test Station"
              && userName == "Test User"
          }
          return false
        }
        XCTAssertTrue(hasSearchEvent)
      }
    }
  }

  func testAddSongToStagingTracksSongAdded() async {
    await withMainSerialExecutor {
      let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
      let songAddedExpectation = XCTestExpectation(description: "songAdded tracked")
      let loggedInUser = LoggedInUser(
        id: "user-123",
        firstName: "Test",
        lastName: "User",
        email: "test@example.com"
      )
      @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

      await withDependencies {
        $0.date.now = fixedNow
        $0.analytics.track = { event in
          capturedEvents.withValue { $0.append(event) }
          if case .broadcastSongAdded = event {
            songAddedExpectation.fulfill()
          }
        }
      } operation: {
        let model = BroadcastPageModel(stationId: testStationId, stationName: "Test Station")
        let audioBlock = AudioBlock.mockWith(
          id: "song-123",
          title: "Test Song",
          artist: "Test Artist"
        )
        await model.addSongToStaging(audioBlock)

        await fulfillment(of: [songAddedExpectation], timeout: 1.0)

        let events = capturedEvents.value
        let hasSongAddedEvent = events.contains { event in
          if case .broadcastSongAdded(
            let stationId, let stationName, let userName, let songTitle, let artistName
          ) = event {
            return stationId == testStationId
              && stationName == "Test Station"
              && userName == "Test User"
              && songTitle == "Test Song"
              && artistName == "Test Artist"
          }
          return false
        }
        XCTAssertTrue(hasSongAddedEvent)
      }
    }
  }

  // MARK: - Schedule Update Notification Tests

  func testRefreshScheduleFromRemoteUpdatesSchedule() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2"])
    let updatedSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    let useUpdatedSpins = LockIsolated(false)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in
        useUpdatedSpins.value ? updatedSpins : initialSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      XCTAssertEqual(model.schedule?.current().count, 2)

      useUpdatedSpins.setValue(true)
      await model.refreshScheduleFromRemote()

      XCTAssertEqual(model.schedule?.current().count, 3)
    }
  }

  func testRefreshScheduleFromRemoteClearsReorderedSpinIds() async {
    let spins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in spins }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      await model.refreshScheduleFromRemote()

      XCTAssertNotNil(model.schedule)
    }
  }

  func testRefreshScheduleFromRemoteSilentlyFailsOnError() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2"])
    let shouldThrow = LockIsolated(false)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in
        if shouldThrow.value { throw TestError.networkError }
        return initialSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      shouldThrow.setValue(true)
      await model.refreshScheduleFromRemote()

      XCTAssertNotNil(model.schedule)
      XCTAssertNil(model.presentedAlert)
    }
  }

  func testScheduleUpdateNotificationTriggersRefresh() async {
    let uniqueStationId = "notification-trigger-test-station"
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2"])
    let updatedSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    let fetchCount = LockIsolated(0)

    await withMainSerialExecutor {
      await withDependencies {
        $0.date.now = fixedNow
        $0.toast = .noop
        $0.api.fetchSchedule = { _, _ in
          let count = fetchCount.withValue { val -> Int in
            val += 1
            return val
          }
          return count > 1 ? updatedSpins : initialSpins
        }
      } operation: {
        let model = BroadcastPageModel(stationId: uniqueStationId)
        await model.viewAppeared()

        XCTAssertEqual(fetchCount.value, 1)

        NotificationCenter.default.post(
          name: .scheduleUpdated,
          object: nil,
          userInfo: ["stationId": uniqueStationId, "editorName": "Jane Smith"]
        )

        // The notification handler spawns a Task that calls refreshScheduleFromRemote.
        // Suspension points: Task start + fetchSchedule + toast.show
        await Task.yield()
        await Task.yield()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(fetchCount.value, 2)
      }
    }
  }

  func testRefreshScheduleFromRemoteShowsToastWithEditorName() async {
    let spins = makeSpins(ids: ["spin-1", "spin-2"])
    let shownToast = LockIsolated<PlayolaToast?>(nil)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in spins }
      $0.toast.show = { toast in shownToast.setValue(toast) }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      await model.refreshScheduleFromRemote(editorName: "Jane Smith")

      XCTAssertNotNil(shownToast.value)
      XCTAssertEqual(shownToast.value?.message, "Edited by Jane Smith")
    }
  }

  func testRefreshScheduleFromRemoteNoToastWithoutEditorName() async {
    let spins = makeSpins(ids: ["spin-1", "spin-2"])
    let shownToast = LockIsolated<PlayolaToast?>(nil)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in spins }
      $0.toast.show = { toast in shownToast.setValue(toast) }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      await model.refreshScheduleFromRemote()

      XCTAssertNil(shownToast.value)
    }
  }

  func testScheduleUpdateNotificationIgnoredForDifferentStation() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2"])
    let fetchCount = LockIsolated(0)

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in
        fetchCount.withValue { $0 += 1 }
        return initialSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      let initialFetchCount = fetchCount.value

      NotificationCenter.default.post(
        name: .scheduleUpdated,
        object: nil,
        userInfo: ["stationId": "different-station-id"]
      )

      await Task.yield()

      XCTAssertEqual(fetchCount.value, initialFetchCount)
    }
  }
}
