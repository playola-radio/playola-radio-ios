//
//  CuratorSeriesPageTests.swift
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

private struct CuratorSeriesPageTestError: Error {}

@Suite(.freshSharedState)
@MainActor
struct CuratorSeriesPageTests {

  // MARK: - Test Helpers

  private let stationId = "station-1"
  private let chicago = TimeZone(identifier: "America/Chicago")!
  private let sundaySeven = "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0"
  private let settings = StationSchedulingSettings(
    timezone: "America/Chicago", airingEditLockMS: 6 * 60 * 60 * 1000)

  /// Thursday, November 5, 2026, noon in Chicago.
  private var now: Date { stationTime(2026, 11, 5, 12) }

  private func stationTime(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = chicago
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  nonisolated private func series(_ title: String = "This One\u{2019}s For You", rrule: String?)
    -> CuratorSeries
  {
    CuratorSeries(id: "s1", stationId: stationId, title: title, isOneTime: false, rrule: rrule)
  }

  private func episode(
    _ id: String, seriesId: String = "s1", at airtimes: [Date] = [],
    durationMS: Int = 38 * 60_000
  ) -> CuratorEpisode {
    CuratorEpisode(
      id: id, showId: seriesId, title: "Show \(id)", durationMS: durationMS, show: nil,
      segments: [],
      airings: airtimes.enumerated().map { index, airtime in
        CuratorAiring(
          id: "\(id)-airing-\(index)", episodeId: id, stationId: stationId, airtime: airtime,
          startTime: airtime, endTime: airtime.addingTimeInterval(Double(durationMS) / 1000))
      })
  }

  private func stationAirings(_ episodes: [CuratorEpisode]) -> [Airing] {
    episodes.flatMap { episode in
      episode.airings.map { airing in
        Airing.mockWith(
          id: airing.id, episodeId: episode.id, stationId: stationId, airtime: airing.airtime,
          episode: .mockWith(id: episode.id, durationMS: episode.durationMS),
          startTime: .some(airing.startTime), endTime: .some(airing.endTime))
      }
    }
  }

  private func makeModel(
    tapped: CuratorSeries? = nil,
    loaded: CuratorSeries? = nil,
    episodes: [CuratorEpisode] = [],
    otherStationEpisodes: [CuratorEpisode] = [],
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) async -> CuratorSeriesPageModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let tappedSeries = tapped ?? series(rrule: sundaySeven)
    let loadedSeries = loaded ?? tappedSeries
    let airings = stationAirings(episodes + otherStationEpisodes)
    return await withDependencies {
      $0.date.now = now
      $0.api.getCuratorSeriesById = { _, _ in loadedSeries }
      $0.api.getCuratorEpisodes = { _, _, _ in episodes }
      $0.api.getAirings = { _, _ in airings }
      $0.api.getStationSchedulingSettings = { [settings] _, _ in settings }
      configure(&$0)
    } operation: {
      let model = CuratorSeriesPageModel(stationId: stationId, series: tappedSeries)
      await model.viewAppeared()
      return model
    }
  }

  // MARK: - Requests

  @Test func itIsBuiltFromTheSeriesAndItsShows() async {
    let requests = LockIsolated<[String]>([])
    let model = await makeModel(loaded: series("Renamed", rrule: nil)) {
      $0.api.getCuratorSeriesById = { [self] _, showId in
        requests.withValue { $0.append("series:\(showId)") }
        return series("Renamed", rrule: nil)
      }
      $0.api.getCuratorEpisodes = { _, stationId, showId in
        requests.withValue { $0.append("episodes:\(stationId ?? "nil"):\(showId ?? "nil")") }
        return []
      }
    }

    expectNoDifference(requests.value.sorted(), ["episodes:nil:s1", "series:s1"])
    expectNoDifference(model.navigationTitle, "Renamed")
  }

  @Test func theTitleShowsBeforeTheFirstLoad() {
    let model = CuratorSeriesPageModel(stationId: stationId, series: series(rrule: nil))

    expectNoDifference(model.navigationTitle, "This One\u{2019}s For You")
    expectNoDifference(model.editButtonTitle, "Edit")
    expectNoDifference(model.addShowButtonTitle, "Add a Show")
  }

  // MARK: - Content

  @Test func draftsAreListedUnderNotScheduledYet() async {
    let model = await makeModel(episodes: [
      episode("hymn-request-night", durationMS: 20 * 60_000),
      episode("no-audio", durationMS: 0),
    ])

    expectNoDifference(model.draftsHeader, "NOT SCHEDULED YET")
    expectNoDifference(
      model.draftRows.elements,
      [
        CuratorSeriesDraftRow(
          id: "hymn-request-night", title: "Show hymn-request-night",
          subtitle: "Not scheduled yet \u{00B7} 20 min"),
        CuratorSeriesDraftRow(
          id: "no-audio", title: "Show no-audio", subtitle: "Not scheduled yet"),
      ])
    expectNoDifference(model.draftsEmptyMessages, [])
  }

