//
//  SeriesDetailsSheetTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Sharing
import SwiftUI
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct SeriesDetailsSheetTests {

  // MARK: - Test Helpers

  private let stationId = "station-1"
  private let chicago = TimeZone(identifier: "America/Chicago")!

  private struct CreateRequest: Equatable {
    let stationId: String
    let title: String
    let rrule: String?
  }

  private func makeDetails(
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) -> SeriesDetailsSheetModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    return withDependencies {
      $0.notificationCenter = NotificationCenter()
      configure(&$0)
    } operation: {
      SeriesDetailsSheetModel(stationId: stationId, timeZone: chicago)
    }
  }

  nonisolated private func created(_ title: String, rrule: String?) -> CuratorSeries {
    CuratorSeries(
      id: "new-series", stationId: stationId, title: title, isOneTime: false, rrule: rrule)
  }

  // MARK: - Text

  @Test func matchesTheNewSeriesMockup() {
    let details = makeDetails()

    expectNoDifference(details.navigationTitle, "New Series")
    expectNoDifference(details.cancelButtonTitle, "Cancel")
    expectNoDifference(details.saveButtonTitle, "Save")
    expectNoDifference(details.namePlaceholder, "Series name")
    expectNoDifference(details.repeatOptions.map(\.title), ["Every week", "No schedule"])
    expectNoDifference(details.dayOptions.map(\.letter), ["S", "M", "T", "W", "T", "F", "S"])
    expectNoDifference(details.repeatOption, .everyWeek)
    expectNoDifference(details.scheduleSections.count, 1)
  }

  @Test func startsAtSevenPMInTheStationTimeZone() {
    let details = makeDetails()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = chicago

    let components = calendar.dateComponents([.hour, .minute], from: details.startTime)

    expectNoDifference(components.hour, 19)
    expectNoDifference(components.minute, 0)
  }

  @Test func settingTheStartTimeUsesStationWallClock() {
    let details = makeDetails()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = chicago
    let eightFifteen = calendar.date(
      bySettingHour: 20, minute: 15, second: 0, of: Date(timeIntervalSince1970: 1_800_000_000))!

    details.startTime = eightFifteen

    expectNoDifference(details.hour, 20)
    expectNoDifference(details.minute, 15)
  }

  @Test func halfPastTwoIsSelectableOnTheSpringForwardDay() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = chicago
    let details = makeDetails()
    details.hour = 2
    details.minute = 30

    let components = calendar.dateComponents([.hour, .minute], from: details.startTime)

    expectNoDifference(components.hour, 2)
    expectNoDifference(components.minute, 30)
  }

  // MARK: - Save Enabled

  @Test func saveIsDisabledWithoutAName() {
    let details = makeDetails()
    details.dayTapped(.tuesday)

    #expect(!details.isSaveEnabled)
    details.name = "   "
    #expect(!details.isSaveEnabled)
    details.name = "Tour Stories"
    #expect(details.isSaveEnabled)
  }

  @Test func everyWeekNeedsAtLeastOneDay() {
    let details = makeDetails()
    details.name = "Tour Stories"

    #expect(!details.isSaveEnabled)
    details.dayTapped(.monday)
    #expect(details.isSaveEnabled)
    details.dayTapped(.monday)
    #expect(!details.isSaveEnabled)
  }

  @Test func dayTappedTogglesTheDay() {
    let details = makeDetails()

    details.dayTapped(.tuesday)
    details.dayTapped(.thursday)

    expectNoDifference(details.selectedDays, [.tuesday, .thursday])
    expectNoDifference(
      details.dayOptions.filter { $0.accessibilityTraits == .isSelected }.map(\.accessibilityLabel),
      ["Tuesday", "Thursday"])
    expectNoDifference(
      details.dayOptions.map(\.fillColor),
      [
        .playolaSurfaceControl, .playolaSurfaceControl, .playolaRed, .playolaSurfaceControl,
        .playolaRed, .playolaSurfaceControl, .playolaSurfaceControl,
      ])

    details.dayTapped(.tuesday)
    expectNoDifference(details.selectedDays, [.thursday])
  }

  @Test func noScheduleHidesDaysAndTimeAndNeedsOnlyAName() {
    let details = makeDetails()
    details.name = "Tour Stories"

    details.repeatOption = .noSchedule

    expectNoDifference(details.scheduleSections, [])
    #expect(details.isSaveEnabled)
    #expect(details.rrule == nil)
  }

  // MARK: - Saving

  @Test func saveSendsATrimmedNameAndTheWeeklyRule() async {
    let requests = LockIsolated<[CreateRequest]>([])
    let saved = LockIsolated<[CuratorSeries]>([])
    let details = makeDetails {
      $0.api.createSeries = { _, stationId, title, rrule in
        requests.withValue {
          $0.append(CreateRequest(stationId: stationId, title: title, rrule: rrule))
        }
        return CuratorSeries(
          id: "new-series", stationId: stationId, title: title, isOneTime: false, rrule: rrule)
      }
    }
    details.onSaved = { series in saved.withValue { $0.append(series) } }
    details.name = "  Tour Stories "
    details.dayTapped(.thursday)
    details.dayTapped(.tuesday)
    details.hour = 20

    await details.saveButtonTapped()

    expectNoDifference(
      requests.value,
      [
        CreateRequest(
          stationId: stationId, title: "Tour Stories",
          rrule: "FREQ=WEEKLY;BYDAY=TU,TH;BYHOUR=20;BYMINUTE=0")
      ])
    expectNoDifference(saved.value.map(\.id), ["new-series"])
  }

  @Test func noScheduleSendsNoRule() async {
    let requests = LockIsolated<[CreateRequest]>([])
    let details = makeDetails {
      $0.api.createSeries = { [self] _, stationId, title, rrule in
        requests.withValue {
          $0.append(CreateRequest(stationId: stationId, title: title, rrule: rrule))
        }
        return created(title, rrule: rrule)
      }
    }
    details.name = "Tour Stories"
    details.repeatOption = .noSchedule

    await details.saveButtonTapped()

    expectNoDifference(
      requests.value, [CreateRequest(stationId: stationId, title: "Tour Stories", rrule: nil)])
  }

  @Test func savePostsRecordedShowsChanged() async {
    let notificationCenter = NotificationCenter()
    let posted = LockIsolated<[String]>([])
    let observer = notificationCenter.addObserver(
      forName: .recordedShowsChanged, object: nil, queue: nil
    ) { note in
      let stationId = note.userInfo?["stationId"] as? String ?? ""
      posted.withValue { $0.append(stationId) }
    }
    defer { notificationCenter.removeObserver(observer) }
    let details = makeDetails {
      $0.notificationCenter = notificationCenter
      $0.api.createSeries = { [self] _, _, title, rrule in created(title, rrule: rrule) }
    }
    details.name = "Tour Stories"
    details.repeatOption = .noSchedule

    await details.saveButtonTapped()

    expectNoDifference(posted.value, [stationId])
  }

  @Test func saveStaysBusyUntilTheJoinFinishesAndIgnoresASecondTap() async {
    await withMainSerialExecutor {
      let creates = LockIsolated(0)
      let (gate, open) = AsyncStream<Void>.makeStream()
      let details = makeDetails {
        $0.api.createSeries = { [self] _, _, title, rrule in
          creates.withValue { $0 += 1 }
          return created(title, rrule: rrule)
        }
      }
      details.onSaved = { _ in
        for await _ in gate { break }
      }
      details.name = "Tour Stories"
      details.repeatOption = .noSchedule

      let save = Task { await details.saveButtonTapped() }
      await Task.megaYield()

      #expect(details.isSaving)
      #expect(details.isInteractiveDismissDisabled)
      expectNoDifference(details.saveTitleOpacity, 0)
      expectNoDifference(details.savingSpinnerOpacity, 1)
      await details.saveButtonTapped()
      details.cancelButtonTapped()
      expectNoDifference(creates.value, 1)

      open.yield()
      open.finish()
      await save.value
      expectNoDifference(creates.value, 1)
    }
  }

  @Test func cancelMakesNoRequest() {
    let cancels = LockIsolated(0)
    let details = makeDetails()
    details.onCancel = { cancels.withValue { $0 += 1 } }
    details.name = "Tour Stories"

    details.cancelButtonTapped()

    expectNoDifference(cancels.value, 1)
  }

  @Test func failedSaveKeepsTheInputAndShowsTheServerMessage() async {
    let saved = LockIsolated(0)
    let details = makeDetails {
      $0.api.createSeries = { _, _, _, _ in throw APIError.serverError("Name is taken") }
      $0.errorReporting.reportError = { _, _ in }
    }
    details.onSaved = { _ in saved.withValue { $0 += 1 } }
    details.name = "Tour Stories"
    details.dayTapped(.tuesday)

    await details.saveButtonTapped()

    #expect(!details.isSaving)
    expectNoDifference(details.presentedAlert?.message, "Name is taken")
    expectNoDifference(details.name, "Tour Stories")
    expectNoDifference(details.selectedDays, [.tuesday])
    expectNoDifference(saved.value, 0)
    #expect(details.isSaveEnabled)
  }

  @Test func retryAfterAFailureSaves() async {
    let attempts = LockIsolated(0)
    let saved = LockIsolated<[String]>([])
    let details = makeDetails {
      $0.api.createSeries = { [self] _, _, title, rrule in
        let attempt = attempts.withValue {
          $0 += 1
          return $0
        }
        guard attempt > 1 else { throw APIError.serverError("Try again") }
        return created(title, rrule: rrule)
      }
      $0.errorReporting.reportError = { _, _ in }
    }
    details.onSaved = { series in saved.withValue { $0.append(series.id) } }
    details.name = "Tour Stories"
    details.repeatOption = .noSchedule

    await details.saveButtonTapped()
    details.presentedAlert = nil
    await details.saveButtonTapped()

    expectNoDifference(attempts.value, 2)
    expectNoDifference(saved.value, ["new-series"])
  }

  @Test func cancelledSaveShowsNoAlert() async {
    let reports = LockIsolated(0)
    let details = makeDetails {
      $0.api.createSeries = { _, _, _, _ in throw CancellationError() }
      $0.errorReporting.reportError = { _, _ in reports.withValue { $0 += 1 } }
    }
    details.name = "Tour Stories"
    details.repeatOption = .noSchedule

    await details.saveButtonTapped()

    #expect(details.presentedAlert == nil)
    expectNoDifference(reports.value, 0)
    #expect(!details.isSaving)
  }
  // MARK: - Edit Series

  private struct UpdateRequest: Equatable {
    let showId: String
    let title: String
    let rrule: String??
  }

  nonisolated private func series(rrule: String?) -> CuratorSeries {
    CuratorSeries(
      id: "series-1", stationId: stationId, title: "This One\u{2019}s For You", isOneTime: false,
      rrule: rrule)
  }

  private func makeEditDetails(
    rrule: String?, _ configure: (inout DependencyValues) -> Void = { _ in }
  ) -> SeriesDetailsSheetModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    return withDependencies {
      $0.notificationCenter = NotificationCenter()
      configure(&$0)
    } operation: {
      SeriesDetailsSheetModel(
        stationId: stationId, timeZone: chicago, editing: series(rrule: rrule))
    }
  }

  @Test func editOpensAWeeklyScheduleFilledIn() {
    let details = makeEditDetails(rrule: "FREQ=WEEKLY;BYDAY=TU,TH;BYHOUR=20;BYMINUTE=0")

    expectNoDifference(details.navigationTitle, "Edit Series")
    expectNoDifference(details.name, "This One\u{2019}s For You")
    expectNoDifference(details.repeatOption, .everyWeek)
    expectNoDifference(details.selectedDays, [.tuesday, .thursday])
    expectNoDifference(details.hour, 20)
    expectNoDifference(details.minute, 0)
    expectNoDifference(details.repeatsSections, ["repeats"])
    expectNoDifference(details.scheduleSections.count, 1)
    expectNoDifference(details.customScheduleRows, [])
    expectNoDifference(
      details.notes,
      [
        "Changing the schedule only changes your open slots. Shows that are already scheduled "
          + "keep their times."
      ])
  }

  @Test func editOpensNoScheduleForANilRule() {
    let details = makeEditDetails(rrule: nil)

    expectNoDifference(details.repeatOption, .noSchedule)
    expectNoDifference(details.selectedDays, [])
    expectNoDifference(details.hour, 19)
    expectNoDifference(details.minute, 0)
    expectNoDifference(details.scheduleSections, [])
    expectNoDifference(details.repeatsSections, ["repeats"])
  }

  @Test func editOpensCustomScheduleForAnUnreadableRule() {
    let details = makeEditDetails(rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=SU;BYHOUR=19;BYMINUTE=0")

    expectNoDifference(details.name, "This One\u{2019}s For You")
    expectNoDifference(details.repeatsSections, [])
    expectNoDifference(details.scheduleSections, [])
    expectNoDifference(details.scheduleHeader, "SCHEDULE")
    expectNoDifference(details.customScheduleRows, ["Custom schedule"])
    expectNoDifference(details.notes, [])
    #expect(details.isSaveEnabled)
  }

  @Test func newSeriesKeepsItsNote() {
    let details = makeDetails()

    expectNoDifference(details.repeatsSections, ["repeats"])
    expectNoDifference(details.customScheduleRows, [])
    expectNoDifference(details.notes, [details.note])
  }

  @Test func editSaveIsDisabledForAnEmptyNameOrNoDay() {
    let details = makeEditDetails(rrule: "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0")
    #expect(details.isSaveEnabled)

    details.name = "  "
    #expect(!details.isSaveEnabled)
    details.name = "Renamed"
    details.dayTapped(.sunday)
    #expect(!details.isSaveEnabled)
    details.repeatOptionTapped(.noSchedule)
    #expect(details.isSaveEnabled)
  }

  @Test func customScheduleSaveIsDisabledOnlyForAnEmptyName() {
    let details = makeEditDetails(rrule: "FREQ=DAILY")

    details.name = ""
    #expect(!details.isSaveEnabled)
    details.name = "Renamed"
    #expect(details.isSaveEnabled)
  }

  @Test(
    arguments: [
      (
        "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0", SeriesRepeatOption.everyWeek,
        String??.some("FREQ=WEEKLY;BYDAY=TU,SU;BYHOUR=19;BYMINUTE=0")
      ),
      ("FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0", .noSchedule, String??.some(nil)),
      ("FREQ=DAILY", .everyWeek, String??.none),
    ])
  func editSaveSendsTheScheduleChange(
    rule: String, option: SeriesRepeatOption, expected: String??
  ) async {
    let requests = LockIsolated<[UpdateRequest]>([])
    let details = makeEditDetails(rrule: rule) {
      $0.api.updateSeries = { [self] _, showId, title, rrule in
        requests.withValue { $0.append(UpdateRequest(showId: showId, title: title, rrule: rrule)) }
        return series(rrule: rrule ?? rule)
      }
      $0.api.createSeries = { _, _, _, _ in
        Issue.record("Edit must not create a Series")
        throw APIError.dataNotValid
      }
    }
    details.name = "  Renamed  "
    details.repeatOptionTapped(option)
    details.dayTapped(.tuesday)

    await details.saveButtonTapped()

    expectNoDifference(
      requests.value, [UpdateRequest(showId: "series-1", title: "Renamed", rrule: expected)])
  }

  @Test func editSaveStaysBusyUntilUpdateReturnsAndIgnoresASecondTap() async {
    await withMainSerialExecutor {
      let updates = LockIsolated(0)
      let (gate, open) = AsyncStream<Void>.makeStream()
      let details = makeEditDetails(rrule: nil) {
        $0.api.updateSeries = { [self] _, _, _, _ in
          updates.withValue { $0 += 1 }
          for await _ in gate { break }
          return series(rrule: nil)
        }
      }

      let save = Task { await details.saveButtonTapped() }
      await Task.megaYield()

      #expect(details.isSaving)
      #expect(details.isInteractiveDismissDisabled)
      #expect(!details.isSaveEnabled)
      expectNoDifference(details.saveTitleOpacity, 0)
      expectNoDifference(details.savingSpinnerOpacity, 1)
      await details.saveButtonTapped()
      details.repeatOptionTapped(.everyWeek)
      expectNoDifference(details.repeatOption, .noSchedule)
      expectNoDifference(updates.value, 1)

      open.yield()
      open.finish()
      await save.value
      expectNoDifference(updates.value, 1)
    }
  }

  @Test func editFailureKeepsTheSheetAndInputAndShowsTheServerMessage() async {
    let saved = LockIsolated(0)
    let details = makeEditDetails(rrule: "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0") {
      $0.api.updateSeries = { _, _, _, _ in throw APIError.serverError("Name is taken") }
      $0.errorReporting.reportError = { _, _ in }
    }
    details.onSaved = { _ in saved.withValue { $0 += 1 } }
    details.name = "Renamed"

    await details.saveButtonTapped()

    #expect(!details.isSaving)
    expectNoDifference(details.presentedAlert?.message, "Name is taken")
    expectNoDifference(details.name, "Renamed")
    expectNoDifference(details.selectedDays, [.sunday])
    expectNoDifference(saved.value, 0)
  }

  @Test func editSuccessPostsRecordedShowsChangedAndCloses() async {
    let notificationCenter = NotificationCenter()
    let posted = LockIsolated<[String]>([])
    let observer = notificationCenter.addObserver(
      forName: .recordedShowsChanged, object: nil, queue: nil
    ) { note in
      posted.withValue { $0.append(note.userInfo?["stationId"] as? String ?? "") }
    }
    defer { notificationCenter.removeObserver(observer) }
    let saved = LockIsolated<[String]>([])
    let details = makeEditDetails(rrule: nil) {
      $0.notificationCenter = notificationCenter
      $0.api.updateSeries = { [self] _, _, title, _ in
        CuratorSeries(
          id: "series-1", stationId: stationId, title: title, isOneTime: false, rrule: nil)
      }
    }
    details.onSaved = { series in saved.withValue { $0.append(series.title) } }
    details.name = "Renamed"

    await details.saveButtonTapped()

    expectNoDifference(posted.value, [stationId])
    expectNoDifference(saved.value, ["Renamed"])
  }

  @Test func editCancelSendsNothing() {
    let cancels = LockIsolated(0)
    let details = makeEditDetails(rrule: nil) {
      $0.api.updateSeries = { _, _, _, _ in
        Issue.record("Cancel must not save")
        throw APIError.dataNotValid
      }
    }
    details.onCancel = { cancels.withValue { $0 += 1 } }
    details.name = "Renamed"

    details.cancelButtonTapped()

    expectNoDifference(cancels.value, 1)
  }
}
