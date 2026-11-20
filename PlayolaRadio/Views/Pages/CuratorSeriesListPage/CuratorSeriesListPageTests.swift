//
//  CuratorSeriesListPageTests.swift
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

private struct CuratorSeriesListTestError: Error {}

@Suite(.freshSharedState)
@MainActor
struct CuratorSeriesListPageTests {

  // MARK: - Test Helpers

  private let stationId = "station-1"
  private let chicago = TimeZone(identifier: "America/Chicago")!
  private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
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

  nonisolated private func series(_ id: String, rrule: String?, isOneTime: Bool = false)
    -> CuratorSeries
  {
    CuratorSeries(
      id: id, stationId: stationId, title: "Series \(id)", isOneTime: isOneTime, rrule: rrule)
  }

  private func episode(
    _ id: String, seriesId: String, at airtimes: [Date] = [], durationMS: Int = 38 * 60_000
  ) -> CuratorEpisode {
    CuratorEpisode(
      id: id, showId: seriesId, title: "Show \(id)", durationMS: durationMS, show: nil,
      segments: [],
      airings: airtimes.enumerated().map { index, airtime in
        CuratorAiring(
          id: "\(id)-airing-\(index)", episodeId: id, stationId: stationId, airtime: airtime,
          startTime: airtime,
          endTime: airtime.addingTimeInterval(Double(durationMS) / 1000))
      })
  }

