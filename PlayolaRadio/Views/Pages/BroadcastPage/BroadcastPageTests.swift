// swiftlint:disable file_length
//
//  BroadcastPageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/30/25.
//

import ConcurrencyExtras
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct BroadcastPageTests {
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

  @Test
  func testViewAppearedLoadsScheduleSuccessfully() async {
    let mockSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { requestedStationId, extended in
        #expect(requestedStationId == self.testStationId)
        #expect(extended)
        return mockSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      #expect(model.schedule != nil)
      #expect(model.presentedAlert == nil)
      #expect(!model.isLoading)
    }
  }

  @Test
  func testViewAppearedShowsErrorAlertOnFailure() async {
    await withDependencies {
      $0.api.fetchSchedule = { _, _ in
        throw TestError.networkError
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      #expect(model.schedule == nil)
      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Error")
      #expect(!model.isLoading)
    }
  }

  @Test
  func testNowPlayingReturnsCurrentSpin() async {
    let stationId = "test-station-id"
    let fixedNow = Date(timeIntervalSince1970: 1_000_000)
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
      #expect(model.nowPlaying?.id == "spin-1")
    }
  }

  @Test
  func testUpcomingSpinsExcludesNowPlaying() async {
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
      #expect(!upcomingIds.contains("spin-1"))
      #expect(upcomingIds.contains("spin-2"))
      #expect(upcomingIds.contains("spin-3"))
    }
  }

  @Test
  func testTickUpdatesCurrentNowPlayingIdWhenSpinChanges() async {
    let stationId = "test-station-id"
    let initialTime = Date(timeIntervalSince1970: 1_000_000)

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

      #expect(model.currentNowPlayingId == "spin-1")
      #expect(model.upcomingSpins.first?.id == "spin-2")
    }

    let laterTime = initialTime.addingTimeInterval(35)

    await withDependencies {
      $0.date.now = laterTime
      $0.api.fetchSchedule = { _, _ in mockSpins }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      model.tick()

      #expect(model.currentNowPlayingId == "spin-2")
    }
  }

  @Test
  func testTickDoesNotChangeIdWhenNowPlayingUnchanged() async {
    let stationId = "test-station-id"
    let initialTime = Date(timeIntervalSince1970: 1_000_000)

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

      #expect(model.currentNowPlayingId == "spin-1")

      model.tick()

      #expect(model.currentNowPlayingId == "spin-1")
    }
  }

  // MARK: - Station Name Tests

  @Test
  func testNavigationTitleUsesStationNameWhenProvided() async {
    let stationId = "test-station-id"
    let stationName = "My Awesome Station"

    withDependencies {
      $0.date.now = Date()
      $0.api.fetchSchedule = { _, _ in [] }
      $0.api.fetchStation = { _, _ in nil }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId, stationName: stationName)

      #expect(model.navigationTitle == stationName)
    }
  }

  @Test
  func testNavigationTitleFetchesStationNameOnLoad() async {
    let stationId = "test-station-id"
    let fetchedStationName = "Fetched Station Name"
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = Date()
      $0.api.fetchSchedule = { _, _ in [] }
      $0.api.fetchStation = { _, requestedId in
        #expect(requestedId == stationId)
        return Station.mockWith(name: fetchedStationName)
      }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      #expect(model.navigationTitle == "My Station")

      await model.viewAppeared()

      #expect(model.navigationTitle == fetchedStationName)
    }
  }

  @Test
  func testNavigationTitleFallsBackToDefaultWhenFetchFails() async {
    let stationId = "test-station-id"
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = Date()
      $0.api.fetchSchedule = { _, _ in [] }
      $0.api.fetchStation = { _, _ in nil }
    } operation: {
      let model = BroadcastPageModel(stationId: stationId)
      await model.viewAppeared()

      #expect(model.navigationTitle == "My Station")
    }
  }

  // MARK: - Grouped Spin Tests

  @Test
  func testMoveSpinsMovesUngroupedSpinNormally() async {
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

      await model.moveSpins(from: IndexSet(integer: 0), to: 2)

      let ids = model.upcomingSpins.map { $0.id }
      #expect(ids == ["spin-2", "spin-1", "spin-3"])
    }
  }

  @Test
  func testMoveSpinsMovesEntireGroupTogether() async {
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

      await model.moveSpins(from: IndexSet(integer: 0), to: 3)

      let ids = model.upcomingSpins.map { $0.id }
      #expect(ids == ["spin-3", "spin-1", "spin-2", "spin-4"])
    }
  }

  @Test
  func testMoveSpinsPreservesRelativeOrderWithinGroup() async {
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

      await model.moveSpins(from: IndexSet(integer: 2), to: 5)

      let ids = model.upcomingSpins.map { $0.id }
      #expect(ids == ["spin-A", "spin-B", "spin-1", "spin-2", "spin-3"])
    }
  }

  // MARK: - Coming Soon Alert Tests

  @Test
  func testOnAddVoiceTrackTappedPresentsRecordPageSheet() {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator = MainContainerNavigationCoordinator()

    let model = BroadcastPageModel(stationId: "test-station")

    #expect(mainContainerNavigationCoordinator.presentedSheet == nil)

    model.onAddVoiceTrackTapped()

    #expect(model.recordPageModel != nil)
    if case .recordPage = mainContainerNavigationCoordinator.presentedSheet {
      // Success - presented record page sheet
    } else {
      Issue.record("Expected recordPage sheet presentation")
    }
  }

  @Test
  func testOnAddSongTappedPresentsSongSearchPageSheet() async {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator = MainContainerNavigationCoordinator()

    let model = BroadcastPageModel(stationId: "test-station")

    #expect(mainContainerNavigationCoordinator.presentedSheet == nil)
    #expect(model.songSearchPageModel == nil)

    await model.onAddSongTapped()

    #expect(model.songSearchPageModel != nil)
    if case .songSearchPage = mainContainerNavigationCoordinator.presentedSheet {
    } else {
      Issue.record("Expected songSearchPage sheet presentation")
    }
  }

  @Test
  func testOnAddSongTappedUsesAllSearchMode() async {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator = MainContainerNavigationCoordinator()

    let model = BroadcastPageModel(stationId: "test-station")

    await model.onAddSongTapped()

    #expect(model.songSearchPageModel?.searchMode == .all)
  }

  @Test
  func testOnAddSongTappedSongSelectedCallbackAddsSongToStaging() async {
    await withMainSerialExecutor {
      @Shared(.mainContainerNavigationCoordinator)
      var mainContainerNavigationCoordinator = MainContainerNavigationCoordinator()

      let model = BroadcastPageModel(stationId: "test-station")
      #expect(model.stagingItems.isEmpty)

      await model.onAddSongTapped()

      let testSong = AudioBlock.mockWith(
        id: "test-song-123", title: "Test Song", artist: "Test Artist")
      model.songSearchPageModel?.onSongSelected?(testSong)
      await Task.yield()

      #expect(model.stagingItems.count == 1)
      #expect(model.stagingItems.first?.stagingId == "test-song-123")
      #expect(model.stagingItems.first?.titleText == "Test Song")
    }
  }

  @Test
  func testOnAddSongTappedSongSelectedCallbackDismissesSheet() async {
    @Shared(.mainContainerNavigationCoordinator)
    var mainContainerNavigationCoordinator = MainContainerNavigationCoordinator()

    let model = BroadcastPageModel(stationId: "test-station")
    await model.onAddSongTapped()

    #expect(mainContainerNavigationCoordinator.presentedSheet != nil)

    let testSong = AudioBlock.mockWith(id: "test-song-123")
    model.songSearchPageModel?.onSongSelected?(testSong)

    #expect(mainContainerNavigationCoordinator.presentedSheet == nil)
  }

  @Test
  func testAddSongToStagingDoesNotAddDuplicates() async {
    let model = BroadcastPageModel(stationId: "test-station")
    let testSong = AudioBlock.mockWith(id: "test-song-123")

    await model.addSongToStaging(testSong)
    await model.addSongToStaging(testSong)

    #expect(model.stagingItems.count == 1)
  }

  @Test
  func testAddSongToStagingAddsMultipleDifferentSongs() async {
    let model = BroadcastPageModel(stationId: "test-station")
    let song1 = AudioBlock.mockWith(id: "song-1", title: "First Song")
    let song2 = AudioBlock.mockWith(id: "song-2", title: "Second Song")

    await model.addSongToStaging(song1)
    await model.addSongToStaging(song2)

    #expect(model.stagingItems.count == 2)
    #expect(model.stagingItems[0].stagingId == "song-1")
    #expect(model.stagingItems[1].stagingId == "song-2")
  }

  @Test
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
      #expect(model.stagingItems.isEmpty)

      model.onAddVoiceTrackTapped()
      let recordingURL = URL(fileURLWithPath: "/tmp/test-recording.wav")
      await model.recordPageModel?.onRecordingAccepted?(recordingURL)

      #expect(model.stagingItems.count == 1)
      let voicetrack = model.stagingItems.first as? LocalVoicetrack
      #expect(voicetrack?.originalURL == recordingURL)
      #expect(voicetrack?.title == "Voice Track 11:00am")
      #expect(voicetrack?.status == .completed)
    }
  }

  // MARK: - Grouped Spin Tests

  @Test
  func testMoveSpinsMovesGroupToBeginning() async {
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

      await model.moveSpins(from: IndexSet(integer: 2), to: 0)

      let ids = model.upcomingSpins.map { $0.id }
      #expect(ids == ["spin-1", "spin-2", "spin-A", "spin-B"])
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
  @Test
  func testCanDeleteSpinReturnsTrueForSpinMoreThanTwoMinutesAway() async {
    let spinMoreThanTwoMinutesAway = makeSpins(ids: ["spin-1"], startOffset: 121).first!

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [spinMoreThanTwoMinutesAway] }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      #expect(model.canDeleteSpin(spinMoreThanTwoMinutesAway))
    }
  }

  @Test
  func testCanDeleteSpinReturnsFalseForSpinExactlyTwoMinutesAway() async {
    let spinExactlyTwoMinutesAway = makeSpins(ids: ["spin-1"], startOffset: 120).first!

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [spinExactlyTwoMinutesAway] }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      #expect(!model.canDeleteSpin(spinExactlyTwoMinutesAway))
    }
  }

  @Test
  func testCanDeleteSpinReturnsFalseForSpinLessThanTwoMinutesAway() async {
    let spinLessThanTwoMinutesAway = makeSpins(ids: ["spin-1"]).first!

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in [spinLessThanTwoMinutesAway] }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      #expect(!model.canDeleteSpin(spinLessThanTwoMinutesAway))
    }
  }
}

