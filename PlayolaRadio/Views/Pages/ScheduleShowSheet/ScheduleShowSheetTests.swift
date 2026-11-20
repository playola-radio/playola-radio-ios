//
//  ScheduleShowSheetTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ScheduleShowSheetTests {

  // MARK: - Test Helpers

  // Sunday, Nov 22 2026 at 7:00 PM in Chicago.
  private let airtime = Date(timeIntervalSince1970: 1_795_395_600)
  private let week: TimeInterval = 7 * 24 * 3600
  private let sixHoursMS = 21_600_000
  private let weeklyRule = "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0"

  private func series(rrule: String? = nil, isOneTime: Bool = false) -> CuratorSeries {
    CuratorSeries(
      id: "series-1", stationId: "station-1", title: "This One\u{2019}s For You",
      isOneTime: isOneTime, rrule: rrule ?? weeklyRule)
  }

  private func episode(
    title: String = "Tour Stories", durationMS: Int = 1_115_000, airings: [CuratorAiring] = []
  ) -> CuratorEpisode {
    CuratorEpisode(
      id: "episode-1", showId: "series-1", title: title, durationMS: durationMS, show: nil,
      segments: [], airings: airings)
  }

  private func settings(_ timezone: String = "America/Chicago") -> StationSchedulingSettings {
    StationSchedulingSettings(timezone: timezone, airingEditLockMS: sixHoursMS)
  }

  private func makeModel(
    episode: CuratorEpisode? = nil,
    series: CuratorSeries? = nil,
    settings: StationSchedulingSettings? = nil,
    occupiedIntervals: [DateInterval] = [],
    initialTime: Date? = nil,
    now: Date? = nil,
    schedule: @escaping @MainActor (Date) async throws -> Void = { _ in }
  ) -> ScheduleShowSheetModel {
    let resolvedNow = now ?? airtime.addingTimeInterval(-24 * 3600)
    return withDependencies {
      $0.date.now = resolvedNow
    } operation: {
      ScheduleShowSheetModel(
        episode: episode ?? self.episode(), series: series ?? self.series(),
        settings: settings ?? self.settings(), occupiedIntervals: occupiedIntervals,
        initialTime: initialTime, schedule: schedule)
    }
  }

  // MARK: - Open slots

  @Test func listsNextEightOpenSlotsForWeeklySeries() {
    let model = makeModel()

    expectNoDifference(
      model.slotRows.map(\.id), (0..<8).map { airtime.addingTimeInterval(Double($0) * week) })
    expectNoDifference(
      model.slotRows[0],
      ScheduleSlotRow(
        id: airtime, monthText: "NOV", dayText: "22", title: "Sunday \u{00B7} 7:00 PM",
        subtitle: "Airs at about 7:00 PM"))
    expectNoDifference(model.slotsSubtitleLines, ["Open slots in This One\u{2019}s For You"])
  }

  @Test func occupiedSlotsAreSkipped() {
    let occupied = DateInterval(start: airtime.addingTimeInterval(week), duration: 1_115)
    let model = makeModel(occupiedIntervals: [occupied])

    expectNoDifference(model.slotRows.count, 8)
    expectNoDifference(model.slotRows[1].id, airtime.addingTimeInterval(2 * week))
  }

  @Test func noSlotsForStandaloneShowOrUnparseableRule() {
    let oneTime = makeModel(series: series(isOneTime: true))
    let custom = makeModel(series: series(rrule: "FREQ=DAILY"))
    let noRule = makeModel(
      series: CuratorSeries(
        id: "series-2", stationId: "station-1", title: "Loose", isOneTime: false, rrule: nil))

    expectNoDifference(oneTime.slotRows.count, 0)
    expectNoDifference(custom.slotRows.count, 0)
    expectNoDifference(noRule.slotRows.count, 0)
    expectNoDifference(oneTime.slotsSubtitleLines, [])
  }

  @Test func tappingSlotFillsPickerWithoutScheduling() {
    let calls = LockIsolated(0)
    let model = makeModel { _ in calls.withValue { $0 += 1 } }

    model.slotTapped(model.slotRows[2])

    expectNoDifference(model.pickedTime, airtime.addingTimeInterval(2 * week))
    expectNoDifference(calls.value, 0)
  }

  // MARK: - Initial time

  @Test func startsOnTheFirstOpenSlotForASeries() {
    expectNoDifference(makeModel().pickedTime, airtime)
  }

  @Test func initialTimeWinsOverTheFirstOpenSlot() {
    let requested = airtime.addingTimeInterval(week + 15 * 60)

    expectNoDifference(makeModel(initialTime: requested).pickedTime, requested)
  }

  @Test func standaloneShowStartsJustOutsideTheLock() {
    let model = makeModel(series: series(isOneTime: true))

    expectNoDifference(model.pickedTime, airtime.addingTimeInterval(-17 * 3600))
    expectNoDifference(model.lockNotes.count, 0)
  }

  // MARK: - Lock note

  @Test func showsLocksRightAwayInsideLock() {
    let now = airtime.addingTimeInterval(-24 * 3600)
    let inside = makeModel(initialTime: now.addingTimeInterval(3 * 3600), now: now)
    let boundary = makeModel(initialTime: now.addingTimeInterval(6 * 3600), now: now)
    let outside = makeModel(initialTime: now.addingTimeInterval(7 * 3600), now: now)

    expectNoDifference(inside.lockNotes.map(\.title), ["Locks right away"])
    expectNoDifference(
      inside.lockNotes.map(\.body),
      [
        "This is less than 6 hours away, so Tour Stories\u{2019} songs and time lock as soon as "
          + "it\u{2019}s scheduled. To change them later, unschedule it first."
      ])
    expectNoDifference(boundary.lockNotes.count, 1)
    expectNoDifference(outside.lockNotes.count, 0)
  }

  @Test func lockNoteFollowsThePickedTime() {
    let now = airtime.addingTimeInterval(-24 * 3600)
    let model = makeModel(initialTime: now.addingTimeInterval(3 * 3600), now: now)

    model.pickedTime = now.addingTimeInterval(9 * 3600)

    expectNoDifference(model.lockNotes.count, 0)
  }

  @Test func lockNoteUsesTheStationsLockLength() {
    let now = airtime.addingTimeInterval(-24 * 3600)
    let twoHours = StationSchedulingSettings(
      timezone: "America/Chicago", airingEditLockMS: 7_200_000)
    let model = makeModel(
      episode: episode(title: "Road"), settings: twoHours,
      initialTime: now.addingTimeInterval(3600), now: now)

    expectNoDifference(
      model.lockNotes.map(\.body),
      [
        "This is less than 2 hours away, so Road\u{2019}s songs and time lock as soon as "
          + "it\u{2019}s scheduled. To change them later, unschedule it first."
      ])
  }

  // MARK: - Scheduling

  @Test func scheduleSendsThePickedTimeAndClosesTheSheet() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let scheduled = LockIsolated<[Date]>([])
    let model = makeModel { time in scheduled.withValue { $0.append(time) } }
    coordinator.presentedSheet = .scheduleShow(model)

    await model.scheduleButtonTapped()

    expectNoDifference(scheduled.value, [airtime])
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func scheduleDropsStraySecondsFromThePickedTime() async {
    let scheduled = LockIsolated<[Date]>([])
    let model = makeModel { time in scheduled.withValue { $0.append(time) } }

    model.pickedTime = airtime.addingTimeInterval(27)
    await model.scheduleButtonTapped()

    expectNoDifference(scheduled.value, [airtime])
  }

  @Test func successDoesNotCloseADifferentSheet() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let other = PlayolaSheet.share(ShareSheetModel(items: ["x"]))
    coordinator.presentedSheet = other
    let model = makeModel()

    await model.scheduleButtonTapped()

    #expect(coordinator.presentedSheet == other)
  }

  @Test func cancelClosesTheSheetWithoutScheduling() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let calls = LockIsolated(0)
    let model = makeModel { _ in calls.withValue { $0 += 1 } }
    coordinator.presentedSheet = .scheduleShow(model)

    model.cancelButtonTapped()

    #expect(coordinator.presentedSheet == nil)
    expectNoDifference(calls.value, 0)
  }

  @Test func scheduleButtonDisabledWhileSaving() async {
    await withMainSerialExecutor {
      let calls = LockIsolated(0)
      let (gate, openGate) = AsyncStream<Void>.makeStream()
      let model = makeModel { _ in
        calls.withValue { $0 += 1 }
        for await _ in gate { break }
      }

      let first = Task { await model.scheduleButtonTapped() }
      await Task.megaYield()
      #expect(model.isSaving)
      #expect(!model.isScheduleEnabled)
      await model.scheduleButtonTapped()
      openGate.yield()
      openGate.finish()
      await first.value

      expectNoDifference(calls.value, 1)
      #expect(!model.isSaving)
    }
  }

  // MARK: - Saving blocks Cancel and swipe

  @Test func cancelAndSwipeAreBlockedWhileTheScheduleClosureRuns() async {
    await withMainSerialExecutor {
      @Shared(.mainContainerNavigationCoordinator) var coordinator =
        MainContainerNavigationCoordinator()
      let finished = LockIsolated(false)
      let (gate, openGate) = AsyncStream<Void>.makeStream()
      let model = makeModel { _ in
        for await _ in gate { break }
        finished.setValue(true)
      }
      coordinator.presentedSheet = .scheduleShow(model)
      #expect(model.isCancelEnabled)
      #expect(!model.isSwipeDismissDisabled)

      let save = Task { await model.scheduleButtonTapped() }
      await Task.megaYield()
      #expect(!model.isCancelEnabled)
      #expect(model.isSwipeDismissDisabled)

      model.cancelButtonTapped()
      #expect(coordinator.presentedSheet == .scheduleShow(model))
      #expect(model.isSaving)

      openGate.yield()
      openGate.finish()
      await save.value

      #expect(finished.value)
      #expect(coordinator.presentedSheet == nil)
      #expect(model.isCancelEnabled)
    }
  }

  @Test func aThrowingScheduleClosureKeepsTheSheetOpenAndCancelWorksAgain() async {
    await withMainSerialExecutor {
      @Shared(.mainContainerNavigationCoordinator) var coordinator =
        MainContainerNavigationCoordinator()
      let (gate, openGate) = AsyncStream<Void>.makeStream()
      let model = makeModel { _ in
        for await _ in gate { break }
        throw APIError.serverError("This overlaps Fall Favorites.")
      }
      coordinator.presentedSheet = .scheduleShow(model)

      let save = Task { await model.scheduleButtonTapped() }
      await Task.megaYield()
      model.cancelButtonTapped()
      #expect(coordinator.presentedSheet == .scheduleShow(model))
      openGate.yield()
      openGate.finish()
      await save.value

      expectNoDifference(model.errorLines, ["This overlaps Fall Favorites."])
      #expect(coordinator.presentedSheet == .scheduleShow(model))
      #expect(model.isCancelEnabled)
      #expect(!model.isSwipeDismissDisabled)

      model.cancelButtonTapped()
      #expect(coordinator.presentedSheet == nil)
    }
  }

  @Test func theDismissedClosureRunsOnceWhenTheSheetIsGone() {
    let dismissals = LockIsolated(0)
    let model = withDependencies {
      $0.date.now = airtime.addingTimeInterval(-24 * 3600)
    } operation: {
      ScheduleShowSheetModel(
        episode: episode(), series: series(), settings: settings(), occupiedIntervals: [],
        initialTime: nil, schedule: { _ in },
        dismissed: { dismissals.withValue { $0 += 1 } })
    }

    model.dismissed()
    model.dismissed()

    expectNoDifference(dismissals.value, 1)
  }

  @Test func withoutADismissedClosureDismissalDoesNothing() {
    makeModel().dismissed()
  }

  // MARK: - Refusals

  @Test func refusalShowsMessageAndDisablesScheduleUntilTimeChanges() async {
    let message = "This overlaps Fall Favorites, which airs 7:00\u{2013}7:38 PM."
    let model = makeModel { _ in throw APIError.serverError(message) }

    await model.scheduleButtonTapped()

    expectNoDifference(model.errorLines, [message])
    expectNoDifference(model.airsAtLines, [])
    #expect(!model.isScheduleEnabled)

    model.pickedTime = airtime.addingTimeInterval(15 * 60)
    #expect(model.isScheduleEnabled)
    expectNoDifference(model.errorLines, [])
    expectNoDifference(model.airsAtLines.count, 1)

    model.pickedTime = airtime
    #expect(!model.isScheduleEnabled)
    expectNoDifference(model.errorLines, [message])
  }

  @Test func lockRefusalShowsRedMessageAndStaysOpen() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = makeModel { _ in throw APIError.recordedShowLocked("This show is locked.") }
    coordinator.presentedSheet = .scheduleShow(model)

    await model.scheduleButtonTapped()

    expectNoDifference(model.errorLines, ["This show is locked."])
    #expect(!model.isScheduleEnabled)
    #expect(coordinator.presentedSheet == .scheduleShow(model))
  }

  @Test func missingAudioRefusalDisablesScheduleUntilTimeChanges() async {
    let model = makeModel { _ in throw APIError.serverError("No audio.") }

    await model.scheduleButtonTapped()

    expectNoDifference(model.errorLines, ["No audio."])
    #expect(!model.isScheduleEnabled)
  }

  @Test func connectivityFailureShowsMessageButAllowsRetry() async {
    let model = makeModel { _ in throw URLError(.notConnectedToInternet) }

    await model.scheduleButtonTapped()

    expectNoDifference(model.errorLines.count, 1)
    #expect(model.isScheduleEnabled)
  }

  @Test func temporaryServerFailureShowsMessageButAllowsRetry() async {
    let model = makeModel { _ in throw APIError.serverError("Something went wrong on our end.") }

    await model.scheduleButtonTapped()

    expectNoDifference(model.errorLines, ["Something went wrong on our end."])
    #expect(model.isScheduleEnabled)
  }

  @Test func cancelledScheduleShowsNothing() async {
    let model = makeModel { _ in throw CancellationError() }

    await model.scheduleButtonTapped()

    expectNoDifference(model.errorLines, [])
    #expect(model.isScheduleEnabled)
  }

  // MARK: - Labels

  @Test func scheduleSheetLabelsUseStationTimeZone() {
    let model = makeModel(settings: settings("Pacific/Auckland"), initialTime: airtime)

    expectNoDifference(model.airsAtLines, ["Airs at about 2:00 PM \u{00B7} ends about 2:19 PM"])
    expectNoDifference(model.slotRows[0].id, airtime.addingTimeInterval(-19 * 3600))
    expectNoDifference(model.slotRows[0].title, "Sunday \u{00B7} 7:00 PM")
    expectNoDifference(model.slotRows[0].dayText, "22")
    expectNoDifference(model.stationTimeZone.identifier, "Pacific/Auckland")
    expectNoDifference(model.stationCalendar.timeZone.identifier, "Pacific/Auckland")
  }

  @Test func dayAndTimePillsShowTheWeekdayDateAndTime() {
    let model = makeModel(initialTime: airtime)

    expectNoDifference(model.dayPillLabel, "Sun, Nov 22")
    expectNoDifference(model.timePillLabel, "7:00 PM")
  }

  @Test func dayPillSaysTodayForTheStationsCurrentDay() {
    let laterToday = airtime.addingTimeInterval(-3 * 3600)
    let model = makeModel(initialTime: laterToday, now: airtime.addingTimeInterval(-6 * 3600))

    expectNoDifference(model.dayPillLabel, "Today, Nov 22")
  }

  @Test func dayPillUsesTheStationsCalendarDayForToday() {
    let auckland = settings("Pacific/Auckland")
    let model = makeModel(
      settings: auckland, initialTime: airtime, now: airtime.addingTimeInterval(-3 * 3600))

    expectNoDifference(model.dayPillLabel, "Today, Nov 23")
  }

  @Test func slotListShowsAtMostThreeRowsAtRest() {
    let model = makeModel()

    expectNoDifference(model.slotListHeight, 3 * model.slotRowHeight)
    expectNoDifference(makeModel(series: series(isOneTime: true)).slotListHeight, 0)
  }

  @Test func airsAtLineLeavesOutTheEndWhenThereIsNoAudioYet() {
    let model = makeModel(episode: episode(durationMS: 0))

    expectNoDifference(model.airsAtLines, ["Airs at about 7:00 PM"])
  }

  @Test func titleAndSaveButtonDependOnWhetherTheShowIsAlreadyScheduled() {
    let scheduledAiring = CuratorAiring(
      id: "airing-1", episodeId: "episode-1", stationId: "station-1", airtime: airtime,
      startTime: nil, endTime: nil)
    let fresh = makeModel()
    let moving = makeModel(episode: episode(airings: [scheduledAiring]))

    expectNoDifference(fresh.navigationTitle, "Schedule Tour Stories")
    expectNoDifference(fresh.saveButtonTitle, "Schedule")
    expectNoDifference(moving.navigationTitle, "Change Time")
    expectNoDifference(moving.saveButtonTitle, "Save")
  }
}
