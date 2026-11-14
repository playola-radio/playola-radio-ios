//
//  UnscheduleShowSheetTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct UnscheduleShowSheetTests {

  // MARK: - Test Helpers

  // Sunday, Nov 22 2026 at 7:00 PM in Chicago.
  private let airtime = Date(timeIntervalSince1970: 1_795_395_600)

  private var episode: CuratorEpisode {
    CuratorEpisode(
      id: "episode-1", showId: "series-1", title: "Tour Stories", durationMS: 1_115_000,
      show: nil, segments: [], airings: [])
  }

  private var airing: CuratorAiring {
    CuratorAiring(
      id: "airing-1", episodeId: "episode-1", stationId: "station-1", airtime: airtime,
      startTime: nil, endTime: nil)
  }

  private var weeklySeries: CuratorSeries {
    CuratorSeries(
      id: "series-1", stationId: "station-1", title: "This One\u{2019}s For You",
      isOneTime: false, rrule: "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0")
  }

  private func makeModel(
    series: CuratorSeries? = nil,
    timezone: String = "America/Chicago",
    unschedule: @escaping @MainActor () async throws -> Void = {}
  ) -> UnscheduleShowSheetModel {
    UnscheduleShowSheetModel(
      episode: episode, airing: airing, series: series ?? weeklySeries,
      settings: StationSchedulingSettings(timezone: timezone, airingEditLockMS: 21_600_000),
      unschedule: unschedule)
  }

  // MARK: - Tests

  @Test func unscheduleAsksFirst() {
    let calls = LockIsolated(0)
    let model = makeModel { calls.withValue { $0 += 1 } }

    expectNoDifference(model.title, "Unschedule Tour Stories?")
    expectNoDifference(
      model.subtitle,
      "It goes back to your drafts, and Sunday, Nov 22 at 7:00 PM opens up again in "
        + "This One\u{2019}s For You.")
    expectNoDifference(model.unscheduleButtonTitle, "Unschedule")
    expectNoDifference(model.keepScheduledButtonTitle, "Keep it scheduled")
    expectNoDifference(calls.value, 0)
  }

  @Test func subtitleLeavesOutTheSlotForAShowNotInASeries() {
    let oneTime = CuratorSeries(
      id: "series-2", stationId: "station-1", title: "Solo", isOneTime: true, rrule: nil)

    expectNoDifference(makeModel(series: oneTime).subtitle, "It goes back to your drafts.")
  }

  @Test func subtitleUsesStationTimeZone() {
    let model = makeModel(timezone: "Pacific/Auckland")

    #expect(model.subtitle.contains("Monday, Nov 23 at 2:00 PM"))
  }

  @Test func keepScheduledClosesWithoutUnscheduling() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let calls = LockIsolated(0)
    let model = makeModel { calls.withValue { $0 += 1 } }
    coordinator.presentedSheet = .unscheduleShow(model)

    model.keepScheduledTapped()

    #expect(coordinator.presentedSheet == nil)
    expectNoDifference(calls.value, 0)
  }

  @Test func unscheduleConfirmedRunsTheChangeAndClosesTheSheet() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let calls = LockIsolated(0)
    let model = makeModel { calls.withValue { $0 += 1 } }
    coordinator.presentedSheet = .unscheduleShow(model)

    await model.unscheduleConfirmed()

    expectNoDifference(calls.value, 1)
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func unscheduleInsideCutoffShowsServerMessage() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let message =
      "This show goes on the air in less than 2 minutes and can\u{2019}t be unscheduled."
    let model = makeModel { throw APIError.serverError(message) }
    coordinator.presentedSheet = .unscheduleShow(model)

    await model.unscheduleConfirmed()

    expectNoDifference(model.errorLines, [message])
    #expect(coordinator.presentedSheet == .unscheduleShow(model))
    #expect(!model.isSaving)
  }

  @Test func retryClearsThePreviousFailure() async {
    let attempts = LockIsolated(0)
    let model = makeModel {
      attempts.withValue { $0 += 1 }
      if attempts.value == 1 { throw APIError.serverError("Too late.") }
    }

    await model.unscheduleConfirmed()
    expectNoDifference(model.errorLines, ["Too late."])

    await model.unscheduleConfirmed()
    expectNoDifference(model.errorLines, [])
  }

  @Test func doubleTapOnlyUnschedulesOnce() async {
    await withMainSerialExecutor {
      let calls = LockIsolated(0)
      let (gate, openGate) = AsyncStream<Void>.makeStream()
      let model = makeModel {
        calls.withValue { $0 += 1 }
        for await _ in gate { break }
      }

      let first = Task { await model.unscheduleConfirmed() }
      await Task.megaYield()
      #expect(model.isSaving)
      await model.unscheduleConfirmed()
      openGate.yield()
      openGate.finish()
      await first.value

      expectNoDifference(calls.value, 1)
    }
  }

  @Test func cancelledUnscheduleShowsNothing() async {
    let model = makeModel { throw CancellationError() }

    await model.unscheduleConfirmed()

    expectNoDifference(model.errorLines, [])
  }
}