  @Test func upcomingMergesShowsAndTheNextEightOpenSlotsByDate() async {
    let model = await makeModel(episodes: [
      episode("old-hymns", at: [stationTime(2026, 11, 15, 19)], durationMS: 44 * 60_000),
      episode("fall-favorites", at: [stationTime(2026, 11, 8, 19)]),
      episode("aired", at: [stationTime(2026, 11, 1, 19)]),
    ])

    let rows = model.upcomingRows
    expectNoDifference(model.upcomingHeader, "UPCOMING")
    expectNoDifference(rows.count, 10)
    expectNoDifference(
      Array(rows.map(\.title).prefix(4)), ["Show fall-favorites", "Show old-hymns", "Open", "Open"])
    expectNoDifference(
      Array(rows.map(\.subtitle).prefix(3)),
      [
        "Sunday \u{00B7} 7:00 PM \u{00B7} 38 min", "Sunday \u{00B7} 7:00 PM \u{00B7} 44 min",
        "Sunday \u{00B7} 7:00 PM",
      ])
    expectNoDifference(rows.flatMap(\.slots).count, 8)
    expectNoDifference(rows.flatMap(\.slots).first?.addButtonTitle, "Add show")
    expectNoDifference(rows.map(\.date), rows.map(\.date).sorted())
    expectNoDifference(rows.last?.date, stationTime(2027, 1, 10, 19))
    expectNoDifference(model.upcomingEmptyMessages, [])
  }

  @Test func aShowThatAirsTwiceIsListedOnceAtItsNextAiring() async {
    let model = await makeModel(
      tapped: series(rrule: nil),
      episodes: [
        episode("twice", at: [stationTime(2026, 11, 1, 19), stationTime(2026, 11, 20, 19)])
      ])

    expectNoDifference(model.upcomingRows.map(\.id), ["show-twice"])
    expectNoDifference(model.upcomingRows.first?.date, stationTime(2026, 11, 20, 19))
    expectNoDifference(model.draftRows.count, 0)
  }

  @Test func emptySectionsShowTheirMessages() async {
    let model = await makeModel(tapped: series(rrule: "FREQ=DAILY"))

    expectNoDifference(model.draftRows.count, 0)
    expectNoDifference(model.draftsEmptyMessages, ["No drafts in this series."])
    expectNoDifference(model.upcomingRows.count, 0)
    expectNoDifference(model.upcomingEmptyMessages, ["No upcoming shows."])
    expectNoDifference(model.scheduleBadges, ["Custom schedule"])
  }

  @Test func aWeeklySeriesWhoseEveryTimeIsTakenHasNoSlots() async {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = chicago
    let firstSunday = stationTime(2026, 11, 8, 19)
    let allSundays = (0..<54).map { week in
      calendar.date(byAdding: .weekOfYear, value: week, to: firstSunday)!
    }
    let takenByAnotherSeries = allSundays.enumerated().map { index, airtime in
      Airing.mockWith(
        id: "other-\(index)", episodeId: "other-\(index)", stationId: stationId,
        airtime: airtime.addingTimeInterval(-1800),
        episode: .mockWith(id: "other-\(index)", durationMS: 60 * 60_000),
        startTime: .some(airtime.addingTimeInterval(-1800)),
        endTime: .some(airtime.addingTimeInterval(1800)))
    }
    let model = await makeModel {
      $0.api.getAirings = { _, _ in takenByAnotherSeries }
    }

    expectNoDifference(model.upcomingRows.count, 0)
    expectNoDifference(model.upcomingEmptyMessages, ["No upcoming shows."])
  }

  @Test func theSlotsNoteShowsOnlyForAReadableWeeklySchedule() async {
    let weekly = await makeModel(tapped: series(rrule: sundaySeven))
    let none = await makeModel(tapped: series(rrule: nil))
    let custom = await makeModel(tapped: series(rrule: "FREQ=DAILY"))

    expectNoDifference(
      weekly.slotsNotes,
      ["Open slots are only suggestions. If you leave one empty, your station plays as usual."])
    expectNoDifference(weekly.scheduleBadges, ["Every Sunday at 7pm"])
    expectNoDifference(none.slotsNotes, [])
    expectNoDifference(none.scheduleBadges, [])
    expectNoDifference(none.upcomingRows.count, 0)
    expectNoDifference(custom.slotsNotes, [])
  }

  // MARK: - Actions

  @Test func editPresentsEditModeWithTheSeries() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = await makeModel(loaded: series("Loaded Name", rrule: sundaySeven))

    model.editButtonTapped()

    guard case .seriesDetails(let details) = coordinator.presentedSheet else {
      Issue.record("Expected the Series details sheet")
      return
    }
    expectNoDifference(details.navigationTitle, "Edit Series")
    expectNoDifference(details.editedSeries, series("Loaded Name", rrule: sundaySeven))
    expectNoDifference(details.name, "Loaded Name")
    expectNoDifference(details.selectedDays, [.sunday])
    expectNoDifference(details.timeZone, chicago)

