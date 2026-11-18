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
}
