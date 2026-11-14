//
//  UpcomingShowsPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

private struct UpcomingShowsTestError: Error {}

@Suite(.freshSharedState)
@MainActor
struct UpcomingShowsPageTests {

  // MARK: - Test Helpers

  private let stationId = "station-1"
  private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)
  private let thirtyMinutesMS = 30 * 60 * 1000

  private func makeSeries(id: String, isOneTime: Bool) -> CuratorSeries {
    CuratorSeries(
      id: id, stationId: stationId, title: "Series \(id)", isOneTime: isOneTime,
      rrule: isOneTime ? nil : "FREQ=WEEKLY;BYDAY=TU;BYHOUR=20;BYMINUTE=0")
  }

  private func airing(id: String, episodeId: String, hoursFromNow: Double) -> CuratorAiring {
    let airtime = fixedNow.addingTimeInterval(hoursFromNow * 3600)
    return CuratorAiring(
      id: id, episodeId: episodeId, stationId: stationId, airtime: airtime,
      startTime: nil, endTime: airtime.addingTimeInterval(Double(thirtyMinutesMS) / 1000))
  }

  private func episode(
    id: String, seriesId: String, airingHours: [Double] = []
  ) -> CuratorEpisode {
    CuratorEpisode(
      id: id, showId: seriesId, title: "Show \(id)", durationMS: thirtyMinutesMS, show: nil,
      segments: [],
      airings: airingHours.enumerated().map { index, hours in
        airing(id: "\(id)-airing-\(index)", episodeId: id, hoursFromNow: hours)
      })
  }

  private func makeModel(
    episodes: [CuratorEpisode] = [],
    series: [CuratorSeries] = [],
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) async -> UpcomingShowsPageModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    return await withDependencies {
      $0.date.now = fixedNow
      $0.api.getCuratorEpisodes = { _, _, _ in episodes }
      $0.api.getCuratorSeries = { _, _ in series }
      configure(&$0)
    } operation: {
      let model = UpcomingShowsPageModel(stationId: stationId)
      await model.viewAppeared()
      return model
    }
  }

  // MARK: - Titles

  @Test func upcomingShowsPageTitlesComeFromTheModel() async {
    let model = await makeModel()

    expectNoDifference(model.navigationTitle, "Upcoming")
    expectNoDifference(model.seriesRowTitle, "Series")
    expectNoDifference(model.individualShowsRowTitle, "Individual Shows")
  }

  // MARK: - Fetching

  @Test func upcomingFetchesNoAirings() async {
    let airingsRequested = LockIsolated(false)
    let requested = LockIsolated<[String?]>([])

    _ = await makeModel {
      $0.api.getAirings = { _, _ in
        airingsRequested.setValue(true)
        return []
      }
      $0.api.getCuratorEpisodes = { _, stationId, showId in
        requested.withValue { $0.append(stationId) }
        expectNoDifference(showId, nil)
        return []
      }
    }

    #expect(!airingsRequested.value)
    expectNoDifference(requested.value, [stationId])
  }

  @Test func upcomingDoesNothingWithoutAnAuthToken() async {
    @Shared(.auth) var auth = Auth()
    let fetched = LockIsolated(false)

    let model = withDependencies {
      $0.api.getCuratorEpisodes = { _, _, _ in
        fetched.setValue(true)
        return []
      }
    } operation: {
      UpcomingShowsPageModel(stationId: stationId)
    }
    await model.viewAppeared()

    #expect(!fetched.value)
  }

  // MARK: - Counts

  @Test func upcomingCountsShowsNotAirings() async {
    let regular = makeSeries(id: "regular", isOneTime: false)
    let otherRegular = makeSeries(id: "other-regular", isOneTime: false)
    let oneTime = makeSeries(id: "one-time", isOneTime: true)
    let episodes = [
      episode(id: "in-series-with-two-airings", seriesId: "regular", airingHours: [24, 48]),
      episode(id: "in-series-draft", seriesId: "other-regular"),
      episode(id: "one-off-upcoming", seriesId: "one-time", airingHours: [5]),
      episode(id: "one-off-draft", seriesId: "one-time"),
      episode(id: "one-off-aired", seriesId: "one-time", airingHours: [-48]),
    ]

    let model = await makeModel(episodes: episodes, series: [regular, otherRegular, oneTime])

    expectNoDifference(model.seriesCountLabel, "2 series · 1 show coming up")
    expectNoDifference(model.individualShowsCountLabel, "2 shows coming up · 2 not scheduled")
  }

  @Test func oneTimeSeriesAreNotCountedAsSeries() async {
    let model = await makeModel(
      series: [
        makeSeries(id: "one-time-a", isOneTime: true),
        makeSeries(id: "one-time-b", isOneTime: true),
        makeSeries(id: "regular", isOneTime: false),
      ])

    expectNoDifference(model.seriesCountLabel, "1 series · 0 shows coming up")
  }

  @Test func countLabelsMatchTheMockupWording() async {
    let regular = makeSeries(id: "regular", isOneTime: false)
    let oneTime = makeSeries(id: "one-time", isOneTime: true)
    let episodes = [
      episode(id: "a", seriesId: "regular", airingHours: [24]),
      episode(id: "b", seriesId: "regular", airingHours: [48]),
      episode(id: "c", seriesId: "regular", airingHours: [72]),
      episode(id: "d", seriesId: "one-time", airingHours: [10]),
      episode(id: "e", seriesId: "one-time", airingHours: [11]),
      episode(id: "f", seriesId: "one-time", airingHours: [12]),
      episode(id: "g", seriesId: "one-time"),
    ]
    let series = [
      regular, makeSeries(id: "regular-2", isOneTime: false),
      makeSeries(id: "regular-3", isOneTime: false), oneTime,
    ]

    let model = await makeModel(episodes: episodes, series: series)

    expectNoDifference(model.seriesCountLabel, "3 series · 3 shows coming up")
    expectNoDifference(model.individualShowsCountLabel, "6 shows coming up · 1 not scheduled")
  }

  @Test func countLabelsUseSingularForOne() async {
    let model = await makeModel(
      episodes: [episode(id: "a", seriesId: "one-time", airingHours: [3])],
      series: [makeSeries(id: "one-time", isOneTime: true)])

    expectNoDifference(model.individualShowsCountLabel, "1 show coming up")
  }

  @Test func countLabelsWhenNothingIsScheduled() async {
    let model = await makeModel()

    expectNoDifference(model.seriesCountLabel, "0 series · 0 shows coming up")
    expectNoDifference(model.individualShowsCountLabel, "0 shows coming up")
  }

  @Test func showWithAnEndedAiringAndAFutureOneStillCountsAsComingUp() async {
    let model = await makeModel(
      episodes: [episode(id: "a", seriesId: "one-time", airingHours: [-48, 24])],
      series: [makeSeries(id: "one-time", isOneTime: true)])

    expectNoDifference(model.individualShowsCountLabel, "1 show coming up")
  }

  // MARK: - Failed Loads

  @Test func failedLoadShowsToastAndKeepsWhatWasShown() async {
    let shownToasts = LockIsolated<[PlayolaToast]>([])
    let reports = LockIsolated(0)
    let shouldFail = LockIsolated(false)
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let regular = makeSeries(id: "regular", isOneTime: false)
    let comingUp = episode(id: "a", seriesId: "regular", airingHours: [24])

    let model = withDependencies {
      $0.date.now = fixedNow
      $0.api.getCuratorSeries = { _, _ in [regular] }
      $0.api.getCuratorEpisodes = { _, _, _ in
        if shouldFail.value { throw UpcomingShowsTestError() }
        return [comingUp]
      }
      $0.toast.show = { toast in shownToasts.withValue { $0.append(toast) } }
      $0.errorReporting.reportError = { _, _ in reports.withValue { $0 += 1 } }
    } operation: {
      UpcomingShowsPageModel(stationId: stationId)
    }
    await model.viewAppeared()
    shouldFail.setValue(true)
    await model.viewAppeared()

    expectNoDifference(model.seriesCountLabel, "1 series · 1 show coming up")
    expectNoDifference(shownToasts.value.map(\.message), ["Upcoming shows couldn't load."])
    expectNoDifference(shownToasts.value.map(\.buttonTitle), ["OK"])
    expectNoDifference(reports.value, 1)
    #expect(!model.isLoading)
  }

  @Test func failedSeriesLoadAppliesNeitherResult() async {
    let regular = makeSeries(id: "regular", isOneTime: false)
    let model = await makeModel(
      episodes: [episode(id: "a", seriesId: "regular", airingHours: [24])],
      series: [regular]
    ) {
      $0.api.getCuratorSeries = { _, _ in throw UpcomingShowsTestError() }
      $0.toast.show = { _ in }
      $0.errorReporting.reportError = { _, _ in }
    }

    expectNoDifference(model.seriesCountLabel, "0 series · 0 shows coming up")
    expectNoDifference(model.individualShowsCountLabel, "0 shows coming up")
  }

  // MARK: - Navigation

  @Test func seriesRowDoesNothingUntilItsPageExists() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = await makeModel()

    model.seriesRowTapped()

    #expect(coordinator.path.isEmpty)
  }

  @Test func individualShowsRowPushesIndividualShowsPage() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = await makeModel()

    model.individualShowsRowTapped()

    guard case .individualShowsPage(let pushedModel) = coordinator.path.last else {
      Issue.record("Expected an individualShowsPage to be pushed")
      return
    }
    expectNoDifference(pushedModel.stationId, stationId)
    expectNoDifference(coordinator.path.count, 1)
  }

  // MARK: - Recorded shows changes

  @Test func recordedShowsChangedReloadsCounts() async {
    let notificationCenter = NotificationCenter()
    let latest = LockIsolated<[CuratorEpisode]>([])
    let reloaded = AsyncStream<Void>.makeStream()
    let model = await makeModel {
      $0.notificationCenter = notificationCenter
      $0.api.getCuratorEpisodes = { _, _, _ in
        defer { reloaded.continuation.yield() }
        return latest.value
      }
    }
    var reloadIterator = reloaded.stream.makeAsyncIterator()
    await reloadIterator.next()
    let observerReady = AsyncStream<Void>.makeStream()
    let observer = Task {
      await model.observeRecordedShowsChanges { observerReady.continuation.yield() }
    }
    var readyIterator = observerReady.stream.makeAsyncIterator()
    await readyIterator.next()

    let upcoming = episode(id: "e1", seriesId: "one-time", airingHours: [2])
    latest.setValue([upcoming])
    notificationCenter.post(
      name: .recordedShowsChanged, object: nil, userInfo: ["stationId": stationId])
    await reloadIterator.next()
    await Task.megaYield()
    observer.cancel()
    await observer.value

    expectNoDifference(model.individualShowsCountLabel, "1 show coming up")
  }
}