// MARK: - Move Spin Tests

extension BroadcastPageTests {
  @Test
  func testMoveSpinSuccessUpdatesScheduleWithReturnedSpins() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    let updatedSpins = makeSpins(ids: ["spin-2", "spin-1", "spin-3"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.moveSpin = { _, spinId, placeAfterSpinId in
        #expect(spinId == "spin-1")
        #expect(placeAfterSpinId == "spin-2")
        return updatedSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      #expect(model.upcomingSpins.map { $0.id } == ["spin-1", "spin-2", "spin-3"])

      await model.moveSpins(from: IndexSet(integer: 0), to: 2)

      #expect(model.upcomingSpins.map { $0.id } == ["spin-2", "spin-1", "spin-3"])
      #expect(model.spinIdsBeingRescheduled.isEmpty)
      #expect(model.presentedAlert == nil)
    }
  }

  @Test
  func testMoveSpinToBeginningCallsAPIWithNilPlaceAfterSpinId() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    let updatedSpins = makeSpins(ids: ["spin-3", "spin-1", "spin-2"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.moveSpin = { _, spinId, placeAfterSpinId in
        #expect(spinId == "spin-3")
        #expect(placeAfterSpinId == nil)
        return updatedSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      await model.moveSpins(from: IndexSet(integer: 2), to: 0)

      #expect(model.upcomingSpins.map { $0.id } == ["spin-3", "spin-1", "spin-2"])
    }
  }

  @Test
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

      #expect(model.spinIdsBeingRescheduled.isEmpty)

      let moveTask = Task {
        await model.moveSpins(from: IndexSet(integer: 0), to: 2)
      }

      while !moveStarted.value {
        await Task.yield()
      }

      #expect(model.spinIdsBeingRescheduled == ["spin-1", "spin-2", "spin-3"])

      moveContinuation.withValue { continuation in
        continuation?.resume()
        continuation = nil
      }

      await moveTask.value

      #expect(model.spinIdsBeingRescheduled.isEmpty)
    }
  }