  /// The station Airings for `episodes`, as `GET /v1/airings` returns them.
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
    series: [CuratorSeries] = [],
    episodes: [CuratorEpisode] = [],
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) async -> CuratorSeriesListPageModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let stationAirings = stationAirings(episodes)
    return await withDependencies {
      $0.date.now = now
      $0.api.getCuratorSeries = { _, _ in series }
      $0.api.getCuratorEpisodes = { _, _, _ in episodes }
      $0.api.getAirings = { _, _ in stationAirings }
      $0.api.getStationSchedulingSettings = { [settings] _, _ in settings }
      configure(&$0)
    } operation: {
      let model = CuratorSeriesListPageModel(stationId: stationId)
      await model.viewAppeared()
      return model
    }
  }

  private func subtitles(_ card: CuratorSeriesCard?) -> [String] {
    card?.items.map(\.subtitle) ?? []
  }

  // MARK: - Cards

  @Test func oneTimeWrappersAreHiddenAndServerOrderIsKept() async {
    let model = await makeModel(series: [
      series("b", rrule: nil), series("wrapper", rrule: nil, isOneTime: true),
      series("a", rrule: nil),
    ])

    expectNoDifference(model.navigationTitle, "Series")
    expectNoDifference(model.cards.map(\.id), ["b", "a"])
    expectNoDifference(model.cards.map(\.title), ["Series b", "Series a"])
    expectNoDifference(model.cards.first?.upcomingHeader, "UPCOMING SHOWS")
  }

  @Test func aStationWithNoSeriesShowsNoCards() async {
    let model = await makeModel(series: [series("wrapper", rrule: nil, isOneTime: true)])

    expectNoDifference(model.cards.count, 0)
    expectNoDifference(model.createButtonTitle, "Create a New Series")
  }

  @Test func aCardMergesShowsAndSlotsByDateAndKeepsTheFirstThree() async {
    let episodes = [
      episode("old-hymns", seriesId: "s1", at: [stationTime(2026, 11, 15, 19)]),
      episode("fall-favorites", seriesId: "s1", at: [stationTime(2026, 11, 8, 19)]),
      episode("later", seriesId: "s1", at: [stationTime(2026, 12, 6, 19)]),
    ]
    let model = await makeModel(series: [series("s1", rrule: sundaySeven)], episodes: episodes)

    let card = model.cards.first
    expectNoDifference(card?.badges, ["Every Sunday at 7pm"])
    expectNoDifference(card?.countLabels, ["2 shows \u{00B7} 1 open"])
    expectNoDifference(
      subtitles(card),
      ["Sunday the 8th at 7pm", "Sunday the 15th at 7pm", "Sunday the 22nd \u{00B7} open"])
    expectNoDifference(
      card?.items.flatMap(\.shows).map(\.title), ["Show fall-favorites", "Show old-hymns"])
    expectNoDifference(card?.items.flatMap(\.slots).map(\.addButtonTitle), ["Add show"])
    expectNoDifference(card?.emptyMessages, [])
  }

  @Test func countReadsOneShow() async {
    let model = await makeModel(
      series: [series("s1", rrule: "FREQ=DAILY")],
      episodes: [episode("e1", seriesId: "s1", at: [stationTime(2026, 11, 8, 19)])])

    expectNoDifference(model.cards.first?.countLabels, ["1 show"])
  }

  @Test func countReadsThreeOpen() async {
    let model = await makeModel(series: [series("s1", rrule: sundaySeven)])

    expectNoDifference(model.cards.first?.countLabels, ["3 open"])
    expectNoDifference(
      subtitles(model.cards.first),
      [
        "Sunday the 8th \u{00B7} open", "Sunday the 15th \u{00B7} open",
        "Sunday the 22nd \u{00B7} open",
      ])
  }

  @Test func aSeriesWithNothingUpcomingShowsTheMessageAndNoCount() async {
    let model = await makeModel(series: [series("s1", rrule: nil)])

    let card = model.cards.first
    expectNoDifference(card?.items.count, 0)
    expectNoDifference(card?.countLabels, [])
    expectNoDifference(card?.emptyMessages, ["No upcoming shows."])
  }

  @Test func aSlotOverlappingAnyStationAiringIsNotOpen() async {
    let otherSeriesShow = episode(
      "other", seriesId: "s2", at: [stationTime(2026, 11, 8, 18)], durationMS: 90 * 60_000)
    let model = await makeModel(
      series: [series("s1", rrule: sundaySeven), series("s2", rrule: nil)],
      episodes: [otherSeriesShow])

    expectNoDifference(
      subtitles(model.cards.first),
      [
        "Sunday the 15th \u{00B7} open", "Sunday the 22nd \u{00B7} open",
        "Sunday the 29th \u{00B7} open",
      ])
  }

  @Test func aShowWithTwoFutureAiringsAppearsOnceAtTheEarlierOne() async {
    let twice = episode(
      "twice", seriesId: "s1", at: [stationTime(2026, 11, 20, 19), stationTime(2026, 11, 6, 19)])
    let model = await makeModel(series: [series("s1", rrule: nil)], episodes: [twice])

    expectNoDifference(subtitles(model.cards.first), ["Friday the 6th at 7pm"])
  }

  @Test func airedShowsAndDraftsAreNotOnCards() async {
    let aired = episode("aired", seriesId: "s1", at: [stationTime(2026, 11, 1, 19)])
    let draft = episode("draft", seriesId: "s1")
    let model = await makeModel(series: [series("s1", rrule: nil)], episodes: [aired, draft])

    expectNoDifference(model.cards.first?.items.count, 0)
    expectNoDifference(model.cards.first?.emptyMessages, ["No upcoming shows."])
  }

  @Test func aNilRuleHasNoBadgeOrSlotsAndAnUnreadableOneShowsCustomSchedule() async {
    let model = await makeModel(series: [
      series("none", rrule: nil),
      series("custom", rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=SU;BYHOUR=19;BYMINUTE=0"),
    ])

    expectNoDifference(model.cards[id: "none"]?.badges, [])
    expectNoDifference(model.cards[id: "none"]?.items.count, 0)
    expectNoDifference(model.cards[id: "custom"]?.badges, ["Custom schedule"])
    expectNoDifference(model.cards[id: "custom"]?.items.count, 0)
  }

  // MARK: - Time

  @Test func cardTextsAndSlotsAreInCentralTimeWhateverThePhonesTimeZone() async {
    let show = episode("e1", seriesId: "s1", at: [stationTime(2026, 11, 8, 19)])
    let model = await makeModel(series: [series("s1", rrule: sundaySeven)], episodes: [show]) {
      $0.timeZone = tokyo
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = tokyo
      $0.calendar = calendar
    }

    expectNoDifference(
      subtitles(model.cards.first),
      ["Sunday the 8th at 7pm", "Sunday the 15th \u{00B7} open", "Sunday the 22nd \u{00B7} open"])
    expectNoDifference(
      model.cards.first?.items.map(\.date),
      [stationTime(2026, 11, 8, 19), stationTime(2026, 11, 15, 19), stationTime(2026, 11, 22, 19)])
    expectNoDifference(model.cards.first?.items.first?.timeZone, chicago)
  }

  @Test func sundaySevenSlotsCrossTheNovemberFallBack() async throws {
    let model = await makeModel(series: [series("s1", rrule: sundaySeven)]) {
      $0.date.now = Date(timeIntervalSince1970: 1_792_864_800)  // 2026-10-24T18:00:00Z
    }

    expectNoDifference(
      model.cards.first?.items.map(\.date),
      [
        try Date("2026-10-26T00:00:00Z", strategy: .iso8601),
        try Date("2026-11-02T01:00:00Z", strategy: .iso8601),
        try Date("2026-11-09T01:00:00Z", strategy: .iso8601),
      ])
    expectNoDifference(
      subtitles(model.cards.first),
      [
        "Sunday the 25th \u{00B7} open", "Sunday the 1st \u{00B7} open",
        "Sunday the 8th \u{00B7} open",
      ])
  }

  @Test func sundaySevenSlotsCrossTheMarchSpringForward() async throws {
    let model = await makeModel(series: [series("s1", rrule: sundaySeven)]) {
      $0.date.now = Date(timeIntervalSince1970: 1_804_356_000)  // 2027-03-06T18:00:00Z
    }

    expectNoDifference(
      model.cards.first?.items.map(\.date),
      [
        try Date("2027-03-08T01:00:00Z", strategy: .iso8601),
        try Date("2027-03-15T00:00:00Z", strategy: .iso8601),
        try Date("2027-03-22T00:00:00Z", strategy: .iso8601),
      ])
    expectNoDifference(
      subtitles(model.cards.first),
      [
        "Sunday the 7th \u{00B7} open", "Sunday the 14th \u{00B7} open",
        "Sunday the 21st \u{00B7} open",
      ])
  }

  // MARK: - Loading

  @Test func aGatedLoadShowsTheProgressView() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let (gate, open) = AsyncStream<Void>.makeStream()
      let model = withDependencies {
        $0.date.now = now
        $0.api.getCuratorSeries = { [self] _, _ in
          for await _ in gate { break }
          return [series("s1", rrule: nil)]
        }
        $0.api.getCuratorEpisodes = { _, _, _ in [] }
        $0.api.getAirings = { _, _ in [] }
        $0.api.getStationSchedulingSettings = { [settings] _, _ in settings }
      } operation: {
        CuratorSeriesListPageModel(stationId: stationId)
      }

      let load = Task { await model.viewAppeared() }
      await Task.megaYield()

      #expect(model.isProgressVisible)
      expectNoDifference(model.loadingOpacity, 1)

      open.yield()
      open.finish()
      await load.value
      #expect(!model.isProgressVisible)
      expectNoDifference(model.loadingOpacity, 0)
      expectNoDifference(model.cards.map(\.id), ["s1"])
    }
  }

  @Test func aLateOlderLoadDoesNotOverwriteANewerOne() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "test-jwt")
      let (gate, open) = AsyncStream<Void>.makeStream()
      let loads = LockIsolated(0)
      let airingsLoads = LockIsolated(0)
      let model = withDependencies {
        $0.date.now = now
        $0.api.getCuratorSeries = { [self] _, _ in
          let load = loads.withValue {
            $0 += 1
            return $0
          }
          return load == 1 ? [] : [series("new", rrule: nil)]
        }
        $0.api.getCuratorEpisodes = { _, _, _ in [] }
        $0.api.getAirings = { _, _ in
          if airingsLoads.withValue({
            $0 += 1
            return $0
          }) == 1 {
            for await _ in gate { break }
          }
          return []
        }
        $0.api.getStationSchedulingSettings = { [settings] _, _ in settings }
      } operation: {
        CuratorSeriesListPageModel(stationId: stationId)
      }

      let olderLoad = Task { await model.viewAppeared() }
      await Task.megaYield()
      await model.viewAppeared()
      open.yield()
      open.finish()
      await olderLoad.value

      expectNoDifference(model.cards.map(\.id), ["new"])
    }
  }

  @Test func aFailureShowsAToastAndKeepsThePreviousCards() async {
    let shouldFail = LockIsolated(false)
    let toasts = LockIsolated<[String]>([])
    let reports = LockIsolated(0)
    let model = await makeModel(series: [series("s1", rrule: nil)]) {
      $0.api.getAirings = { _, _ in
        if shouldFail.value { throw CuratorSeriesListTestError() }
        return []
      }
      $0.toast.show = { toast in toasts.withValue { $0.append(toast.message) } }
      $0.errorReporting.reportError = { _, _ in reports.withValue { $0 += 1 } }
    }
    shouldFail.setValue(true)

    await model.viewAppeared()

    expectNoDifference(model.cards.map(\.id), ["s1"])
    expectNoDifference(toasts.value, ["Series couldn\u{2019}t load."])
    expectNoDifference(reports.value, 1)
    #expect(!model.isLoading)
  }

  @Test func aCancelledLoadShowsNoToast() async {
    let toasts = LockIsolated(0)
    let reports = LockIsolated(0)
    _ = await makeModel {
      $0.api.getCuratorSeries = { _, _ in throw CancellationError() }
      $0.toast.show = { _ in toasts.withValue { $0 += 1 } }
      $0.errorReporting.reportError = { _, _ in reports.withValue { $0 += 1 } }
    }

    expectNoDifference(toasts.value, 0)
    expectNoDifference(reports.value, 0)
  }

  @Test func recordedShowsChangedForThisStationReloadsAndForAnotherDoesNot() async {
    let notificationCenter = NotificationCenter()
    let loads = LockIsolated(0)
    let latest = LockIsolated<[CuratorSeries]>([])
    let reloaded = AsyncStream<Void>.makeStream()
    let model = await makeModel {
      $0.notificationCenter = notificationCenter
      $0.api.getCuratorSeries = { _, _ in
        loads.withValue { $0 += 1 }
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

    latest.setValue([series("new", rrule: nil)])
    notificationCenter.post(
      name: .recordedShowsChanged, object: nil, userInfo: ["stationId": "other-station"])
    notificationCenter.post(
      name: .recordedShowsChanged, object: nil, userInfo: ["stationId": stationId])
    await reloadIterator.next()
    await Task.megaYield()
    observer.cancel()
    await observer.value

    expectNoDifference(loads.value, 2)
    expectNoDifference(model.cards.map(\.id), ["new"])
  }

  // MARK: - Actions

  @Test func aCardsNamePushesTheSeriesPageWithThatSeries() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let tapped = series("s1", rrule: sundaySeven)
    let model = await makeModel(series: [tapped])

    model.seriesNameTapped(model.cards[0])

    guard case .curatorSeriesPage(let page) = coordinator.path.last else {
      Issue.record("Expected the Series page to be pushed")
      return
    }
    expectNoDifference(page.series, tapped)
    expectNoDifference(page.stationId, stationId)
    expectNoDifference(page.navigationTitle, "Series s1")
  }

  @Test func aShowPushesItsBuilder() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = await makeModel(
      series: [series("s1", rrule: nil)],
      episodes: [episode("e1", seriesId: "s1", at: [stationTime(2026, 11, 8, 19)])])
    let show = model.cards.first?.items.first?.shows.first

    model.showTapped(show?.episodeId ?? "")

    guard case .showBuilderPage(let builder) = coordinator.path.last else {
      Issue.record("Expected the builder to be pushed")
      return
    }
    expectNoDifference(builder.stationId, stationId)
    expectNoDifference(builder.episodeId, "e1")
  }

  @Test func createANewSeriesPresentsTheDetailsSheetInNewSeriesMode() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = await makeModel()

    model.createSeriesButtonTapped()

    guard case .seriesDetails(let details) = coordinator.presentedSheet else {
      Issue.record("Expected the Series details sheet")
      return
    }
    expectNoDifference(details.navigationTitle, "New Series")
    expectNoDifference(details.stationId, stationId)
    expectNoDifference(details.timeZone, chicago)

    details.cancelButtonTapped()
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func createANewSeriesOpensAfterAFailedFirstLoadInCentralTime() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = await makeModel {
      $0.api.getStationSchedulingSettings = { _, _ in throw CuratorSeriesListTestError() }
      $0.toast.show = { _ in }
      $0.errorReporting.reportError = { _, _ in }
    }

    model.createSeriesButtonTapped()

    guard case .seriesDetails(let details) = coordinator.presentedSheet else {
      Issue.record("Expected the Series details sheet")
      return
    }
    #expect(model.settings == nil)
    expectNoDifference(details.timeZone, chicago)
  }

  @Test func savingANewSeriesClosesTheSheet() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = await makeModel {
      $0.notificationCenter = NotificationCenter()
      $0.api.createSeries = { [self] _, _, title, rrule in
        CuratorSeries(id: "new", stationId: stationId, title: title, isOneTime: false, rrule: rrule)
      }
    }
    model.createSeriesButtonTapped()
    guard case .seriesDetails(let details) = coordinator.presentedSheet else {
      Issue.record("Expected the Series details sheet")
      return
    }
    details.name = "Porch Sessions"
    details.repeatOptionTapped(.noSchedule)

    await details.saveButtonTapped()

    #expect(coordinator.presentedSheet == nil)
  }
}
