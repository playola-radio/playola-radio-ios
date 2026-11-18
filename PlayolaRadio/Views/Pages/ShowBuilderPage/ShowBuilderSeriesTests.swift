//
//  ShowBuilderSeriesTests.swift
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

private struct SeriesServerRefusal: Error, LocalizedError {
  var errorDescription: String? { "The server said no." }
}

/// A fake recorded-shows server: records every write and answers reads with what it holds.
private final class FakeSeriesServer: Sendable {
  let log = LockIsolated<[String]>([])
  let episode: LockIsolated<CuratorEpisode?>
  let series: LockIsolated<[CuratorSeries]>
  let updateFailure = LockIsolated<(any Error)?>(nil)
  let createShowFailure = LockIsolated<(any Error)?>(nil)
  let createSeriesFailures = LockIsolated<[any Error]>([])
  let refreshFails = LockIsolated(false)

  init(episode: CuratorEpisode?, series: [CuratorSeries]) {
    self.episode = LockIsolated(episode)
    self.series = LockIsolated(series)
  }

  var writes: [String] { log.value.filter { !$0.hasPrefix("get") } }

  func install(_ dependencies: inout DependencyValues, createdShow: CuratorEpisode) {
    dependencies.api.getCuratorEpisode = { [self] _, id in
      log.withValue { $0.append("getEpisode:\(id)") }
      guard !refreshFails.value, let episode = episode.value else { throw SeriesServerRefusal() }
      return episode
    }
    dependencies.api.getCuratorSeries = { [self] _, _ in
      log.withValue { $0.append("getSeries") }
      return series.value
    }
    dependencies.api.createStandaloneEpisode = { [self] _, _, _ in
      log.withValue { $0.append("createShow") }
      if let failure = createShowFailure.value { throw failure }
      episode.setValue(createdShow)
      return createdShow
    }
    dependencies.api.createSeries = { [self] _, stationId, title, rrule in
      log.withValue { $0.append("createSeries:\(title)") }
      let failure = createSeriesFailures.withValue { $0.isEmpty ? nil : $0.removeFirst() }
      if let failure { throw failure }
      let created = CuratorSeries(
        id: "series-new", stationId: stationId, title: title, isOneTime: false, rrule: rrule)
      series.withValue { $0.append(created) }
      return created
    }
    dependencies.api.updateEpisode = { [self] _, id, update in
      log.withValue { $0.append("update:\(id):\(Self.describe(update.series))") }
      if let failure = updateFailure.value { throw failure }
      let joined: CuratorSeries? =
        switch update.series {
        case .join(let seriesId): series.value.first { $0.id == seriesId }
        case .makeStandalone, nil: nil
        }
      let saved = episode.value.map { $0.withShow(joined) }
      episode.setValue(saved)
      return saved.map { $0.withShow(joined).withoutContent() } ?? createdShow
    }
  }

  private static func describe(_ change: SeriesChange?) -> String {
    switch change {
    case .join(let id): "join(\(id))"
    case .makeStandalone: "standalone"
    case nil: "none"
    }
  }
}

extension CuratorEpisode {
  fileprivate func withShow(_ show: CuratorSeries?) -> CuratorEpisode {
    CuratorEpisode(
      id: id, showId: show?.id ?? "one-time", title: title, durationMS: durationMS, show: show,
      segments: segments, airings: airings)
  }

  fileprivate func withoutContent() -> CuratorEpisode {
    CuratorEpisode(
      id: id, showId: showId, title: title, durationMS: durationMS, show: show, segments: [],
      airings: [])
  }
}

@Suite(.freshSharedState)
@MainActor
struct ShowBuilderSeriesTests {

  // MARK: - Test Helpers

  private let stationId = "station-1"
  // Sunday, Nov 22 2026 at 7:00 PM in Chicago.
  private let airtime = Date(timeIntervalSince1970: 1_795_395_600)
  private let sixHoursMS = 21_600_000

