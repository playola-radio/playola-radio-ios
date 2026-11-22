//
//  ShowBuilderPageSchedulingTests.swift
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
struct ShowBuilderPageSchedulingTests {

  // MARK: - Test Helpers

  private let stationId = "station-1"
  // Sunday, Nov 22 2026 at 7:00 PM in Chicago.
  private let airtime = Date(timeIntervalSince1970: 1_795_395_600)
  private let week: TimeInterval = 7 * 24 * 3600

  nonisolated private var weeklySeries: CuratorSeries {
    CuratorSeries(
      id: "series-1", stationId: stationId, title: "This One\u{2019}s For You",
      isOneTime: false, rrule: "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0")
  }

  nonisolated private func airing(at time: Date? = nil) -> CuratorAiring {
    CuratorAiring(
      id: "airing-1", episodeId: "episode-1", stationId: stationId, airtime: time ?? airtime,
      startTime: nil, endTime: nil)
  }

  nonisolated private func episode(
    durationMS: Int = 1_115_000, airings: [CuratorAiring] = []
  ) -> CuratorEpisode {
    CuratorEpisode(
      id: "episode-1", showId: "series-1", title: "Tour Stories", durationMS: durationMS,
      show: weeklySeries, segments: [], airings: airings)
  }

  private func makeModel(
    episodeId: String? = "episode-1",
    current: LockIsolated<CuratorEpisode>? = nil,
    slot: Date? = nil,
    notificationCenter: NotificationCenter = NotificationCenter(),
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) -> ShowBuilderPageModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let loaded = current ?? LockIsolated(episode())
    let now = airtime.addingTimeInterval(-24 * 3600)
    return withDependencies {
      $0.date.now = now
      $0.notificationCenter = notificationCenter
      $0.api.getCuratorEpisode = { _, _ in loaded.value }
      $0.api.getStationSchedulingSettings = { _, _ in
        StationSchedulingSettings(timezone: "America/Chicago", airingEditLockMS: 21_600_000)
      }
      $0.api.getListenerQuestions = { _, _ in [] }
      $0.api.getAirings = { _, _ in [] }
      $0.errorReporting.reportError = { _, _ in }
      configure(&$0)
    } operation: {
      ShowBuilderPageModel(
        stationId: stationId, episodeId: episodeId, seriesId: nil, slot: slot)
    }
  }

  private func presentedScheduleSheet(
    _ coordinator: MainContainerNavigationCoordinator
  ) -> ScheduleShowSheetModel? {
    guard case .scheduleShow(let sheet) = coordinator.presentedSheet else { return nil }
    return sheet
  }

  private func presentedUnscheduleSheet(
    _ coordinator: MainContainerNavigationCoordinator
  ) -> UnscheduleShowSheetModel? {
    guard case .unscheduleShow(let sheet) = coordinator.presentedSheet else { return nil }
    return sheet
  }

  // MARK: - Schedule

  @Test func scheduleOpensTheSheetAndSchedulesTheDraft() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let calls = LockIsolated<[String]>([])
    let model = makeModel {
      $0.api.scheduleEpisode = { _, episodeId, stationId, airtime in
        calls.withValue { $0.append("\(episodeId):\(stationId):\(airtime.timeIntervalSince1970)") }
      }
      $0.api.moveAiring = { _, _, _ in calls.withValue { $0.append("move") } }
    }
    await model.viewAppeared()

    await model.scheduleButtonTapped()
    let sheet = presentedScheduleSheet(coordinator)
    await sheet?.scheduleButtonTapped()

    expectNoDifference(
      calls.value, ["episode-1:station-1:\(airtime.timeIntervalSince1970)"])
    #expect(coordinator.presentedSheet == nil)
    #expect(model.presentedAlert == nil)
  }

  @Test func slotSeedsTheSheetsInitialTime() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let chosenSlot = airtime.addingTimeInterval(2 * week)
    let model = makeModel(slot: chosenSlot)
    await model.viewAppeared()

    await model.scheduleButtonTapped()

    expectNoDifference(presentedScheduleSheet(coordinator)?.pickedTime, chosenSlot)
  }

  @Test func sheetListsSlotsNotTakenByOtherShows() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let ownScheduled = episode(airings: [airing(at: airtime.addingTimeInterval(week))])
    let takenByAnotherStationsSeries = Airing.mockWith(
      id: "airing-2", episodeId: "episode-2", stationId: stationId, airtime: airtime,
      episode: .mockWith(id: "episode-2", durationMS: 1_800_000))
    let ownAiring = Airing.mockWith(
      id: "airing-1", episodeId: "episode-1", stationId: stationId,
      airtime: airtime.addingTimeInterval(week),
      episode: .mockWith(id: "episode-1", durationMS: 1_115_000))
    let model = makeModel(current: LockIsolated(ownScheduled)) {
      $0.api.getAirings = { _, requestedStationId in
        #expect(requestedStationId == "station-1")
        return [takenByAnotherStationsSeries, ownAiring]
      }
    }
    await model.viewAppeared()

    await model.changeTimeButtonTapped()

    let ids = presentedScheduleSheet(coordinator)?.slotRows.map(\.id)
    expectNoDifference(ids?.first, airtime.addingTimeInterval(week))
    #expect(ids?.contains(airtime) == false)
  }

  @Test func scheduleWithNothingInTheShowYetAsksForContentFirst() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = makeModel(episodeId: nil)

    await model.scheduleButtonTapped()

    #expect(coordinator.presentedSheet == nil)
    expectNoDifference(model.presentedAlert?.title, "Nothing to Schedule Yet")
  }

  @Test func scheduleWithAnEmptyDraftAsksForContentFirst() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = makeModel(current: LockIsolated(episode(durationMS: 0)))
    await model.viewAppeared()

    await model.scheduleButtonTapped()

    #expect(coordinator.presentedSheet == nil)
    expectNoDifference(model.presentedAlert?.title, "Nothing to Schedule Yet")
  }

  @Test func unavailableSlotSuggestionsShowAToastAndDoNotOpenTheSheet() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let shownToasts = LockIsolated<[PlayolaToast]>([])
    let reports = LockIsolated(0)
    let model = makeModel {
      $0.api.getAirings = { _, _ in throw APIError.dataNotValid }
      $0.errorReporting.reportError = { _, _ in reports.withValue { $0 += 1 } }
      $0.toast.show = { toast in shownToasts.withValue { $0.append(toast) } }
    }
    await model.viewAppeared()

    await model.scheduleButtonTapped()

    #expect(coordinator.presentedSheet == nil)
    expectNoDifference(shownToasts.value.map(\.message), ["Open slots couldn’t load."])
    expectNoDifference(reports.value, 1)
  }

  @Test func overlapRefusalStaysInTheSheetWithoutASecondAlert() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let message = "This overlaps Fall Favorites."
    let model = makeModel {
      $0.api.scheduleEpisode = { _, _, _, _ in throw APIError.serverError(message) }
    }
    await model.viewAppeared()
    await model.scheduleButtonTapped()
    let sheet = presentedScheduleSheet(coordinator)

    await sheet?.scheduleButtonTapped()

    expectNoDifference(sheet?.errorLines, [message])
    #expect(sheet?.isScheduleEnabled == false)
    #expect(model.presentedAlert == nil)
    #expect(coordinator.presentedSheet != nil)
  }

  // MARK: - Change time

  @Test func changeMovesTheExistingAiring() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let scheduled = episode(airings: [airing()])
    let moves = LockIsolated<[String]>([])
    let model = makeModel(current: LockIsolated(scheduled)) {
      $0.api.moveAiring = { _, airingId, airtime in
        moves.withValue { $0.append("\(airingId):\(airtime.timeIntervalSince1970)") }
      }
      $0.api.scheduleEpisode = { _, _, _, _ in moves.withValue { $0.append("schedule") } }
    }
    await model.viewAppeared()

    await model.changeTimeButtonTapped()
    let sheet = presentedScheduleSheet(coordinator)
    expectNoDifference(sheet?.pickedTime, airtime)
    sheet?.pickedTime = airtime.addingTimeInterval(week)
    await sheet?.scheduleButtonTapped()

    expectNoDifference(
      moves.value, ["airing-1:\(airtime.addingTimeInterval(week).timeIntervalSince1970)"])
  }

  // MARK: - Unschedule

  @Test func unscheduleAsksBeforeDoingAnything() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let calls = LockIsolated(0)
    let model = makeModel(current: LockIsolated(episode(airings: [airing()]))) {
      $0.api.unscheduleAiring = { _, _ in calls.withValue { $0 += 1 } }
    }
    await model.viewAppeared()

    await model.unscheduleButtonTapped()

    #expect(presentedUnscheduleSheet(coordinator) != nil)
    expectNoDifference(calls.value, 0)
  }

  @Test func unscheduleReturnsTheShowToDraftAndClearsTheLockedRefusal() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let draft = episode()
    let current = LockIsolated(episode(airings: [airing()]))
    let unscheduledIds = LockIsolated<[String]>([])
    let model = makeModel(current: current) {
      $0.api.unscheduleAiring = { _, airingId in
        unscheduledIds.withValue { $0.append(airingId) }
        current.setValue(draft)
      }
    }
    await model.viewAppeared()
    model.refusedAsLocked = true
    await model.unscheduleButtonTapped()

    await presentedUnscheduleSheet(coordinator)?.unscheduleConfirmed()

    expectNoDifference(unscheduledIds.value, ["airing-1"])
    expectNoDifference(model.draftBadges, ["draft"])
    #expect(!model.refusedAsLocked)
    #expect(coordinator.presentedSheet == nil)
    expectNoDifference(model.scheduleButtons, ["Schedule"])
  }

  @Test func unscheduleRefusalShowsServerMessageAndKeepsTheShowScheduled() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let message = "This show is about to go on the air."
    let model = makeModel(current: LockIsolated(episode(airings: [airing()]))) {
      $0.api.unscheduleAiring = { _, _ in throw APIError.serverError(message) }
    }
    await model.viewAppeared()
    await model.unscheduleButtonTapped()
    let sheet = presentedUnscheduleSheet(coordinator)

    await sheet?.unscheduleConfirmed()

    expectNoDifference(sheet?.errorLines, [message])
    #expect(model.presentedAlert == nil)
    expectNoDifference(model.unscheduleButtons, ["Unschedule"])
  }

  @Test func retryAfterCommittedScheduleDoesNotMoveTheLockedAiring() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let current = LockIsolated(episode())
    let calls = LockIsolated(0)
    let scheduled = episode(airings: [airing()])
    let model = makeModel(current: current) {
      $0.api.scheduleEpisode = { _, _, _, _ in
        current.setValue(scheduled)
        throw APIError.serverError("Response lost")
      }
      $0.api.moveAiring = { _, _, _ in calls.withValue { $0 += 1 } }
    }
    await model.viewAppeared()
    await model.scheduleButtonTapped()
    let sheet = presentedScheduleSheet(coordinator)
    await sheet?.scheduleButtonTapped()
    await sheet?.scheduleButtonTapped()
    expectNoDifference(calls.value, 0)
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func failedRefreshAfterSchedulingKeepsScheduleChangesUnavailable() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let reads = LockIsolated(0)
    let model = makeModel {
      $0.api.getCuratorEpisode = { [draft = episode()] _, _ in
        let count = reads.withValue {
          $0 += 1
          return $0
        }
        if count > 1 { throw APIError.dataNotValid }
        return draft
      }
      $0.api.scheduleEpisode = { _, _, _, _ in }
    }
    await model.viewAppeared()
    await model.scheduleButtonTapped()
    await presentedScheduleSheet(coordinator)?.scheduleButtonTapped()
    expectNoDifference(model.scheduleButtons, [])
    #expect(coordinator.presentedSheet != nil)
  }

  @Test func failedRefreshAfterMovingKeepsScheduleChangesUnavailable() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let reads = LockIsolated(0)
    let model = makeModel {
      $0.api.getCuratorEpisode = { [scheduled = episode(airings: [airing()])] _, _ in
        let count = reads.withValue {
          $0 += 1
          return $0
        }
        if count > 1 { throw APIError.dataNotValid }
        return scheduled
      }
      $0.api.moveAiring = { _, _, _ in }
    }
    await model.viewAppeared()
    await model.changeTimeButtonTapped()
    let sheet = presentedScheduleSheet(coordinator)
    sheet?.pickedTime = airtime.addingTimeInterval(week)
    await sheet?.scheduleButtonTapped()
    expectNoDifference(model.changeTimeButtons, [])
    expectNoDifference(model.unscheduleButtons, [])
    #expect(coordinator.presentedSheet != nil)
  }

  @Test func failedRefreshAfterUnschedulingKeepsScheduleChangesUnavailable() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let reads = LockIsolated(0)
    let model = makeModel {
      $0.api.getCuratorEpisode = { [scheduled = episode(airings: [airing()])] _, _ in
        let count = reads.withValue {
          $0 += 1
          return $0
        }
        if count > 1 { throw APIError.dataNotValid }
        return scheduled
      }
      $0.api.unscheduleAiring = { _, _ in }
    }
    await model.viewAppeared()
    await model.unscheduleButtonTapped()
    await presentedUnscheduleSheet(coordinator)?.unscheduleConfirmed()
    expectNoDifference(model.changeTimeButtons, [])
    expectNoDifference(model.unscheduleButtons, [])
    #expect(coordinator.presentedSheet != nil)
  }

  // MARK: - Change notifications

  @Test func schedulingMovingAndUnschedulingPostRecordedShowsChanged() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let notificationCenter = NotificationCenter()
    let posted = LockIsolated<[String?]>([])
    let observer = notificationCenter.addObserver(
      forName: .recordedShowsChanged, object: nil, queue: nil
    ) { notification in
      let stationId = notification.userInfo?["stationId"] as? String
      posted.withValue { $0.append(stationId) }
    }
    defer { notificationCenter.removeObserver(observer) }
    let draft = episode()
    let scheduled = episode(airings: [airing()])
    let current = LockIsolated(draft)
    let model = makeModel(current: current, notificationCenter: notificationCenter) {
      $0.api.scheduleEpisode = { _, _, _, _ in current.setValue(scheduled) }
      $0.api.moveAiring = { _, _, _ in }
      $0.api.unscheduleAiring = { _, _ in current.setValue(draft) }
    }
    await model.viewAppeared()

    await model.scheduleButtonTapped()
    await presentedScheduleSheet(coordinator)?.scheduleButtonTapped()
    expectNoDifference(posted.value, ["station-1"])

    await model.changeTimeButtonTapped()
    await presentedScheduleSheet(coordinator)?.scheduleButtonTapped()
    expectNoDifference(posted.value, ["station-1", "station-1"])

    await model.unscheduleButtonTapped()
    await presentedUnscheduleSheet(coordinator)?.unscheduleConfirmed()
    expectNoDifference(posted.value, ["station-1", "station-1", "station-1"])
  }

  @Test func refusedSchedulingDoesNotPostRecordedShowsChanged() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let notificationCenter = NotificationCenter()
    let posts = LockIsolated(0)
    let observer = notificationCenter.addObserver(
      forName: .recordedShowsChanged, object: nil, queue: nil
    ) { _ in posts.withValue { $0 += 1 } }
    defer { notificationCenter.removeObserver(observer) }
    let model = makeModel(notificationCenter: notificationCenter) {
      $0.api.scheduleEpisode = { _, _, _, _ in throw APIError.serverError("No audio.") }
    }
    await model.viewAppeared()
    await model.scheduleButtonTapped()

    await presentedScheduleSheet(coordinator)?.scheduleButtonTapped()

    expectNoDifference(posts.value, 0)
  }
}
