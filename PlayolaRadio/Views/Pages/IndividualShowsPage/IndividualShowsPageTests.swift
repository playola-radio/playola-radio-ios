//
//  IndividualShowsPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

private struct IndividualShowsTestError: Error {}

@Suite(.freshSharedState)
@MainActor
struct IndividualShowsPageTests {

  // MARK: - Test Helpers

  private let stationId = "station-1"
  private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)
  private let thirtyMinutesMS = 30 * 60 * 1000

  private func makeSeries(
    id: String, title: String? = nil, isOneTime: Bool = false
  ) -> CuratorSeries {
    CuratorSeries(
      id: id, stationId: stationId, title: title ?? "Series \(id)", isOneTime: isOneTime,
      rrule: isOneTime ? nil : "FREQ=WEEKLY;BYDAY=TU;BYHOUR=20;BYMINUTE=0")
  }

  private func airing(
    id: String, episodeId: String, hoursFromNow: Double, lengthMS: Int? = nil
  ) -> CuratorAiring {
    let airtime = fixedNow.addingTimeInterval(hoursFromNow * 3600)
    return CuratorAiring(
      id: id, episodeId: episodeId, stationId: stationId, airtime: airtime,
      startTime: nil,
      endTime: airtime.addingTimeInterval(Double(lengthMS ?? thirtyMinutesMS) / 1000))
  }

  private func episode(
    id: String, seriesId: String = "one-time", title: String? = nil,
    durationMS: Int? = nil, airingHours: [Double] = []
  ) -> CuratorEpisode {
    CuratorEpisode(
      id: id, showId: seriesId, title: title ?? "Show \(id)",
      durationMS: durationMS ?? thirtyMinutesMS, show: nil, segments: [],
      airings: airingHours.enumerated().map { index, hours in
        airing(
          id: "\(id)-airing-\(index)", episodeId: id, hoursFromNow: hours,
          lengthMS: durationMS)
      })
  }

  private func settings(_ timezone: String = "America/Chicago") -> StationSchedulingSettings {
    StationSchedulingSettings(timezone: timezone, airingEditLockMS: 21_600_000)
  }

  private func makeModel(
    episodes: [CuratorEpisode] = [],
    series: [CuratorSeries] = [],
    settings: StationSchedulingSettings? = nil,
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) async -> IndividualShowsPageModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let resolvedSettings = settings ?? self.settings()
    return await withDependencies {
      $0.date.now = fixedNow
      $0.api.getCuratorEpisodes = { _, _, _ in episodes }
      $0.api.getCuratorSeries = { _, _ in series }
      $0.api.getStationSchedulingSettings = { _, _ in resolvedSettings }
      configure(&$0)
    } operation: {
      let model = IndividualShowsPageModel(stationId: stationId)
      await model.viewAppeared()
      return model
    }
  }

  // MARK: - Titles

  @Test func individualShowsPageTextComesFromTheModel() async {
    let model = await makeModel()

    expectNoDifference(model.navigationTitle, "Individual Shows")
    expectNoDifference(model.recordNewShowButtonTitle, "Record a New Show")
    expectNoDifference(model.emptyStateTitle, "No shows scheduled")
    expectNoDifference(
      model.emptyStateMessage, "Record a show and pick when it airs. It'll show up here.")
  }

  // MARK: - Fetching

  @Test func individualShowsFetchesNoAiringsAndAsksForEveryShowOfTheStation() async {
    let airingsRequested = LockIsolated(false)
    let requestedStations = LockIsolated<[String?]>([])
    let requestedSeriesFilters = LockIsolated<[String?]>([])
    let settingsStations = LockIsolated<[String]>([])

    _ = await makeModel {
      $0.api.getAirings = { _, _ in
        airingsRequested.setValue(true)
        return []
      }
      $0.api.getCuratorEpisodes = { _, stationId, showId in
        requestedStations.withValue { $0.append(stationId) }
        requestedSeriesFilters.withValue { $0.append(showId) }
        return []
      }
      $0.api.getStationSchedulingSettings = { [settings = settings()] _, stationId in
        settingsStations.withValue { $0.append(stationId) }
        return settings
      }
    }

    #expect(!airingsRequested.value)
    expectNoDifference(requestedStations.value, [stationId])
    expectNoDifference(requestedSeriesFilters.value, [nil])
    expectNoDifference(settingsStations.value, [stationId])
  }

  @Test func doesNothingWithoutAnAuthToken() async {
    @Shared(.auth) var auth = Auth()
    let fetched = LockIsolated(false)

    let model = withDependencies {
      $0.api.getCuratorEpisodes = { _, _, _ in
        fetched.setValue(true)
        return []
      }
    } operation: {
      IndividualShowsPageModel(stationId: stationId)
    }
    await model.viewAppeared()

    #expect(!fetched.value)
  }

  // MARK: - Listing

  @Test func individualShowsListsDraftsFirstThenByAirtime() async {
    let model = await makeModel(
      episodes: [
        episode(id: "later", airingHours: [48]),
        episode(id: "draft-b"),
        episode(id: "sooner", airingHours: [3]),
        episode(id: "draft-a"),
        episode(id: "middle", airingHours: [24]),
      ])

    expectNoDifference(
      model.rows.map(\.id), ["draft-b", "draft-a", "sooner", "middle", "later"])
  }

  @Test func showInSeriesCarriesSeriesBadge() async {
    let named = makeSeries(id: "named", title: "Kitchen Table Songs")
    let oneTime = makeSeries(id: "one-time", isOneTime: true)

    let model = await makeModel(
      episodes: [
        episode(id: "in-series", seriesId: "named", airingHours: [5]),
        episode(id: "draft-in-series", seriesId: "named"),
        episode(id: "one-off", seriesId: "one-time", airingHours: [6]),
      ],
      series: [named, oneTime])

    expectNoDifference(
      model.rows.map(\.seriesBadges),
      [["Kitchen Table Songs"], ["Kitchen Table Songs"], []])
  }

  @Test func airedShowsAreNotListed() async {
    let model = await makeModel(
      episodes: [
        episode(id: "aired", airingHours: [-48]),
        episode(id: "aired-twice", airingHours: [-72, -48]),
        episode(id: "upcoming", airingHours: [4]),
      ])

    expectNoDifference(model.rows.map(\.id), ["upcoming"])
  }

  @Test func showWithAnEndedAiringAndAFutureOneIsStillListedAtTheFutureTime() async {
    let model = await makeModel(
      episodes: [episode(id: "mixed", airingHours: [-48, 24])])

    expectNoDifference(model.rows.map(\.id), ["mixed"])
    expectNoDifference(
      model.rows.map(\.kind),
      [.scheduled(airtime: fixedNow.addingTimeInterval(24 * 3600), timeZone: model.timeZone)])
  }

  @Test func showOnAirRightNowIsStillListed() async {
    let model = await makeModel(
      episodes: [episode(id: "on-air", airingHours: [-0.25])])

    expectNoDifference(model.rows.map(\.id), ["on-air"])
  }

  @Test func listingAgreesWithUpcomingCounts() async {
    let regular = makeSeries(id: "regular")
    let oneTime = makeSeries(id: "one-time", isOneTime: true)
    let episodes = [
      episode(id: "in-series-with-two-airings", seriesId: "regular", airingHours: [24, 48]),
      episode(id: "in-series-draft", seriesId: "regular"),
      episode(id: "one-off-upcoming", airingHours: [5]),
      episode(id: "one-off-draft"),
      episode(id: "one-off-aired", airingHours: [-48]),
      episode(id: "ended-then-future", airingHours: [-48, 12]),
    ]
    let series = [regular, oneTime]

    let individual = await makeModel(episodes: episodes, series: series)
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let upcoming = await withDependencies {
      $0.date.now = fixedNow
      $0.api.getCuratorEpisodes = { _, _, _ in episodes }
      $0.api.getCuratorSeries = { _, _ in series }
    } operation: {
      let model = UpcomingShowsPageModel(stationId: stationId)
      await model.viewAppeared()
      return model
    }

    let drafts = individual.rows.filter { $0.kind == .draft }.count
    let comingUp = individual.rows.count - drafts
    expectNoDifference(
      upcoming.individualShowsCountLabel, "\(comingUp) shows coming up · \(drafts) not scheduled")
  }

  // MARK: - Row Text

  @Test func scheduledRowShowsDayTimeAndLengthInStationTime() async {
    let model = await makeModel(
      episodes: [
        episode(
          id: "a", title: "Back Porch Requests", durationMS: 42 * 60_000, airingHours: [10])
      ])

    expectNoDifference(model.rows.map(\.title), ["Back Porch Requests"])
    expectNoDifference(model.rows.map(\.subtitle), ["Friday · 12:00 PM · 42 min"])
  }

  @Test func draftRowSaysNotScheduledYetWithItsLength() async {
    let model = await makeModel(
      episodes: [
        episode(id: "with-audio", durationMS: 18 * 60_000),
        episode(id: "no-audio", durationMS: 0),
      ])

    expectNoDifference(
      model.rows.map(\.subtitle), ["Not scheduled yet · 18 min", "Not scheduled yet"])
    expectNoDifference(model.rows.map(\.kind), [.draft, .draft])
  }

  // MARK: - Station Time Zone

  @Test func rowsUseStationTimeZoneNotDeviceTimeZone() async {
    let airing = CuratorAiring(
      id: "a-1", episodeId: "a", stationId: stationId,
      airtime: Date(timeIntervalSince1970: 1_800_000_000 + 12 * 3600),
      startTime: nil, endTime: nil)
    let shown = CuratorEpisode(
      id: "a", showId: "one-time", title: "Holiday Hangout", durationMS: 25 * 60_000,
      show: nil, segments: [], airings: [airing])

    let chicago = await makeModel(episodes: [shown], settings: settings("America/Chicago"))
    let auckland = await makeModel(episodes: [shown], settings: settings("Pacific/Auckland"))

    expectNoDifference(chicago.rows.map(\.subtitle), ["Friday · 2:00 PM · 25 min"])
    expectNoDifference(auckland.rows.map(\.subtitle), ["Saturday · 9:00 AM · 25 min"])
    expectNoDifference(
      chicago.rows.map(\.kind),
      [.scheduled(airtime: airing.airtime, timeZone: TimeZone(identifier: "America/Chicago")!)])
    expectNoDifference(
      auckland.rows.map(\.kind),
      [.scheduled(airtime: airing.airtime, timeZone: TimeZone(identifier: "Pacific/Auckland")!)])
  }

  // MARK: - Empty State

  @Test func emptyStateShowsOnlyAfterALoadFindsNothing() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let model = withDependencies {
      $0.api.getCuratorEpisodes = { _, _, _ in [] }
      $0.api.getCuratorSeries = { _, _ in [] }
      $0.api.getStationSchedulingSettings = { [settings = settings()] _, _ in settings }
    } operation: {
      IndividualShowsPageModel(stationId: stationId)
    }
    expectNoDifference(model.emptyStateOpacity, 0)

    await model.viewAppeared()

    expectNoDifference(model.emptyStateOpacity, 1)
  }

  @Test func emptyStateHidesWhenThereAreShows() async {
    let model = await makeModel(episodes: [episode(id: "a", airingHours: [3])])

    expectNoDifference(model.emptyStateOpacity, 0)
  }

  @Test func onlyAiredShowsLeaveTheListEmpty() async {
    let model = await makeModel(episodes: [episode(id: "aired", airingHours: [-48])])

    expectNoDifference(model.rows, [])
    expectNoDifference(model.emptyStateOpacity, 1)
  }

  // MARK: - Failed Loads

  @Test func failedLoadShowsToastAndKeepsList() async {
    let shownToasts = LockIsolated<[PlayolaToast]>([])
    let reports = LockIsolated(0)
    let shouldFail = LockIsolated(false)
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let comingUp = episode(id: "a", airingHours: [24])

    let model = withDependencies {
      $0.date.now = fixedNow
      $0.api.getCuratorSeries = { _, _ in [] }
      $0.api.getStationSchedulingSettings = { [settings = settings()] _, _ in settings }
      $0.api.getCuratorEpisodes = { _, _, _ in
        if shouldFail.value { throw IndividualShowsTestError() }
        return [comingUp]
      }
      $0.toast.show = { toast in shownToasts.withValue { $0.append(toast) } }
      $0.errorReporting.reportError = { _, _ in reports.withValue { $0 += 1 } }
    } operation: {
      IndividualShowsPageModel(stationId: stationId)
    }
    await model.viewAppeared()
    shouldFail.setValue(true)
    await model.viewAppeared()

    expectNoDifference(model.rows.map(\.id), ["a"])
    expectNoDifference(shownToasts.value.map(\.message), ["Individual shows couldn't load."])
    expectNoDifference(shownToasts.value.map(\.buttonTitle), ["OK"])
    expectNoDifference(reports.value, 1)
    #expect(!model.isLoading)
  }

  @Test func failedSettingsLoadAppliesNoneOfTheResults() async {
    let model = await makeModel(episodes: [episode(id: "a", airingHours: [3])]) {
      $0.api.getStationSchedulingSettings = { _, _ in throw IndividualShowsTestError() }
      $0.toast.show = { _ in }
      $0.errorReporting.reportError = { _, _ in }
    }

    expectNoDifference(model.rows, [])
    expectNoDifference(model.emptyStateOpacity, 0)
  }

  // MARK: - Inert Actions

  @Test func rowAndRecordButtonDoNothingUntilTheBuilderExists() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = await makeModel(episodes: [episode(id: "a", airingHours: [3])])

    model.showRowTapped(model.rows[0])
    model.recordNewShowButtonTapped()

    #expect(coordinator.path.isEmpty)
  }
}