  private var thisOnesForYou: CuratorSeries {
    CuratorSeries(
      id: "series-1", stationId: stationId, title: "This One\u{2019}s For You", isOneTime: false,
      rrule: "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0")
  }

  private var kitchenTableSongs: CuratorSeries {
    CuratorSeries(
      id: "series-2", stationId: stationId, title: "Kitchen Table Songs", isOneTime: false,
      rrule: "FREQ=WEEKLY;BYDAY=WE;BYHOUR=20;BYMINUTE=0")
  }

  private var oneTimeWrapper: CuratorSeries {
    CuratorSeries(
      id: "one-time", stationId: stationId, title: "Tour Stories", isOneTime: true, rrule: nil)
  }

  private func episode(
    id: String = "episode-1", title: String = "Tour Stories", show: CuratorSeries? = nil,
    airings: [CuratorAiring]? = nil
  ) -> CuratorEpisode {
    let segment = CuratorEpisodeSegment(
      id: "s1", position: 0, offsetMS: 0,
      audioBlock: AudioBlock.mockWith(
        id: "block-1", title: "Hummingbird", artist: "Flatland Cavalry", durationMS: 185_000,
        endOfMessageMS: 185_000, type: "song"))
    let airing = CuratorAiring(
      id: "airing-1", episodeId: id, stationId: stationId, airtime: airtime, startTime: nil,
      endTime: nil)
    return CuratorEpisode(
      id: id, showId: show?.id ?? "one-time", title: title, durationMS: 185_000,
      show: show ?? oneTimeWrapper, segments: [segment], airings: airings ?? [airing])
  }

  private var createdShow: CuratorEpisode {
    CuratorEpisode(
      id: "new-episode", showId: "one-time", title: "New Show", durationMS: 0,
      show: oneTimeWrapper, segments: [], airings: [])
  }

  private func makeServer(
    episode: CuratorEpisode? = nil, series: [CuratorSeries]? = nil
  ) -> FakeSeriesServer {
    FakeSeriesServer(
      episode: episode ?? self.episode(), series: series ?? [thisOnesForYou, kitchenTableSongs])
  }