  @Test
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
      #expect(originalIds == ["spin-1", "spin-2", "spin-3"])

      await model.moveSpins(from: IndexSet(integer: 0), to: 2)

      let restoredIds = model.upcomingSpins.map { $0.id }
      #expect(restoredIds == ["spin-1", "spin-2", "spin-3"])
      #expect(model.spinIdsBeingRescheduled.isEmpty)
    }
  }

  @Test
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

      #expect(model.presentedAlert == nil)

      await model.moveSpins(from: IndexSet(integer: 0), to: 2)

      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Error")
    }
  }
}

// MARK: - Delete Spin Tests

extension BroadcastPageTests {
  @Test
  func testDeleteSpinSuccessUpdatesScheduleWithReturnedSpins() async {
    let initialSpins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])
    let updatedSpins = makeSpins(ids: ["spin-1", "spin-3"])
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in initialSpins }
      $0.api.deleteSpin = { _, spinId in
        #expect(spinId == "spin-2")
        return updatedSpins
      }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      #expect(model.upcomingSpins.map { $0.id } == ["spin-1", "spin-2", "spin-3"])

      let spinToDelete = initialSpins[1]
      await model.deleteSpin(spinToDelete)

      #expect(model.upcomingSpins.map { $0.id } == ["spin-1", "spin-3"])
      #expect(model.spinIdsBeingRescheduled.isEmpty)
      #expect(model.presentedAlert == nil)
    }
  }

  @Test
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

      #expect(model.spinIdsBeingRescheduled.isEmpty)

      let deleteTask = Task {
        await model.deleteSpin(initialSpins[1])
      }

      while !deleteStarted.value {
        await Task.yield()
      }

      #expect(model.spinIdsBeingRescheduled == ["spin-3"])

      deleteContinuation.withValue { continuation in
        continuation?.resume()
        continuation = nil
      }

      await deleteTask.value

      #expect(model.spinIdsBeingRescheduled.isEmpty)
    }
  }

  @Test
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
      #expect(originalIds == ["spin-1", "spin-2", "spin-3"])

      await model.deleteSpin(initialSpins[1])

      let restoredIds = model.upcomingSpins.map { $0.id }
      #expect(restoredIds == ["spin-1", "spin-2", "spin-3"])
      #expect(model.spinIdsBeingRescheduled.isEmpty)
    }
  }

  @Test
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

      #expect(model.presentedAlert == nil)

      await model.deleteSpin(initialSpins[0])

      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Error")
    }
  }
}