    details.cancelButtonTapped()
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func editOpensAfterAFailedFirstLoadWithTheTappedSeriesInCentralTime() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let tapped = series(rrule: nil)
    let model = await makeModel(tapped: tapped) {
      $0.api.getStationSchedulingSettings = { _, _ in throw CuratorSeriesPageTestError() }
      $0.toast.show = { _ in }
      $0.errorReporting.reportError = { _, _ in }
    }

    model.editButtonTapped()

    guard case .seriesDetails(let details) = coordinator.presentedSheet else {
      Issue.record("Expected the Series details sheet")
      return
    }
    #expect(model.settings == nil)
    expectNoDifference(details.editedSeries, tapped)
    expectNoDifference(details.timeZone, chicago)
  }

  @Test func savingAnEditClosesTheSheet() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = await makeModel {
      $0.notificationCenter = NotificationCenter()
      $0.api.updateSeries = { [self] _, _, title, _ in series(title, rrule: nil) }
    }
    model.editButtonTapped()
    guard case .seriesDetails(let details) = coordinator.presentedSheet else {
      Issue.record("Expected the Series details sheet")
      return
    }
    details.name = "Renamed"

    await details.saveButtonTapped()

    #expect(coordinator.presentedSheet == nil)
  }

  @Test func aShowInEitherSectionPushesItsBuilder() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = await makeModel(episodes: [
      episode("draft"), episode("scheduled", at: [stationTime(2026, 11, 8, 19)]),
    ])

    model.showTapped(model.draftRows[0].id)
    model.showTapped(model.upcomingRows.flatMap(\.shows)[0].episodeId)

    let pushed: [String?] = coordinator.path.map { path in
      guard case .showBuilderPage(let builder) = path else { return nil }
      return builder.episodeId
    }
    expectNoDifference(pushed, ["draft", "scheduled"])
  }

  // MARK: - Loading

  @Test func aGatedLoadShowsTheProgressView() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let (gate, open) = AsyncStream<Void>.makeStream()
      let model = withDependencies {
        $0.date.now = now
        $0.api.getCuratorSeriesById = { [self] _, _ in
          for await _ in gate { break }
          return series(rrule: nil)
        }
        $0.api.getCuratorEpisodes = { _, _, _ in [] }
        $0.api.getAirings = { _, _ in [] }
        $0.api.getStationSchedulingSettings = { [settings] _, _ in settings }
      } operation: {
        CuratorSeriesPageModel(stationId: stationId, series: series(rrule: nil))
      }

      let load = Task { await model.viewAppeared() }
      await Task.megaYield()

      #expect(model.isProgressVisible)
      expectNoDifference(model.loadingOpacity, 1)

      open.yield()
      open.finish()
      await load.value
      #expect(!model.isProgressVisible)
    }
  }

  @Test func aFailureShowsAToastAndKeepsWhatWasShown() async {
    let shouldFail = LockIsolated(false)
    let toasts = LockIsolated<[String]>([])
    let reports = LockIsolated(0)
    let model = await makeModel(episodes: [episode("draft")]) {
      $0.api.getAirings = { _, _ in
        if shouldFail.value { throw CuratorSeriesPageTestError() }
        return []
      }
      $0.toast.show = { toast in toasts.withValue { $0.append(toast.message) } }
      $0.errorReporting.reportError = { _, _ in reports.withValue { $0 += 1 } }
    }
    shouldFail.setValue(true)

    await model.viewAppeared()

    expectNoDifference(model.draftRows.map(\.id), ["draft"])
    expectNoDifference(toasts.value, ["This series couldn\u{2019}t load."])
    expectNoDifference(reports.value, 1)
    #expect(!model.isLoading)
  }

  @Test func aCancelledLoadShowsNoToast() async {
    let toasts = LockIsolated(0)
    _ = await makeModel {
      $0.api.getCuratorSeriesById = { _, _ in throw CancellationError() }
      $0.toast.show = { _ in toasts.withValue { $0 += 1 } }
    }

    expectNoDifference(toasts.value, 0)
  }

  @Test func recordedShowsChangedForThisStationReloadsAndForAnotherDoesNot() async {
    let notificationCenter = NotificationCenter()
    let loads = LockIsolated(0)
    let latestTitle = LockIsolated("Before")
    let reloaded = AsyncStream<Void>.makeStream()
    let model = await makeModel {
      $0.notificationCenter = notificationCenter
      $0.api.getCuratorSeriesById = { [self] _, _ in
        loads.withValue { $0 += 1 }
        defer { reloaded.continuation.yield() }
        return series(latestTitle.value, rrule: nil)
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

    latestTitle.setValue("After")
    notificationCenter.post(
      name: .recordedShowsChanged, object: nil, userInfo: ["stationId": "other-station"])
    notificationCenter.post(
      name: .recordedShowsChanged, object: nil, userInfo: ["stationId": stationId])
    await reloadIterator.next()
    await Task.megaYield()
    observer.cancel()
    await observer.value

    expectNoDifference(loads.value, 2)
    expectNoDifference(model.navigationTitle, "After")
  }
}