  private func makeModel(
    server: FakeSeriesServer,
    episodeId: String? = "episode-1",
    now: Date? = nil,
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) -> ShowBuilderPageModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let resolvedNow = now ?? airtime.addingTimeInterval(-24 * 3600)
    let createdShow = createdShow
    return withDependencies {
      $0.date.now = resolvedNow
      $0.notificationCenter = NotificationCenter()
      $0.errorReporting.reportError = { _, _ in }
      $0.toast.show = { _ in }
      $0.api.getStationSchedulingSettings = { [sixHoursMS] _, _ in
        StationSchedulingSettings(timezone: "America/Chicago", airingEditLockMS: sixHoursMS)
      }
      $0.api.getListenerQuestions = { _, _ in [] }
      server.install(&$0, createdShow: createdShow)
      configure(&$0)
    } operation: {
      ShowBuilderPageModel(stationId: stationId, episodeId: episodeId, seriesId: nil, slot: nil)
    }
  }

  private func openPicker(
    _ model: ShowBuilderPageModel, loads: Bool = true
  ) async throws -> SeriesPickerSheetModel {
    @Shared(.mainContainerNavigationCoordinator) var coordinator
    model.seriesRowTapped()
    guard case .seriesPicker(let picker) = coordinator.presentedSheet else {
      Issue.record("The series picker did not open")
      throw SeriesServerRefusal()
    }
    if loads { await picker.viewAppeared() }
    return picker
  }

  // MARK: - Opening

  @Test(arguments: [-24.0, -1.0, 24.0, nil])
  func rowOpensThePickerInEveryBuilderState(hoursFromAirtime: Double?) async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let loaded = episode(show: thisOnesForYou, airings: hoursFromAirtime == nil ? [] : nil)
    let now = airtime.addingTimeInterval((hoursFromAirtime ?? -24) * 3600)
    let model = makeModel(server: makeServer(episode: loaded), now: now)
    await model.viewAppeared()

    let picker = try await openPicker(model, loads: false)

    expectNoDifference(picker.title, "Series")
    expectNoDifference(picker.currentSeries?.id, "series-1")
    expectNoDifference(picker.showTitle, "Tour Stories")
  }

  @Test func theFourBuilderStatesAreCovered() async {
    var seen: [String] = []
    for hours in [-24.0, -1.0, 24.0, nil] as [Double?] {
      let loaded = episode(show: thisOnesForYou, airings: hours == nil ? [] : nil)
      let model = makeModel(
        server: makeServer(episode: loaded),
        now: airtime.addingTimeInterval((hours ?? -24) * 3600))
      await model.viewAppeared()
      seen.append(Self.stateName(model.state))
    }
    expectNoDifference(seen, ["scheduled", "locked", "aired", "draft"])
  }

  private static func stateName(_ state: CuratorEpisodeState) -> String {
    switch state {
    case .draft: "draft"
    case .scheduled: "scheduled"
    case .locked: "locked"
    case .aired: "aired"
    }
  }

  @Test func standaloneShowOpensAddToASeries() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = makeModel(server: makeServer())
    await model.viewAppeared()

    let picker = try await openPicker(model, loads: false)

    expectNoDifference(picker.title, "Add to a series")
    #expect(picker.currentSeries == nil)
  }

  @Test func rowDoesNothingWhileTheShowLoads() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = makeModel(server: makeServer())

    model.seriesRowTapped()

    #expect(coordinator.presentedSheet == nil)
  }

  @Test func rowDoesNothingForAShowThatAirsMoreThanOnce() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let first = CuratorAiring(
      id: "a1", episodeId: "episode-1", stationId: stationId, airtime: airtime, startTime: nil,
      endTime: nil)
    let second = CuratorAiring(
      id: "a2", episodeId: "episode-1", stationId: stationId,
      airtime: airtime.addingTimeInterval(7 * 24 * 3600), startTime: nil, endTime: nil)
    let model = makeModel(server: makeServer(episode: episode(airings: [first, second])))
    await model.viewAppeared()

    model.seriesRowTapped()

    #expect(coordinator.presentedSheet == nil)
  }

  // MARK: - Picking

  @Test func pickingJoinsAfterTheSheetClosesWithoutAnOptimisticUpdate() async throws {
    try await withMainSerialExecutor {
      @Shared(.mainContainerNavigationCoordinator) var coordinator =
        MainContainerNavigationCoordinator()
      let (gate, open) = AsyncStream<Void>.makeStream()
      let server = makeServer()
      let model = makeModel(server: server) {
        let update = $0.api.updateEpisode
        $0.api.updateEpisode = { jwt, id, change in
          for await _ in gate { break }
          return try await update(jwt, id, change)
        }
      }
      await model.viewAppeared()
      let picker = try await openPicker(model)

      let pick = Task { await picker.seriesRowTapped("series-2") }
      await Task.megaYield()

      #expect(coordinator.presentedSheet == nil)
      expectNoDifference(model.seriesTitle, "Add to a series")

      open.yield()
      open.finish()
      await pick.value

      expectNoDifference(server.writes, ["update:episode-1:join(series-2)"])
      expectNoDifference(model.seriesTitle, "Kitchen Table Songs")
      expectNoDifference(model.episode?.airings.map(\.airtime), [airtime])
    }
  }

  @Test func joinKeepsSegmentsAndAiringsWhenTheRefreshFails() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer()
    let model = makeModel(server: server)
    await model.viewAppeared()
    let picker = try await openPicker(model)
    let before = model.episode
    server.refreshFails.setValue(true)

    await picker.seriesRowTapped("series-1")

    expectNoDifference(model.seriesTitle, "This One\u{2019}s For You")
    expectNoDifference(model.episode?.segments, before?.segments)
    expectNoDifference(model.episode?.airings, before?.airings)
  }

  @Test func switchingSeriesSendsTheNewSeries() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer(episode: episode(show: thisOnesForYou))
    let model = makeModel(server: server)
    await model.viewAppeared()
    let picker = try await openPicker(model)

    await picker.seriesRowTapped("series-2")

    expectNoDifference(server.writes, ["update:episode-1:join(series-2)"])
    expectNoDifference(model.seriesTitle, "Kitchen Table Songs")
  }

  @Test func removingMakesTheShowStandalone() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer(episode: episode(show: thisOnesForYou))
    let model = makeModel(server: server)
    await model.viewAppeared()
    let picker = try await openPicker(model)

    await picker.removeButtonTapped()

    expectNoDifference(server.writes, ["update:episode-1:standalone"])
    expectNoDifference(model.seriesTitle, "Add to a series")
  }

  @Test func tappingTheCheckedSeriesSendsNothing() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer(episode: episode(show: thisOnesForYou))
    let model = makeModel(server: server)
    await model.viewAppeared()
    let picker = try await openPicker(model)

    await picker.seriesRowTapped("series-1")
    picker.dismissed()

    expectNoDifference(server.writes, [])
    #expect(coordinator.presentedSheet == nil)
    #expect(model.canChangeSeries)
  }

  @Test func refusalRefreshesOnceAndAlertsOnlyAfterTheSheetIsGone() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer()
    server.updateFailure.setValue(APIError.serverError("That series is full"))
    let model = makeModel(server: server)
    await model.viewAppeared()
    let picker = try await openPicker(model)
    server.log.setValue([])

    await picker.seriesRowTapped("series-2")

    expectNoDifference(
      server.log.value, ["update:episode-1:join(series-2)", "getEpisode:episode-1"])
    #expect(model.presentedAlert == nil)

    picker.dismissed()

    expectNoDifference(model.presentedAlert?.message, "That series is full")
    #expect(model.canChangeSeries)
  }

  @Test func dismissalBeforeTheRefusalAlertsAsSoonAsItArrives() async throws {
    try await withMainSerialExecutor {
      @Shared(.mainContainerNavigationCoordinator) var coordinator =
        MainContainerNavigationCoordinator()
      let (gate, open) = AsyncStream<Void>.makeStream()
      let server = makeServer()
      let model = makeModel(server: server) {
        $0.api.updateEpisode = { _, _, _ in
          for await _ in gate { break }
          throw APIError.serverError("That series is full")
        }
      }
      await model.viewAppeared()
      let picker = try await openPicker(model)

      let pick = Task { await picker.seriesRowTapped("series-2") }
      await Task.megaYield()
      picker.dismissed()
      #expect(model.presentedAlert == nil)

      open.yield()
      open.finish()
      await pick.value

      expectNoDifference(model.presentedAlert?.message, "That series is full")
    }
  }

  @Test func rowStaysDisabledUntilTheChangeFinishesAndTheSheetIsGone() async throws {
    try await withMainSerialExecutor {
      @Shared(.mainContainerNavigationCoordinator) var coordinator =
        MainContainerNavigationCoordinator()
      for dismissFirst in [true, false] {
        $coordinator.withLock { $0.presentedSheet = nil }
        let (gate, open) = AsyncStream<Void>.makeStream()
        let server = makeServer()
        let model = makeModel(server: server) {
          let update = $0.api.updateEpisode
          $0.api.updateEpisode = { jwt, id, change in
            for await _ in gate { break }
            return try await update(jwt, id, change)
          }
        }
        await model.viewAppeared()
        let picker = try await openPicker(model)

        let pick = Task { await picker.seriesRowTapped("series-2") }
        await Task.megaYield()
        #expect(!model.canChangeSeries)
        model.seriesRowTapped()
        #expect(coordinator.presentedSheet == nil)

        if dismissFirst {
          picker.dismissed()
          #expect(!model.canChangeSeries)
          open.yield()
          open.finish()
          await pick.value
        } else {
          open.yield()
          open.finish()
          await pick.value
          #expect(!model.canChangeSeries)
          picker.dismissed()
        }

        #expect(model.canChangeSeries)
      }
    }
  }

  // MARK: - Unsaved Show

  @Test func openingAndDismissingTheSheetsOnAnUnsavedShowCreatesNothing() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer(episode: nil)
    let model = makeModel(server: server, episodeId: nil)
    await model.viewAppeared()
    let picker = try await openPicker(model)

    picker.newSeriesRowTapped()
    picker.seriesDetails?.cancelButtonTapped()
    $coordinator.withLock { $0.presentedSheet = nil }
    picker.dismissed()

    expectNoDifference(server.writes, [])
    #expect(model.episodeId == nil)
  }

  @Test func pickingOnAnUnsavedShowCreatesItOnceThenJoins() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer(episode: nil)
    let model = makeModel(server: server, episodeId: nil)
    await model.viewAppeared()
    let picker = try await openPicker(model)

    await picker.seriesRowTapped("series-1")
    picker.dismissed()

    expectNoDifference(server.writes, ["createShow", "update:new-episode:join(series-1)"])
    expectNoDifference(model.episodeId, "new-episode")
    expectNoDifference(model.seriesTitle, "This One\u{2019}s For You")
  }

  @Test func laterChangesEditTheSameCreatedShow() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer(episode: nil)
    let model = makeModel(server: server, episodeId: nil)
    await model.viewAppeared()
    let first = try await openPicker(model)
    await first.seriesRowTapped("series-1")
    first.dismissed()

    let second = try await openPicker(model)
    await second.removeButtonTapped()

    expectNoDifference(
      server.writes,
      ["createShow", "update:new-episode:join(series-1)", "update:new-episode:standalone"])
  }

  @Test func failedCreationOfAnUnsavedShowLeavesItUnsaved() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer(episode: nil)
    server.createShowFailure.setValue(APIError.serverError("Couldn\u{2019}t make that show"))
    let model = makeModel(server: server, episodeId: nil)
    await model.viewAppeared()
    let picker = try await openPicker(model)

    await picker.seriesRowTapped("series-1")
    #expect(model.presentedAlert == nil)
    picker.dismissed()

    expectNoDifference(server.writes, ["createShow"])
    #expect(model.episodeId == nil)
    expectNoDifference(model.presentedAlert?.message, "Couldn\u{2019}t make that show")
  }

  @Test func failedJoinKeepsTheCreatedShow() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer(episode: nil)
    server.updateFailure.setValue(APIError.serverError("No"))
    let model = makeModel(server: server, episodeId: nil)
    await model.viewAppeared()
    let picker = try await openPicker(model)

    await picker.seriesRowTapped("series-1")
    picker.dismissed()

    expectNoDifference(model.episodeId, "new-episode")
    expectNoDifference(model.presentedAlert?.message, "No")
  }

  @Test func renameQueuedAlongsideAPickCreatesOneShow() async throws {
    try await withMainSerialExecutor {
      @Shared(.mainContainerNavigationCoordinator) var coordinator =
        MainContainerNavigationCoordinator()
      let (gate, open) = AsyncStream<Void>.makeStream()
      let server = makeServer(episode: nil)
      let created = createdShow
      let model = makeModel(server: server, episodeId: nil) {
        $0.api.createStandaloneEpisode = { _, _, _ in
          server.log.withValue { $0.append("createShow") }
          for await _ in gate { break }
          server.episode.setValue(created)
          return created
        }
      }
      await model.viewAppeared()
      let picker = try await openPicker(model)

      let pick = Task { await picker.seriesRowTapped("series-1") }
      await Task.megaYield()
      model.renameText = "Tour Stories"
      let rename = Task { await model.renameSaveButtonTapped() }
      await Task.megaYield()
      open.yield()
      open.finish()
      await pick.value
      await rename.value

      expectNoDifference(server.writes.filter { $0 == "createShow" }, ["createShow"])
      expectNoDifference(server.writes.count, 3)
    }
  }

  // MARK: - New Series

  @Test func newSeriesCreatesTheSeriesThenTheShowThenJoins() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer(episode: nil)
    let model = makeModel(server: server, episodeId: nil)
    await model.viewAppeared()
    let picker = try await openPicker(model)
    picker.newSeriesRowTapped()
    let details = try #require(picker.seriesDetails)
    details.name = "Porch Sessions"
    details.repeatOption = .noSchedule

    await details.saveButtonTapped()

    expectNoDifference(
      server.writes,
      ["createSeries:Porch Sessions", "createShow", "update:new-episode:join(series-new)"])
    #expect(picker.seriesDetails == nil)
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func tuesdayAndThursdayAtEightReadsBackInStationTime() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer()
    let model = makeModel(server: server) {
      $0.timeZone = TimeZone(identifier: "Asia/Tokyo")!
      $0.api.getStationSchedulingSettings = { _, _ in throw SeriesServerRefusal() }
    }
    await model.viewAppeared()
    let picker = try await openPicker(model)
    picker.newSeriesRowTapped()
    let details = try #require(picker.seriesDetails)
    var chicago = Calendar(identifier: .gregorian)
    chicago.timeZone = TimeZone(identifier: "America/Chicago")!
    details.name = "Porch Sessions"
    details.dayTapped(.tuesday)
    details.dayTapped(.thursday)
    details.startTime = chicago.date(bySettingHour: 20, minute: 0, second: 0, of: airtime)!

    await details.saveButtonTapped()
    picker.dismissed()

    expectNoDifference(
      server.series.value.last?.rrule, "FREQ=WEEKLY;BYDAY=TU,TH;BYHOUR=20;BYMINUTE=0")
    let reopened = try await openPicker(model)
    expectNoDifference(
      reopened.rows[id: "series-new"]?.subtitle, "Every Tuesday and Thursday at 8pm")
  }

  @Test func saveStaysBusyThroughCreateJoinAndRefresh() async throws {
    try await withMainSerialExecutor {
      @Shared(.mainContainerNavigationCoordinator) var coordinator =
        MainContainerNavigationCoordinator()
      let (gate, open) = AsyncStream<Void>.makeStream()
      let server = makeServer()
      let model = makeModel(server: server) {
        let getEpisode = $0.api.getCuratorEpisode
        $0.api.getCuratorEpisode = { jwt, id in
          let isRefresh = server.writes.contains { $0.hasPrefix("update") }
          if isRefresh { for await _ in gate { break } }
          return try await getEpisode(jwt, id)
        }
      }
      await model.viewAppeared()
      let picker = try await openPicker(model)
      picker.newSeriesRowTapped()
      let details = try #require(picker.seriesDetails)
      details.name = "Porch Sessions"
      details.repeatOption = .noSchedule
      server.log.setValue([])

      let save = Task { await details.saveButtonTapped() }
      await Task.megaYield()

      #expect(details.isSaving)
      #expect(picker.seriesDetails != nil)
      await details.saveButtonTapped()

      open.yield()
      open.finish()
      await save.value

      expectNoDifference(
        server.log.value,
        [
          "createSeries:Porch Sessions", "update:episode-1:join(series-new)",
          "getEpisode:episode-1",
        ])
      #expect(picker.seriesDetails == nil)
      #expect(coordinator.presentedSheet == nil)
    }
  }

  @Test func failedSeriesCreationKeepsTheSheetAndLeavesTheBuilderAlone() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer()
    server.createSeriesFailures.setValue([APIError.serverError("Name is taken")])
    let model = makeModel(server: server)
    await model.viewAppeared()
    let picker = try await openPicker(model)
    picker.newSeriesRowTapped()
    let details = try #require(picker.seriesDetails)
    details.name = "Porch Sessions"
    details.repeatOption = .noSchedule

    await details.saveButtonTapped()

    #expect(picker.seriesDetails === details)
    #expect(coordinator.presentedSheet == .seriesPicker(picker))
    expectNoDifference(details.name, "Porch Sessions")
    expectNoDifference(details.presentedAlert?.message, "Name is taken")
    #expect(!model.isSavingSeries)
    expectNoDifference(server.writes, ["createSeries:Porch Sessions"])
  }

  @Test func retryAfterAFailedCreationJoinsAndReenablesTheRow() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer()
    server.createSeriesFailures.setValue([APIError.serverError("Try again")])
    let model = makeModel(server: server)
    await model.viewAppeared()
    let picker = try await openPicker(model)
    picker.newSeriesRowTapped()
    let details = try #require(picker.seriesDetails)
    details.name = "Porch Sessions"
    details.repeatOption = .noSchedule

    await details.saveButtonTapped()
    details.presentedAlert = nil
    await details.saveButtonTapped()
    #expect(!model.canChangeSeries)
    picker.dismissed()

    expectNoDifference(
      server.writes,
      [
        "createSeries:Porch Sessions", "createSeries:Porch Sessions",
        "update:episode-1:join(series-new)",
      ])
    expectNoDifference(model.seriesTitle, "Porch Sessions")
    #expect(model.canChangeSeries)
  }

  @Test func failedCreationThenCancelStillLetsAnExistingSeriesBePicked() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer()
    server.createSeriesFailures.setValue([APIError.serverError("Nope")])
    let model = makeModel(server: server)
    await model.viewAppeared()
    let picker = try await openPicker(model)
    picker.newSeriesRowTapped()
    let details = try #require(picker.seriesDetails)
    details.name = "Porch Sessions"
    details.repeatOption = .noSchedule

    await details.saveButtonTapped()
    details.cancelButtonTapped()
    await picker.seriesRowTapped("series-2")

    expectNoDifference(
      server.writes, ["createSeries:Porch Sessions", "update:episode-1:join(series-2)"])
  }

  @Test func failedJoinOfANewSeriesClosesBothSheetsAndAlertsAfterDismissal() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer()
    server.updateFailure.setValue(APIError.serverError("Couldn\u{2019}t join"))
    let model = makeModel(server: server)
    await model.viewAppeared()
    let picker = try await openPicker(model)
    picker.newSeriesRowTapped()
    let details = try #require(picker.seriesDetails)
    details.name = "Porch Sessions"
    details.repeatOption = .noSchedule

    await details.saveButtonTapped()

    #expect(picker.seriesDetails == nil)
    #expect(coordinator.presentedSheet == nil)
    #expect(model.presentedAlert == nil)
    picker.dismissed()
    expectNoDifference(model.presentedAlert?.message, "Couldn\u{2019}t join")

    let reopened = try await openPicker(model)
    expectNoDifference(
      reopened.rows.map(\.title),
      ["This One\u{2019}s For You", "Kitchen Table Songs", "Porch Sessions"])
  }

  @Test func failedShowCreationAfterANewSeriesClosesBothSheetsAndAlertsAfterDismissal()
    async throws
  {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let server = makeServer(episode: nil)
    server.createShowFailure.setValue(APIError.serverError("No show for you"))
    let model = makeModel(server: server, episodeId: nil)
    await model.viewAppeared()
    let picker = try await openPicker(model)
    picker.newSeriesRowTapped()
    let details = try #require(picker.seriesDetails)
    details.name = "Porch Sessions"
    details.repeatOption = .noSchedule

    await details.saveButtonTapped()

    #expect(picker.seriesDetails == nil)
    #expect(coordinator.presentedSheet == nil)
    #expect(model.presentedAlert == nil)
    picker.dismissed()
    expectNoDifference(model.presentedAlert?.message, "No show for you")
    #expect(model.episodeId == nil)
  }
}