// MARK: - Insert Voicetrack Tests

extension BroadcastPageTests {
  @Test
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

      await model.insertStagingItem(stagingId: voicetrackId.uuidString, beforeSpinId: "spin-2")

      #expect(capturedAudioBlockId.value == voicetrackAudioBlockId)
      #expect(capturedPlaceAfterSpinId.value == "spin-1")
    }
  }

  @Test
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

      #expect(model.stagingItems.count == 1)

      await model.insertStagingItem(stagingId: voicetrackId.uuidString, beforeSpinId: "spin-2")

      #expect(model.stagingItems.count == 0)
    }
  }

  @Test
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

      #expect(model.upcomingSpins.map { $0.id } == ["spin-1", "new-spin", "spin-2"])
    }
  }

  @Test
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

      #expect(model.nowPlaying?.id == "now-playing")
      #expect(model.upcomingSpins.first?.id == "spin-1")

      let voicetrackId = UUID()
      model.stagingItems = [makeStagingVoicetrack(id: voicetrackId)]

      await model.insertStagingItem(stagingId: voicetrackId.uuidString, beforeSpinId: "spin-1")

      #expect(capturedPlaceAfterSpinId.value == "now-playing")
      #expect(model.presentedAlert == nil)
    }
  }

  @Test
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

      #expect(model.nowPlaying == nil)

      let voicetrackId = UUID()
      model.stagingItems = [makeStagingVoicetrack(id: voicetrackId)]

      await model.insertStagingItem(stagingId: voicetrackId.uuidString, beforeSpinId: "spin-1")

      #expect(!apiWasCalled.value)
      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Cannot Place Here")
    }
  }
}

// MARK: - Notify Listeners Tests

extension BroadcastPageTests {
  @Test
  func testOnNotifyListenersTappedShowsSheet() {
    let model = BroadcastPageModel(stationId: testStationId)

    #expect(!model.showNotifyListenersSheet)

    model.onNotifyListenersTapped()

    #expect(model.showNotifyListenersSheet)
  }

  @Test
  func testCancelNotifyListenersDismissesSheet() {
    let model = BroadcastPageModel(stationId: testStationId)
    model.showNotifyListenersSheet = true
    model.notifyMessage = "Some message"

    model.cancelNotifyListeners()

    #expect(!model.showNotifyListenersSheet)
    #expect(model.notifyMessage == "")
  }

