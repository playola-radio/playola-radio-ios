//
//  SeriesPickerSheetTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

private struct SeriesPickerTestError: Error {}

@Suite(.freshSharedState)
@MainActor
struct SeriesPickerSheetTests {

  // MARK: - Test Helpers

  private let stationId = "station-1"

  nonisolated private func series(
    _ id: String, _ title: String, isOneTime: Bool = false, rrule: String? = nil
  ) -> CuratorSeries {
    CuratorSeries(id: id, stationId: stationId, title: title, isOneTime: isOneTime, rrule: rrule)
  }

  private var thisOnesForYou: CuratorSeries {
    series(
      "series-1", "This One\u{2019}s For You", rrule: "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0")
  }

  private var kitchenTableSongs: CuratorSeries {
    series(
      "series-2", "Kitchen Table Songs", rrule: "FREQ=WEEKLY;BYDAY=WE;BYHOUR=20;BYMINUTE=0")
  }

  private func makePicker(
    currentSeries: CuratorSeries? = nil,
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) -> SeriesPickerSheetModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    return withDependencies {
      $0.api.getCuratorSeries = { [thisOnesForYou, kitchenTableSongs] _, _ in
        [thisOnesForYou, kitchenTableSongs]
      }
      configure(&$0)
    } operation: {
      SeriesPickerSheetModel(
        stationId: stationId, showTitle: "Tour Stories", currentSeries: currentSeries,
        timeZone: TimeZone(identifier: "America/Chicago")!)
    }
  }

  // MARK: - Text

  @Test func standaloneShowMatchesAddToASeries() async {
    let picker = makePicker()
    await picker.viewAppeared()

    expectNoDifference(picker.title, "Add to a series")
    expectNoDifference(picker.subtitle, "Tour Stories will show up on the series page.")
    expectNoDifference(
      picker.rows.map(\.title), ["This One\u{2019}s For You", "Kitchen Table Songs"])
    expectNoDifference(picker.rows.map(\.accessoryIcon), ["chevron.right", "chevron.right"])
    expectNoDifference(picker.newSeriesRows.map(\.title), ["New Series"])
    expectNoDifference(
      picker.newSeriesRows.map(\.subtitle), ["Name it and choose when it repeats"])
    expectNoDifference(picker.removeButtons, [])
  }

  @Test func oneTimeWrapperCountsAsStandalone() async {
    let picker = makePicker(currentSeries: series("wrapper", "Tour Stories", isOneTime: true))
    await picker.viewAppeared()

    expectNoDifference(picker.title, "Add to a series")
    expectNoDifference(picker.removeButtons, [])
  }

  @Test func showInASeriesMatchesChangeSeries() async {
    let picker = makePicker(currentSeries: thisOnesForYou)
    await picker.viewAppeared()

    expectNoDifference(picker.title, "Series")
    expectNoDifference(
      picker.subtitle, "Changing the series doesn\u{2019}t change when Tour Stories airs.")
    expectNoDifference(picker.rows.map(\.accessoryIcon), ["checkmark", "chevron.right"])
    expectNoDifference(picker.removeButtons, ["Remove from This One\u{2019}s For You"])
  }

  @Test func oneTimeWrappersAreHiddenAndServerOrderIsKept() async {
    let picker = makePicker {
      $0.api.getCuratorSeries = { [self] _, _ in
        [
          series("z", "Zebra Hour"),
          series("wrapper", "Some Show", isOneTime: true),
          series("a", "Appalachian Mornings"),
        ]
      }
    }
    await picker.viewAppeared()

    expectNoDifference(picker.rows.map(\.id), ["z", "a"])
  }

  @Test func rowSubtitlesDescribeTheSchedule() async {
    let picker = makePicker {
      $0.api.getCuratorSeries = { [self] _, _ in
        [
          series("weekly", "Weekly", rrule: "FREQ=WEEKLY;BYDAY=TU,TH;BYHOUR=20;BYMINUTE=0"),
          series("none", "None", rrule: nil),
          series("custom", "Custom", rrule: "FREQ=DAILY;BYHOUR=20"),
        ]
      }
    }
    await picker.viewAppeared()

    expectNoDifference(
      picker.rows.map(\.subtitle),
      ["Every Tuesday and Thursday at 8pm", "No schedule", "Custom schedule"])
  }

  @Test func stationWithNoSeriesShowsOnlyNewSeries() async {
    let picker = makePicker { $0.api.getCuratorSeries = { _, _ in [] } }
    await picker.viewAppeared()

    expectNoDifference(picker.rows.map(\.id), [])
    expectNoDifference(picker.newSeriesRows.map(\.title), ["New Series"])
    expectNoDifference(picker.removeButtons, [])
  }

  // MARK: - Loading

  @Test func showsAProgressViewWhileLoading() async {
    await withMainSerialExecutor {
      let (gate, open) = AsyncStream<Void>.makeStream()
      let picker = makePicker(currentSeries: thisOnesForYou) {
        $0.api.getCuratorSeries = { [thisOnesForYou] _, _ in
          for await _ in gate { break }
          return [thisOnesForYou]
        }
      }

      let load = Task { await picker.viewAppeared() }
      await Task.megaYield()

      expectNoDifference(picker.title, "Series")
      expectNoDifference(picker.loadingSpinners.count, 1)
      expectNoDifference(picker.rows.map(\.id), [])
      expectNoDifference(picker.newSeriesRows.count, 0)
      expectNoDifference(picker.removeButtons, [])

      open.yield()
      open.finish()
      await load.value

      expectNoDifference(picker.loadingSpinners.count, 0)
      expectNoDifference(picker.rows.map(\.id), ["series-1"])
      expectNoDifference(picker.newSeriesRows.count, 1)
    }
  }

  @Test func failedLoadShowsAToastAndStillOffersNewSeriesAndRemove() async {
    let toasts = LockIsolated<[String]>([])
    let picker = makePicker(currentSeries: thisOnesForYou) {
      $0.api.getCuratorSeries = { _, _ in throw APIError.serverError("Nope") }
      $0.errorReporting.reportError = { _, _ in }
      $0.toast.show = { toast in toasts.withValue { $0.append(toast.message) } }
    }

    await picker.viewAppeared()

    expectNoDifference(toasts.value, ["The series couldn\u{2019}t load."])
    expectNoDifference(picker.loadingSpinners.count, 0)
    expectNoDifference(picker.rows.map(\.id), [])
    expectNoDifference(picker.newSeriesRows.map(\.title), ["New Series"])
    expectNoDifference(picker.removeButtons, ["Remove from This One\u{2019}s For You"])
  }

  @Test func failedLoadOnAStandaloneShowOffersOnlyNewSeries() async {
    let picker = makePicker {
      $0.api.getCuratorSeries = { _, _ in throw APIError.serverError("Nope") }
      $0.errorReporting.reportError = { _, _ in }
      $0.toast.show = { _ in }
    }

    await picker.viewAppeared()

    expectNoDifference(picker.newSeriesRows.map(\.title), ["New Series"])
    expectNoDifference(picker.removeButtons, [])
  }

  @Test func reopeningLoadsAgain() async {
    let loads = LockIsolated(0)
    let configure: (inout DependencyValues) -> Void = {
      $0.api.getCuratorSeries = { _, _ in
        loads.withValue { $0 += 1 }
        return []
      }
    }

    await makePicker(configure).viewAppeared()
    await makePicker(configure).viewAppeared()

    expectNoDifference(loads.value, 2)
  }

  @Test func cancelledLoadShowsNoToast() async {
    let toasts = LockIsolated(0)
    let reports = LockIsolated(0)
    let picker = makePicker {
      $0.api.getCuratorSeries = { _, _ in throw CancellationError() }
      $0.errorReporting.reportError = { _, _ in reports.withValue { $0 += 1 } }
      $0.toast.show = { _ in toasts.withValue { $0 += 1 } }
    }

    await picker.viewAppeared()

    expectNoDifference(toasts.value, 0)
    expectNoDifference(reports.value, 0)
  }

  // MARK: - Choosing

  @Test func tappingASeriesDismissesThenSendsTheJoin() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let picker = makePicker()
    let sheetWhenSent = LockIsolated<PlayolaSheet?>(.none)
    let changes = LockIsolated<[SeriesChange]>([])
    picker.onSeriesChange = { [coordinator = $coordinator] change in
      let sheet = coordinator.wrappedValue.presentedSheet
      sheetWhenSent.setValue(sheet)
      changes.withValue { $0.append(change) }
    }
    coordinator.presentedSheet = .seriesPicker(picker)
    await picker.viewAppeared()

    await picker.seriesRowTapped("series-2")

    expectNoDifference(changes.value, [.join("series-2")])
    #expect(sheetWhenSent.value == nil)
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func tappingTheCheckedSeriesDismissesAndSendsNothing() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let picker = makePicker(currentSeries: thisOnesForYou)
    let changes = LockIsolated<[SeriesChange]>([])
    picker.onSeriesChange = { change in changes.withValue { $0.append(change) } }
    coordinator.presentedSheet = .seriesPicker(picker)
    await picker.viewAppeared()

    await picker.seriesRowTapped("series-1")

    expectNoDifference(changes.value, [])
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func removeSendsMakeStandalone() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let picker = makePicker(currentSeries: thisOnesForYou)
    let changes = LockIsolated<[SeriesChange]>([])
    picker.onSeriesChange = { change in changes.withValue { $0.append(change) } }
    coordinator.presentedSheet = .seriesPicker(picker)
    await picker.viewAppeared()

    await picker.removeButtonTapped()

    expectNoDifference(changes.value, [.makeStandalone])
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func onlyTheFirstChoiceIsSent() async {
    let picker = makePicker()
    let changes = LockIsolated<[SeriesChange]>([])
    picker.onSeriesChange = { change in changes.withValue { $0.append(change) } }
    await picker.viewAppeared()

    await picker.seriesRowTapped("series-1")
    await picker.seriesRowTapped("series-2")

    expectNoDifference(changes.value, [.join("series-1")])
  }

  @Test func lateDismissalDoesNotCloseANewerSheet() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let picker = makePicker()
    picker.onSeriesChange = { _ in }
    let newer = makePicker()
    coordinator.presentedSheet = .seriesPicker(newer)

    await picker.seriesRowTapped("series-1")

    #expect(coordinator.presentedSheet == .seriesPicker(newer))
  }

  @Test func newSeriesOpensTheDetailsSheetAndCancelReturnsToThePicker() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let picker = makePicker()
    coordinator.presentedSheet = .seriesPicker(picker)
    await picker.viewAppeared()

    picker.newSeriesRowTapped()
    picker.seriesDetails?.cancelButtonTapped()

    #expect(picker.seriesDetails == nil)
    #expect(coordinator.presentedSheet == .seriesPicker(picker))
  }

  @Test func dismissedClosureRunsOnce() {
    let picker = makePicker()
    let count = LockIsolated(0)
    picker.onDismissed = { count.withValue { $0 += 1 } }

    picker.dismissed()
    picker.dismissed()

    expectNoDifference(count.value, 1)
  }
}
