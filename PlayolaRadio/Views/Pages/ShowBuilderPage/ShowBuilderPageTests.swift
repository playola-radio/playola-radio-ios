//
//  ShowBuilderPageTests.swift
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

private struct ShowBuilderTestError: Error {}

@Suite(.freshSharedState)
@MainActor
struct ShowBuilderPageTests {

  // MARK: - Test Helpers

  private let stationId = "station-1"
  // Sunday, Nov 22 2026 at 7:00 PM in Chicago.
  private let airtime = Date(timeIntervalSince1970: 1_795_395_600)
  private let sixHoursMS = 21_600_000
  private let eighteenMinutesThirtyFiveMS = 1_115_000

  private func block(_ id: String, title: String? = nil, type: String = "song") -> AudioBlock {
    AudioBlock.mockWith(
      id: id, title: title ?? "Song \(id)", artist: "Artist \(id)", durationMS: 180_000,
      endOfMessageMS: 180_000, type: type)
  }

  private func segment(_ id: String, position: Int, audio: AudioBlock? = nil)
    -> CuratorEpisodeSegment
  {
    CuratorEpisodeSegment(
      id: id, position: position, offsetMS: position * 180_000,
      audioBlock: audio ?? block("block-\(id)"))
  }

  private func airing(_ id: String = "airing-1", at time: Date? = nil, startTime: Date? = nil)
    -> CuratorAiring
  {
    let airtime = time ?? self.airtime
    return CuratorAiring(
      id: id, episodeId: "episode-1", stationId: stationId, airtime: airtime,
      startTime: startTime, endTime: nil)
  }

  private func episode(
    id: String = "episode-1", title: String = "Tour Stories", show: CuratorSeries? = nil,
    durationMS: Int? = nil, segments: [CuratorEpisodeSegment] = [],
    airings: [CuratorAiring] = []
  ) -> CuratorEpisode {
    CuratorEpisode(
      id: id, showId: show?.id ?? "one-time", title: title,
      durationMS: durationMS ?? eighteenMinutesThirtyFiveMS, show: show, segments: segments,
      airings: airings)
  }

  private func settings(_ timezone: String = "America/Chicago") -> StationSchedulingSettings {
    StationSchedulingSettings(timezone: timezone, airingEditLockMS: sixHoursMS)
  }