  @Test
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

      #expect(capturedStationId.value == testStationId)
      #expect(capturedMessage.value == "I'm going live from the van!")
    }
  }

  @Test
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

      #expect(!model.showNotifyListenersSheet)
      #expect(model.notifyMessage == "")
    }
  }

  @Test
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

      #expect(lastSent[testStationId] == fixedNow)
    }
  }

  @Test
  func testCanSendNotificationReturnsTrueWhenNeverSent() {
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [:]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      #expect(model.canSendNotification)
    }
  }

  @Test
  func testCanSendNotificationReturnsFalseWithin12Hours() {
    let elevenHoursAgo = fixedNow.addingTimeInterval(-11 * 60 * 60)
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [testStationId: elevenHoursAgo]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      #expect(!model.canSendNotification)
    }
  }

  @Test
  func testCanSendNotificationReturnsTrueAfter12Hours() {
    let thirteenHoursAgo = fixedNow.addingTimeInterval(-13 * 60 * 60)
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [
      testStationId: thirteenHoursAgo
    ]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      #expect(model.canSendNotification)
    }
  }

  @Test
  func testTimeUntilNextNotificationReturnsNilWhenCanSend() {
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [:]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      #expect(model.timeUntilNextNotification == nil)
    }
  }

  @Test
  func testTimeUntilNextNotificationReturnsRemainingTime() {
    let elevenHoursAgo = fixedNow.addingTimeInterval(-11 * 60 * 60)
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [testStationId: elevenHoursAgo]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      #expect(model.timeUntilNextNotification != nil)
      #expect(abs(model.timeUntilNextNotification! - 3600) < 1)
    }
  }

  @Test
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

      #expect(model.presentedAlert == nil)

      await model.sendNotification()

      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Error")
    }
  }

  @Test
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

      #expect(lastSent[testStationId] == nil)
    }
  }

  @Test
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

      #expect(!apiWasCalled.value)
      #expect(model.showNotifyListenersSheet)
    }
  }

  @Test
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

      #expect(!apiWasCalled.value)
      #expect(model.showNotifyListenersSheet)
    }
  }

  @Test
  func testNotificationRestTimeRemainingStringReturnsNilWhenCanSend() {
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [:]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      #expect(model.notificationRestTimeRemainingString == nil)
    }
  }

  @Test
  func testNotificationRestTimeRemainingStringShowsHoursAndMinutes() {
    let elevenHoursAgo = fixedNow.addingTimeInterval(-11 * 60 * 60)
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [testStationId: elevenHoursAgo]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      #expect(model.notificationRestTimeRemainingString == "1h 0m")
    }
  }

  @Test
  func testNotificationRestTimeRemainingStringShowsOnlyMinutesWhenUnderOneHour() {
    let elevenAndAHalfHoursAgo = fixedNow.addingTimeInterval(-11.5 * 60 * 60)
    @Shared(.lastNotificationSentAt) var lastSent: [String: Date] = [
      testStationId: elevenAndAHalfHoursAgo
    ]

    withDependencies {
      $0.date.now = fixedNow
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)

      #expect(model.notificationRestTimeRemainingString == "30m")
    }
  }

  @Test
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

      #expect(!model.isSendingNotification)

      let sendTask = Task {
        await model.sendNotification()
      }

      while !requestStarted.value {
        await Task.yield()
      }

      #expect(model.isSendingNotification)

      requestContinuation.withValue { continuation in
        continuation?.resume()
        continuation = nil
      }

      await sendTask.value

      #expect(!model.isSendingNotification)
    }
  }
}

// MARK: - Voicetrack Upload Tests