  private func makeModel(
    episodeId: String? = "episode-1",
    seriesId: String? = nil,
    episode: CuratorEpisode? = nil,
    settings: StationSchedulingSettings? = nil,
    now: Date? = nil,
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) -> ShowBuilderPageModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let loaded = episode ?? self.episode()
    let resolvedSettings = settings ?? self.settings()
    let resolvedNow = now ?? airtime.addingTimeInterval(-24 * 3600)
    return withDependencies {
      $0.date.now = resolvedNow
      $0.api.getCuratorEpisode = { _, _ in loaded }
      $0.api.getStationSchedulingSettings = { _, _ in resolvedSettings }
      configure(&$0)
    } operation: {
      ShowBuilderPageModel(
        stationId: stationId, episodeId: episodeId, seriesId: seriesId, slot: nil)
    }
  }

  // MARK: - Save chain

  @Test func firstChangeCreatesOnce() async {
    let creates = LockIsolated<[String]>([])
    let changedIds = LockIsolated<[String]>([])
    let created = episode(id: "new-episode", title: "New Show", durationMS: 0)
    let model = makeModel(episodeId: nil, episode: created) {
      $0.api.createStandaloneEpisode = { _, stationId, title in
        creates.withValue { $0.append("\(stationId):\(title)") }
        return created
      }
    }

    await model.save { id in changedIds.withValue { $0.append(id) } }
    await model.save { id in changedIds.withValue { $0.append(id) } }

    expectNoDifference(creates.value, ["station-1:New Show"])
    expectNoDifference(changedIds.value, ["new-episode", "new-episode"])
    expectNoDifference(model.episodeId, "new-episode")
  }

  @Test func firstChangeInASeriesCreatesTheShowInThatSeries() async {
    let createdInSeries = LockIsolated<[String]>([])
    let created = episode(id: "new-episode", title: "New Show", durationMS: 0)
    let model = makeModel(episodeId: nil, seriesId: "series-1", episode: created) {
      $0.api.createEpisodeInSeries = { _, showId, title in
        createdInSeries.withValue { $0.append("\(showId):\(title)") }
        return created
      }
    }

    await model.save { _ in }

    expectNoDifference(createdInSeries.value, ["series-1:New Show"])
  }

  @Test func twoQuickChangesSaveInOrderOnce() async {
    await withMainSerialExecutor {
      let log = LockIsolated<[String]>([])
      let (createGate, openCreate) = AsyncStream<Void>.makeStream()
      let created = episode(id: "new-episode", title: "New Show", durationMS: 0)
      let model = makeModel(episodeId: nil, episode: created) {
        $0.api.createStandaloneEpisode = { _, _, _ in
          log.withValue { $0.append("create") }
          for await _ in createGate { break }
          return created
        }
      }

      let first = Task { await model.save { _ in log.withValue { $0.append("add(a)") } } }
      await Task.megaYield()
      let second = Task { await model.save { _ in log.withValue { $0.append("add(b)") } } }
      await Task.megaYield()
      openCreate.yield()
      openCreate.finish()
      await first.value
      await second.value

      expectNoDifference(log.value, ["create", "add(a)", "add(b)"])
    }
  }

  @Test func failedChangeKeepsCreatedId() async {
    let createCount = LockIsolated(0)
    let changedIds = LockIsolated<[String]>([])
    let created = episode(id: "new-episode", title: "New Show", durationMS: 0)
    let model = makeModel(episodeId: nil, episode: created) {
      $0.api.createStandaloneEpisode = { _, _, _ in
        createCount.withValue { $0 += 1 }
        return created
      }
    }

    await model.save { _ in throw ShowBuilderTestError() }
    await model.save { id in changedIds.withValue { $0.append(id) } }

    expectNoDifference(createCount.value, 1)
    expectNoDifference(changedIds.value, ["new-episode"])
  }

  @Test func failedRefetchStillAddsTheNextVoicetrackAtTheEnd() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let positions = LockIsolated<[Int]>([])
    let fetchCount = LockIsolated(0)
    let empty = episode()
    let afterFirst = episode(segments: [segment("s1", position: 0)])
    let model = makeModel(episode: empty) {
      $0.api.getCuratorEpisode = { _, _ in
        let count = fetchCount.withValue {
          $0 += 1
          return $0
        }
        guard count == 1 else { throw ShowBuilderTestError() }
        return empty
      }
      $0.api.addEpisodeSegments = { _, _, _, position in
        positions.withValue { $0.append(position) }
        return afterFirst
      }
      $0.errorReporting.reportError = { _, _ in }
    }
    await model.viewAppeared()

    for blockId in ["voicetrack-a", "voicetrack-b"] {
      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
        Issue.record("Expected the voicetrack recorder to be pushed")
        return
      }
      await recorder.onCompleted?(block(blockId, type: "voiceTrack"))
    }
    await model.waitForPendingSaves()

    expectNoDifference(positions.value, [0, 1])
  }

  @Test func reorderingWaitsForPendingSaves() async {
    await withMainSerialExecutor {
      let (removeGate, openRemove) = AsyncStream<Void>.makeStream()
      let loaded = episode(segments: [segment("s1", position: 0), segment("s2", position: 1)])
      let model = makeModel(episode: loaded) {
        $0.api.removeEpisodeSegment = { _, _, _ in
          for await _ in removeGate { break }
          return loaded
        }
      }
      await model.viewAppeared()
      #expect(model.canReorder)

      let removal = Task { await model.segmentDeleteTapped("s2") }
      await Task.megaYield()
      #expect(!model.canReorder)

      openRemove.yield()
      openRemove.finish()
      await removal.value
      #expect(model.canReorder)
    }
  }

  @Test func existingShowCannotBeEditedBeforeItLoads() async {
    let model = makeModel()

    #expect(!model.canEditContent)
    #expect(!model.canRename)
    #expect(!model.canChangeSeries)
    model.renameButtonTapped()
    #expect(!model.isRenameAlertPresented)

    await model.viewAppeared()

    #expect(model.canEditContent)
    #expect(model.canRename)
  }

  @Test func untouchedBuilderCreatesNothing() async {
    let created = LockIsolated(false)
    let model = makeModel(episodeId: nil) {
      $0.api.createStandaloneEpisode = { _, _, _ in
        created.setValue(true)
        throw ShowBuilderTestError()
      }
      $0.api.createEpisodeInSeries = { _, _, _ in
        created.setValue(true)
        throw ShowBuilderTestError()
      }
    }

    await model.viewAppeared()

    #expect(!created.value)
    #expect(model.episode == nil)
    expectNoDifference(model.navigationTitle, "New Show")
  }

  @Test func viewAppearedLoadsEpisodeAndSettings() async {
    let loaded = episode(segments: [segment("s1", position: 0)])
    let requestedEpisodes = LockIsolated<[String]>([])
    let model = makeModel(episode: loaded, settings: settings("America/New_York")) {
      $0.api.getCuratorEpisode = { _, episodeId in
        requestedEpisodes.withValue { $0.append(episodeId) }
        return loaded
      }
    }

    await model.viewAppeared()

    expectNoDifference(requestedEpisodes.value, ["episode-1"])
    expectNoDifference(model.episode, loaded)
    expectNoDifference(model.settings, settings("America/New_York"))
  }

  // MARK: - Content

  @Test func addingQAndASendsBothIdsInOneRequest() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let requests = LockIsolated<[[String]]>([])
    let positions = LockIsolated<[Int]>([])
    let loaded = episode(segments: [segment("s1", position: 0), segment("s2", position: 1)])
    let model = makeModel(episode: loaded) {
      $0.api.addEpisodeSegments = { _, _, ids, position in
        requests.withValue { $0.append(ids) }
        positions.withValue { $0.append(position) }
        return loaded
      }
    }
    await model.viewAppeared()

    model.qaActionTapped()
    guard case .amaQuestionPickerPage(let picker) = coordinator.path.last else {
      Issue.record("Expected the question picker to be pushed")
      return
    }
    try await picker.addToShow(
      AMAQuestionAnswer(
        questionId: "question-1", listenerName: "Maya",
        questionBlock: block("question-audio"), answerBlock: block("answer-audio")))

    expectNoDifference(requests.value, [["question-audio", "answer-audio"]])
    expectNoDifference(positions.value, [2])
  }

  @Test func failedQAndAAdditionThrowsBackToTheAnswerPage() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = makeModel(episode: episode(segments: [segment("s1", position: 0)])) {
      $0.api.addEpisodeSegments = { _, _, _, _ in
        throw APIError.recordedShowLocked("This show is locked because it airs soon.")
      }
      $0.errorReporting.reportError = { _, _ in }
    }
    await model.viewAppeared()

    model.qaActionTapped()
    guard case .amaQuestionPickerPage(let picker) = coordinator.path.last else {
      Issue.record("Expected the question picker to be pushed")
      return
    }
    await #expect(throws: APIError.self) {
      try await picker.addToShow(
        AMAQuestionAnswer(
          questionId: "question-1", listenerName: "Maya",
          questionBlock: block("question-audio"), answerBlock: block("answer-audio")))
    }

    #expect(model.presentedAlert == nil)
    #expect(model.refusedAsLocked)
  }

  @Test func songPickerOffersAvailableSongsOnly() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let requests = LockIsolated<[[String]]>([])
    let loaded = episode(segments: [segment("s1", position: 0, audio: block("song-1"))])
    let model = makeModel(episode: loaded) {
      $0.api.addEpisodeSegments = { _, _, ids, _ in
        requests.withValue { $0.append(ids) }
        return loaded
      }
    }
    await model.viewAppeared()

    model.songActionTapped()
    guard case .curatorSongPicker(let picker) = coordinator.presentedSheet else {
      Issue.record("Expected the song picker to be presented")
      return
    }
    #expect(!picker.offersSongRequests)
    #expect(picker.isAdded(block("song-1")))

    picker.addButtonTapped(block("song-2"))
    await model.waitForPendingSaves()

    expectNoDifference(requests.value, [["song-2"]])
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func recordedVoicetrackIsAddedToTheEnd() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let requests = LockIsolated<[[String]]>([])
    let positions = LockIsolated<[Int]>([])
    let loaded = episode(segments: [segment("s1", position: 0)])
    let model = makeModel(episode: loaded) {
      $0.api.addEpisodeSegments = { _, _, ids, position in
        requests.withValue { $0.append(ids) }
        positions.withValue { $0.append(position) }
        return loaded
      }
    }
    await model.viewAppeared()

    model.voicetrackActionTapped()
    guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
      Issue.record("Expected the voicetrack recorder to be pushed")
      return
    }
    #expect(recorder.onUseRecording != nil)
    let onCompleted = try #require(recorder.onCompleted)
    await onCompleted(block("voicetrack-1", type: "voiceTrack"))
    await model.waitForPendingSaves()

    expectNoDifference(requests.value, [["voicetrack-1"]])
    expectNoDifference(positions.value, [1])
  }

  @Test func reorderSendsNewPosition() async {
    let moves = LockIsolated<[String]>([])
    let loaded = episode(segments: [
      segment("s1", position: 0), segment("s2", position: 1), segment("s3", position: 2),
    ])
    let model = makeModel(episode: loaded) {
      $0.api.moveEpisodeSegment = { _, episodeId, segmentId, position in
        moves.withValue { $0.append("\(episodeId):\(segmentId)->\(position)") }
        return loaded
      }
    }
    await model.viewAppeared()

    await model.segmentsMoved(from: IndexSet(integer: 0), to: 3)
    await model.segmentsMoved(from: IndexSet(integer: 2), to: 0)

    expectNoDifference(moves.value, ["episode-1:s1->2", "episode-1:s3->0"])
  }

  @Test func failedReorderRestoresTheSavedOrder() async {
    let fetchCount = LockIsolated(0)
    let loaded = episode(segments: [
      segment("s1", position: 0), segment("s2", position: 1), segment("s3", position: 2),
    ])
    let model = makeModel(episode: loaded) {
      $0.api.getCuratorEpisode = { _, _ in
        let count = fetchCount.withValue {
          $0 += 1
          return $0
        }
        guard count == 1 else { throw ShowBuilderTestError() }
        return loaded
      }
      $0.api.moveEpisodeSegment = { _, _, _, _ in throw ShowBuilderTestError() }
      $0.errorReporting.reportError = { _, _ in }
    }
    await model.viewAppeared()

    await model.segmentsMoved(from: IndexSet(integer: 0), to: 3)

    expectNoDifference(model.rows.map(\.id), ["s1", "s2", "s3"])
  }

  @Test func removingASegmentSendsItsId() async {
    let removed = LockIsolated<[String]>([])
    let loaded = episode(segments: [segment("s1", position: 0), segment("s2", position: 1)])
    let model = makeModel(episode: loaded) {
      $0.api.removeEpisodeSegment = { _, _, segmentId in
        removed.withValue { $0.append(segmentId) }
        return loaded
      }
    }
    await model.viewAppeared()

    await model.segmentDeleteTapped("s2")

    expectNoDifference(removed.value, ["s2"])
  }

  @Test func renameSendsTheNewTitle() async {
    let updates = LockIsolated<[CuratorEpisodeUpdate]>([])
    let model = makeModel {
      $0.api.updateEpisode = { [loaded = episode()] _, _, update in
        updates.withValue { $0.append(update) }
        return loaded
      }
    }
    await model.viewAppeared()

    model.renameButtonTapped()
    #expect(model.isRenameAlertPresented)
    expectNoDifference(model.renameText, "Tour Stories")
    model.renameText = "  Road Stories "
    await model.renameSaveButtonTapped()

    expectNoDifference(updates.value, [CuratorEpisodeUpdate(title: "Road Stories")])
  }

  @Test func renameKeepsTheShowContentWhenTheRefetchFails() async {
    let fetchCount = LockIsolated(0)
    let loaded = episode(segments: [segment("s1", position: 0), segment("s2", position: 1)])
    let model = makeModel(episode: loaded) {
      $0.api.getCuratorEpisode = { _, _ in
        let count = fetchCount.withValue {
          $0 += 1
          return $0
        }
        guard count == 1 else { throw ShowBuilderTestError() }
        return loaded
      }
      $0.api.updateEpisode = { [renamed = episode(title: "Road Stories")] _, _, _ in renamed }
      $0.errorReporting.reportError = { _, _ in }
    }
    await model.viewAppeared()

    model.renameButtonTapped()
    model.renameText = "Road Stories"
    await model.renameSaveButtonTapped()

    expectNoDifference(model.rows.map(\.id), ["s1", "s2"])
  }

  // MARK: - Errors

  @Test func lockedRefusalSwitchesToLockedAndRefetches() async {
    let fetchCount = LockIsolated(0)
    let reported = LockIsolated(0)
    let loaded = episode(segments: [segment("s1", position: 0)], airings: [airing()])
    let model = makeModel(episode: loaded) {
      $0.api.getCuratorEpisode = { _, _ in
        fetchCount.withValue { $0 += 1 }
        return loaded
      }
      $0.api.removeEpisodeSegment = { _, _, _ in
        throw APIError.recordedShowLocked("This show is locked because it airs soon.")
      }
      $0.errorReporting.reportError = { _, _ in reported.withValue { $0 += 1 } }
    }
    await model.viewAppeared()
    #expect(model.state == .scheduled(airing()))

    await model.segmentDeleteTapped("s1")

    expectNoDifference(model.presentedAlert?.message, "This show is locked because it airs soon.")
    expectNoDifference(model.state, .locked(airing()))
    expectNoDifference(fetchCount.value, 2)
    expectNoDifference(reported.value, 1)
  }

  @Test func failedSaveShowsAlertAndRefetches() async {
    let fetchCount = LockIsolated(0)
    let reported = LockIsolated(0)
    let loaded = episode(segments: [segment("s1", position: 0)])
    let model = makeModel(episode: loaded) {
      $0.api.getCuratorEpisode = { _, _ in
        fetchCount.withValue { $0 += 1 }
        return loaded
      }
      $0.api.addEpisodeSegments = { _, _, _, _ in
        throw APIError.serverError("Something went wrong on our end.")
      }
      $0.errorReporting.reportError = { _, _ in reported.withValue { $0 += 1 } }
    }
    await model.viewAppeared()

    await model.save { [api = model.api] id in
      _ = try await api.addEpisodeSegments("test-jwt", id, ["song-9"], 1)
    }

    expectNoDifference(model.presentedAlert?.message, "Something went wrong on our end.")
    expectNoDifference(fetchCount.value, 2)
    expectNoDifference(reported.value, 1)
  }

  @Test func cancelledSaveShowsNoAlert() async {
    let model = makeModel()
    await model.viewAppeared()

    await model.save { _ in throw CancellationError() }

    #expect(model.presentedAlert == nil)
  }

  @Test func removingLastAudioOfScheduledShowShowsServerMessage() async {
    let message = "Unschedule this show before removing its last piece of audio."
    let loaded = episode(segments: [segment("s1", position: 0)], airings: [airing()])
    let model = makeModel(episode: loaded) {
      $0.api.removeEpisodeSegment = { _, _, _ in throw APIError.serverError(message) }
    }
    await model.viewAppeared()

    await model.segmentDeleteTapped("s1")

    expectNoDifference(model.presentedAlert?.message, message)
    expectNoDifference(model.rows.map(\.id), ["s1"])
    expectNoDifference(model.state, .scheduled(airing()))
  }

  // MARK: - States

  @Test func lockedShowHidesAddActionsButKeepsRenameSeriesAndUnschedule() async {
    let series = CuratorSeries(
      id: "series-1", stationId: stationId, title: "This One\u{2019}s For You",
      isOneTime: false, rrule: "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0")
    let loaded = episode(
      show: series, segments: [segment("s1", position: 0)], airings: [airing()])
    let model = makeModel(episode: loaded, now: airtime.addingTimeInterval(-3600))
    await model.viewAppeared()

    expectNoDifference(model.state, .locked(airing()))
    #expect(!model.canEditContent)
    expectNoDifference(model.addCardOpacity, 0)
    expectNoDifference(model.rows.map(\.data.isEditable), [false])
    #expect(model.canRename)
    #expect(model.canChangeSeries)
    expectNoDifference(model.seriesTitle, "This One\u{2019}s For You")
    expectNoDifference(model.seriesActionText, "Change")
    expectNoDifference(model.unscheduleButtons, ["Unschedule"])
    expectNoDifference(model.scheduleButtons, [])
    expectNoDifference(model.changeTimeButtons, [])
    expectNoDifference(model.lockedBanners.map(\.title), ["Locked"])
    expectNoDifference(
      model.lockedBanners.map(\.message),
      [
        "Shows lock 6 hours before they air. You can still rename it, change its series, "
          + "or unschedule it."
      ])
  }

  @Test func lockedShowIgnoresContentActions() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let removed = LockIsolated(false)
    let loaded = episode(segments: [segment("s1", position: 0)], airings: [airing()])
    let model = makeModel(episode: loaded, now: airtime.addingTimeInterval(-3600)) {
      $0.api.removeEpisodeSegment = { _, _, _ in
        removed.setValue(true)
        return loaded
      }
    }
    await model.viewAppeared()

    model.songActionTapped()
    model.qaActionTapped()
    model.voicetrackActionTapped()
    await model.segmentDeleteTapped("s1")

    #expect(coordinator.path.isEmpty)
    #expect(coordinator.presentedSheet == nil)
    #expect(!removed.value)
  }

  @Test func navigationTitleAndStatusLinesMatchScreens() async {
    let draft = makeModel(episode: episode())
    await draft.viewAppeared()
    expectNoDifference(draft.navigationTitle, "Tour Stories")
    expectNoDifference(draft.renameButtonTitle, "Rename")
    expectNoDifference(draft.headline, "Not scheduled yet")
    expectNoDifference(draft.statusLine, "19 min \u{00B7} Changes save automatically")
    expectNoDifference(draft.lockLines, [])
    expectNoDifference(draft.seriesTitle, "Add to a series")
    expectNoDifference(draft.seriesActionText, "Optional")
    expectNoDifference(draft.yourShowTitle, "YOUR SHOW")
    expectNoDifference(draft.totalDurationText, "18:35")
    expectNoDifference(draft.addSectionTitle, "Add to Show")
    expectNoDifference(draft.addSectionExplanation, "Added to the end of your playlist")
    expectNoDifference(draft.scheduleButtons, ["Schedule"])
    expectNoDifference(draft.unscheduleButtons, [])

    let scheduled = makeModel(episode: episode(airings: [airing()]))
    await scheduled.viewAppeared()
    expectNoDifference(scheduled.headline, "Sunday, Nov 22 \u{00B7} 7:00 PM")
    expectNoDifference(scheduled.statusLine, "19 min \u{00B7} Changes save automatically")
    expectNoDifference(scheduled.lockLines, ["You can make changes until Sun, Nov 22 at 1:00 PM"])
    expectNoDifference(scheduled.changeTimeButtons, ["Change"])
    expectNoDifference(scheduled.lockedBanners, [])

    let locked = makeModel(
      episode: episode(airings: [airing()]), now: airtime.addingTimeInterval(-3600))
    await locked.viewAppeared()
    expectNoDifference(locked.headline, "Sunday, Nov 22 \u{00B7} 7:00 PM")
    expectNoDifference(
      locked.statusLine, "19 min \u{00B7} Airs at about 7:00 PM \u{00B7} locked")
    expectNoDifference(locked.lockLines, [])

    let onAir = makeModel(
      episode: episode(airings: [airing(startTime: airtime.addingTimeInterval(60))]),
      now: airtime.addingTimeInterval(120))
    await onAir.viewAppeared()
    expectNoDifference(onAir.statusLine, "19 min \u{00B7} On air now")

    let newShow = makeModel(episodeId: nil)
    await newShow.viewAppeared()
    expectNoDifference(newShow.navigationTitle, "New Show")
    expectNoDifference(newShow.statusLine, "Changes save automatically")
  }

  @Test func statusAndLockLinesUseStationTimeZone() async {
    let model = makeModel(
      episode: episode(airings: [airing()]), settings: settings("America/New_York"))
    await model.viewAppeared()

    expectNoDifference(model.headline, "Sunday, Nov 22 \u{00B7} 8:00 PM")
    expectNoDifference(model.lockLines, ["You can make changes until Sun, Nov 22 at 2:00 PM"])
    expectNoDifference(model.calendarBadges.map(\.timeZone.identifier), ["America/New_York"])
  }

  @Test func multiAiringShowOpensReadOnly() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let loaded = episode(
      segments: [segment("s1", position: 0)],
      airings: [
        airing("airing-1"), airing("airing-2", at: airtime.addingTimeInterval(7 * 24 * 3600)),
      ])
    let model = makeModel(episode: loaded)
    await model.viewAppeared()

    #expect(!model.canEditContent)
    #expect(!model.canRename)
    #expect(!model.canChangeSeries)
    expectNoDifference(model.addCardOpacity, 0)
    expectNoDifference(model.rows.map(\.data.isEditable), [false])
    expectNoDifference(model.scheduleButtons, [])
    expectNoDifference(model.unscheduleButtons, [])
    expectNoDifference(model.changeTimeButtons, [])
    expectNoDifference(
      model.readOnlyNotices,
      ["This show airs more than once, so it can only be changed on the web."])

    model.renameButtonTapped()
    model.songActionTapped()
    #expect(!model.isRenameAlertPresented)
    #expect(coordinator.presentedSheet == nil)
  }
}