extension BroadcastPageTests {
  @Test
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
      #expect(statuses.count == 6)
      #expect(statuses[0] == .converting)
      #expect(statuses[1] == .uploading(progress: 0.0))
      #expect(statuses[2] == .uploading(progress: 0.5))
      #expect(statuses[3] == .uploading(progress: 1.0))
      #expect(statuses[4] == .finalizing)
      #expect(statuses[5] == .completed)
      let voicetrack = model.stagingItems.first as? LocalVoicetrack
      #expect(voicetrack?.status == .completed)
    }
  }

  @Test
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

      #expect(model.stagingItems.count == 1)
      let voicetrack = model.stagingItems.first as? LocalVoicetrack
      #expect(voicetrack?.audioBlockId == expectedAudioBlockId)
      #expect(voicetrack?.status == .completed)
    }
  }

  @Test
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

      #expect(model.presentedAlert == nil)

      model.onAddVoiceTrackTapped()
      let recordingURL = URL(fileURLWithPath: "/tmp/test-recording.wav")
      await model.recordPageModel?.onRecordingAccepted?(recordingURL)

      #expect(model.presentedAlert != nil)
      #expect(model.presentedAlert?.title == "Upload Failed")
      #expect(model.presentedAlert?.message == serverErrorMessage)
    }
  }

  // MARK: - Analytics Tests

  @Test
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
      #expect(hasViewedEvent)
    }
  }

  @Test
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
      #expect(hasNotificationEvent)
    }
  }

  @Test
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
      #expect(hasRecordedEvent)
    }
  }

  @Test
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
      #expect(hasUploadedEvent)
    }
  }

  @Test
  func testOnAddSongTappedTracksSongSearchTapped() async {
    await withMainSerialExecutor {
      let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
      let loggedInUser = LoggedInUser(
        id: "user-123",
        firstName: "Test",
        lastName: "User",
        email: "test@example.com"
      )
      @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

      await confirmation("songSearchTapped tracked") { confirm in
        await withDependencies {
          $0.date.now = fixedNow
          $0.analytics.track = { event in
            capturedEvents.withValue { $0.append(event) }
            if case .broadcastSongSearchTapped = event {
              confirm()
            }
          }
        } operation: {
          let model = BroadcastPageModel(stationId: testStationId, stationName: "Test Station")
          await model.onAddSongTapped()

          while !capturedEvents.value.contains(where: {
            if case .broadcastSongSearchTapped = $0 { return true }
            return false
          }) {
            await Task.yield()
          }
        }
      }

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
      #expect(hasSearchEvent)
    }
  }

  @Test
  func testAddSongToStagingTracksSongAdded() async {
    await withMainSerialExecutor {
      let capturedEvents = LockIsolated<[AnalyticsEvent]>([])
      let loggedInUser = LoggedInUser(
        id: "user-123",
        firstName: "Test",
        lastName: "User",
        email: "test@example.com"
      )
      @Shared(.auth) var auth = Auth(loggedInUser: loggedInUser)

      await confirmation("songAdded tracked") { confirm in
        await withDependencies {
          $0.date.now = fixedNow
          $0.analytics.track = { event in
            capturedEvents.withValue { $0.append(event) }
            if case .broadcastSongAdded = event {
              confirm()
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

          while !capturedEvents.value.contains(where: {
            if case .broadcastSongAdded = $0 { return true }
            return false
          }) {
            await Task.yield()
          }
        }
      }

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
      #expect(hasSongAddedEvent)
    }
  }

  // MARK: - Schedule Update Notification Tests

  @Test
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

      #expect(model.schedule?.current().count == 2)

      useUpdatedSpins.setValue(true)
      await model.refreshScheduleFromRemote()

      #expect(model.schedule?.current().count == 3)
    }
  }

  @Test
  func testRefreshScheduleFromRemoteClearsReorderedSpinIds() async {
    let spins = makeSpins(ids: ["spin-1", "spin-2", "spin-3"])

    await withDependencies {
      $0.date.now = fixedNow
      $0.api.fetchSchedule = { _, _ in spins }
    } operation: {
      let model = BroadcastPageModel(stationId: testStationId)
      await model.viewAppeared()

      await model.refreshScheduleFromRemote()

      #expect(model.schedule != nil)
    }
  }

  @Test
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

      #expect(model.schedule != nil)
      #expect(model.presentedAlert == nil)
    }
  }

  @Test
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

        #expect(fetchCount.value == 1)

        NotificationCenter.default.post(
          name: .scheduleUpdated,
          object: nil,
          userInfo: ["stationId": uniqueStationId, "editorName": "Jane Smith"]
        )

        await Task.yield()
        await Task.yield()
        await Task.yield()
        await Task.yield()

        #expect(fetchCount.value == 2)
      }
    }
  }

  @Test
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

      #expect(shownToast.value != nil)
      #expect(shownToast.value?.message == "Edited by Jane Smith")
    }
  }

  @Test
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

      #expect(shownToast.value == nil)
    }
  }

  @Test
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

      #expect(fetchCount.value == initialFetchCount)
    }
  }
}
