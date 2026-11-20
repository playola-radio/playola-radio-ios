//
//  AddShowToSeriesSheetTests.swift
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

private struct AddShowTestError: Error {}

@Suite(.freshSharedState)
@MainActor
struct AddShowToSeriesSheetTests {

  // MARK: - Test Helpers

  private let stationId = "station-1"
  private let chicago = TimeZone(identifier: "America/Chicago")!
  private let sixHoursMS = 6 * 60 * 60 * 1000
  private var settings: StationSchedulingSettings {
    StationSchedulingSettings(timezone: "America/Chicago", airingEditLockMS: sixHoursMS)
  }
  private let thisSeries = CuratorSeries(
    id: "s1", stationId: "station-1", title: "This One\u{2019}s For You", isOneTime: false,
    rrule: "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0")

  /// Thursday, November 5, 2026, noon in Chicago.
  private var now: Date { stationTime(2026, 11, 5, 12) }
  /// Sunday, November 22, 2026, 7pm in Chicago.
  private var slot: Date { stationTime(2026, 11, 22, 19) }
  /// Three hours from now: inside the six-hour lock.
  private var nearSlot: Date { now.addingTimeInterval(3 * 3600) }

  private func stationTime(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = chicago
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  private func episode(
    _ id: String, title: String? = nil, seriesId: String = "other-series", at airtimes: [Date] = [],
    minutes: Int = 18
  ) -> CuratorEpisode {
    let durationMS = minutes * 60_000
    return CuratorEpisode(
      id: id, showId: seriesId, title: title ?? "Show \(id)", durationMS: durationMS, show: nil,
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

  private var tourStories: CuratorEpisode {
    episode("tour-stories", title: "Tour Stories", minutes: 18)
  }
  private var backPorch: CuratorEpisode {
    episode(
      "back-porch", title: "Back Porch Requests", seriesId: "wrapper-1",
      at: [stationTime(2026, 11, 8, 19)], minutes: 42)
  }
  private var holiday: CuratorEpisode {
    episode(
      "holiday", title: "Holiday Hangout", at: [stationTime(2026, 11, 13, 19)], minutes: 25)
  }

  private func makeModel(
    slot: Date?,
    episodes: [CuratorEpisode] = [],
    finishes: LockIsolated<[AddShowToSeriesFailure?]> = LockIsolated([]),
    load: Bool = true,
    _ configure: (inout DependencyValues) -> Void = { _ in }
  ) async -> AddShowToSeriesSheetModel {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let model = withDependencies {
      $0.date.now = now
      $0.api.getCuratorEpisodes = { _, _, _ in episodes }
      $0.api.scheduleEpisode = { _, _, _, _ in }
      $0.api.moveAiring = { _, _, _ in }
      $0.api.getCuratorEpisode = { _, id in
        guard let episode = episodes.first(where: { $0.id == id }) else { throw AddShowTestError() }
        return episode
      }
      $0.api.updateEpisode = { [episodes] _, id, _ in
        episodes.first { $0.id == id } ?? episodes[0]
      }
      $0.notificationCenter = NotificationCenter()
      $0.errorReporting.reportError = { _, _ in }
      $0.toast.show = { _ in }
      configure(&$0)
    } operation: {
      AddShowToSeriesSheetModel(
        stationId: stationId, series: thisSeries, slot: slot, settings: settings,
        airings: stationAirings(episodes),
        onAddFinished: { failure in finishes.withValue { $0.append(failure) } })
    }
    if load { await model.viewAppeared() }
    return model
  }

  private func observePosts(on center: NotificationCenter) -> LockIsolated<[String]> {
    let posts = LockIsolated<[String]>([])
    _ = center.addObserver(forName: .recordedShowsChanged, object: nil, queue: nil) {
      notification in
      let stationId = notification.userInfo?["stationId"] as? String ?? "nil"
      posts.withValue { $0.append(stationId) }
    }
    return posts
  }

  // MARK: - Content

  @Test func fromASlotTheSubtitleNamesTheSeriesAndTheSlot() async {
    let model = await makeModel(slot: slot)

    expectNoDifference(model.title, "Add a show")
    expectNoDifference(model.subtitle, "This One\u{2019}s For You \u{00B7} Sunday, Nov 22 at 7pm")
    expectNoDifference(model.recordNewShowTitle, "Record a New Show")
    expectNoDifference(model.recordNewShowSubtitle, "Start from scratch for this slot")
  }

  @Test func withNoSlotTheSubtitleIsJustTheSeries() async {
    let model = await makeModel(slot: nil)

    expectNoDifference(model.subtitle, "This One\u{2019}s For You")
  }

  @Test func rowSubtitlesFromASlot() async {
    let model = await makeModel(slot: slot, episodes: [tourStories, backPorch])

    expectNoDifference(model.listHeaders, ["OR ADD ONE OF YOUR SHOWS"])
    expectNoDifference(
      model.rows.map { [$0.title, $0.subtitle] },
      [
        ["Tour Stories", "Not scheduled yet \u{00B7} 18 min"],
        ["Back Porch Requests", "Moves here from Sun, Nov 8 \u{00B7} 42 min"],
      ])
    expectNoDifference(model.rows.map(\.drafts.count), [1, 0])
    expectNoDifference(
      model.rows.map(\.addButtonAccessibilityLabel),
      ["Add Tour Stories", "Add Back Porch Requests"])
    expectNoDifference(model.rows[1].scheduled.map(\.tile.date), [stationTime(2026, 11, 8, 19)])
  }

  @Test func rowSubtitlesWithNoSlotShowTheirOwnAirTime() async {
    let model = await makeModel(slot: nil, episodes: [tourStories, backPorch])

    expectNoDifference(
      model.rows.map(\.subtitle),
      ["Not scheduled yet \u{00B7} 18 min", "Sun, Nov 8 \u{00B7} 42 min"])
  }

  @Test func draftsComeFirstInServerOrderThenScheduledShowsByAirTime() async {
    let model = await makeModel(
      slot: slot,
      episodes: [
        holiday, episode("draft-b"), backPorch, episode("draft-a"),
      ])

    expectNoDifference(model.rows.map(\.id), ["draft-b", "draft-a", "back-porch", "holiday"])
  }

  @Test func ineligibleShowsAreNeverOffered() async {
    let airtime = stationTime(2026, 11, 21, 19)
    let onAnotherStation = CuratorEpisode(
      id: "elsewhere", showId: "other-series", title: "Elsewhere", durationMS: 18 * 60_000,
      show: nil, segments: [],
      airings: [
        CuratorAiring(
          id: "elsewhere-airing", episodeId: "elsewhere", stationId: "station-2",
          airtime: airtime, startTime: airtime, endTime: airtime.addingTimeInterval(18 * 60))
      ])
    let model = await makeModel(
      slot: slot,
      episodes: [
        episode("own-draft", seriesId: "s1"),
        episode("own-scheduled", seriesId: "s1", at: [stationTime(2026, 11, 15, 19)]),
        episode("locked", at: [now.addingTimeInterval(2 * 3600)]),
        episode(
          "multi", at: [stationTime(2026, 11, 10, 19), stationTime(2026, 11, 11, 19)]),
        episode("no-audio", minutes: 0),
        episode("aired", at: [now.addingTimeInterval(-24 * 3600)]),
        episode("standalone", seriesId: "wrapper-9"),
        episode("other-series", seriesId: "s2", at: [stationTime(2026, 11, 20, 19)]),
        onAnotherStation,
      ])

    expectNoDifference(model.rows.map(\.id), ["standalone", "other-series"])
  }

  @Test func withNothingToOfferTheHeadingIsHidden() async {
    let model = await makeModel(slot: slot, episodes: [episode("own", seriesId: "s1")])

    expectNoDifference(model.rows.count, 0)
    expectNoDifference(model.listHeaders, [])
    expectNoDifference(model.loadingSpinners, [])
  }

  // MARK: - Loading

  @Test func aGatedLoadShowsRecordNewShowAndAProgressView() async {
    await withMainSerialExecutor {
      let (gate, open) = AsyncStream<Void>.makeStream()
      let requests = LockIsolated<[String]>([])
      let model = await makeModel(slot: slot, load: false) {
        $0.api.getCuratorEpisodes = { [tourStories] _, stationId, showId in
          requests.withValue { $0.append("\(stationId ?? "nil"):\(showId ?? "nil")") }
          for await _ in gate { break }
          return [tourStories]
        }
      }

      let load = Task { await model.viewAppeared() }
      await Task.megaYield()

      expectNoDifference(model.recordNewShowTitle, "Record a New Show")
      expectNoDifference(model.loadingSpinners.count, 1)
      expectNoDifference(model.listHeaders, [])
      expectNoDifference(model.rows.count, 0)

      open.yield()
      open.finish()
      await load.value

      expectNoDifference(requests.value, ["station-1:nil"])
      expectNoDifference(model.loadingSpinners, [])
      expectNoDifference(model.rows.map(\.id), ["tour-stories"])
    }
  }

  @Test func aFailedLoadShowsAToastAndTheNothingToOfferLook() async {
    let toasts = LockIsolated<[String]>([])
    let reports = LockIsolated(0)
    let model = await makeModel(slot: slot) {
      $0.api.getCuratorEpisodes = { _, _, _ in throw AddShowTestError() }
      $0.toast.show = { toast in toasts.withValue { $0.append(toast.message) } }
      $0.errorReporting.reportError = { _, _ in reports.withValue { $0 += 1 } }
    }

    expectNoDifference(toasts.value, ["Your shows couldn\u{2019}t load."])
    expectNoDifference(reports.value, 1)
    expectNoDifference(model.loadingSpinners, [])
    expectNoDifference(model.listHeaders, [])
    #expect(model.isRecordNewShowEnabled)
  }

  @Test func aCancelledLoadShowsNoToast() async {
    let toasts = LockIsolated(0)
    _ = await makeModel(slot: slot) {
      $0.api.getCuratorEpisodes = { _, _, _ in throw CancellationError() }
      $0.toast.show = { _ in toasts.withValue { $0 += 1 } }
    }

    expectNoDifference(toasts.value, 0)
  }

  // MARK: - Adding from a slot

  @Test func addingADraftSchedulesItAtTheSlotThenJoinsTheSeries() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let requests = LockIsolated<[String]>([])
    let center = NotificationCenter()
    let posts = observePosts(on: center)
    let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
    let model = await makeModel(slot: slot, episodes: [tourStories], finishes: finishes) {
      $0.notificationCenter = center
      $0.api.scheduleEpisode = { [slot] _, episodeId, stationId, airtime in
        expectNoDifference(airtime, slot)
        requests.withValue { $0.append("schedule:\(episodeId):\(stationId)") }
      }
      $0.api.updateEpisode = { [tourStories] _, episodeId, update in
        requests.withValue { $0.append("join:\(episodeId)") }
        expectNoDifference(update, CuratorEpisodeUpdate(series: .join("s1")))
        return tourStories
      }
    }
    coordinator.presentedSheet = .addShowToSeries(model)

    await model.addButtonTapped("tour-stories")

    expectNoDifference(requests.value, ["schedule:tour-stories:station-1", "join:tour-stories"])
    expectNoDifference(posts.value, ["station-1"])
    expectNoDifference(coordinator.presentedSheet, nil)
    expectNoDifference(finishes.value.count, 0)

    model.dismissed()
    model.dismissed()
    expectNoDifference(finishes.value, [nil])
  }

  @Test func addingAScheduledShowMovesItsAiringThenJoinsTheSeries() async {
    let requests = LockIsolated<[String]>([])
    let model = await makeModel(slot: slot, episodes: [backPorch]) {
      $0.api.moveAiring = { [slot] _, airingId, airtime in
        expectNoDifference(airtime, slot)
        requests.withValue { $0.append("move:\(airingId)") }
      }
      $0.api.updateEpisode = { [backPorch] _, episodeId, _ in
        requests.withValue { $0.append("join:\(episodeId)") }
        return backPorch
      }
    }

    await model.addButtonTapped("back-porch")

    expectNoDifference(requests.value, ["move:back-porch-airing-0", "join:back-porch"])
  }

  @Test func whileAnAddWorksTheRowIsBusyAndEverythingElseIsBlocked() async {
    await withMainSerialExecutor {
      @Shared(.mainContainerNavigationCoordinator) var coordinator =
        MainContainerNavigationCoordinator()
      let (scheduleGate, openSchedule) = AsyncStream<Void>.makeStream()
      let (joinGate, openJoin) = AsyncStream<Void>.makeStream()
      let requests = LockIsolated<[String]>([])
      let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
      let model = await makeModel(
        slot: slot, episodes: [tourStories, backPorch], finishes: finishes
      ) {
        $0.api.scheduleEpisode = { _, _, _, _ in
          requests.withValue { $0.append("schedule") }
          for await _ in scheduleGate { break }
        }
        $0.api.updateEpisode = { [tourStories] _, _, _ in
          requests.withValue { $0.append("join") }
          for await _ in joinGate { break }
          return tourStories
        }
      }
      coordinator.presentedSheet = .addShowToSeries(model)
      expectNoDifference(model.rows.map(\.addButtonTitles), [["Add"], ["Add"]])
      #expect(!model.isSwipeDismissDisabled)

      let add = Task { await model.addButtonTapped("tour-stories") }
      await Task.megaYield()

      expectNoDifference(model.rows.map(\.addButtonTitles), [[], ["Add"]])
      expectNoDifference(model.rows.map(\.busySpinners.count), [1, 0])
      expectNoDifference(model.rows.map(\.isAddEnabled), [false, false])
      #expect(!model.isRecordNewShowEnabled)
      #expect(model.isSwipeDismissDisabled)

      model.recordNewShowTapped()
      await model.addButtonTapped("back-porch")
      expectNoDifference(coordinator.presentedSheet, .addShowToSeries(model))
      expectNoDifference(coordinator.path.count, 0)

      openSchedule.yield()
      openSchedule.finish()
      await Task.megaYield()
      expectNoDifference(requests.value, ["schedule", "join"])
      expectNoDifference(coordinator.presentedSheet, .addShowToSeries(model))
      model.recordNewShowTapped()
      expectNoDifference(coordinator.path.count, 0)

      openJoin.yield()
      openJoin.finish()
      await add.value

      expectNoDifference(coordinator.presentedSheet, nil)
      expectNoDifference(coordinator.path.count, 0)
      expectNoDifference(finishes.value.count, 0)
      model.dismissed()
      expectNoDifference(finishes.value, [nil])
    }
  }

  // MARK: - Failures

  @Test func aStep1RefusalSendsNoJoinAndReportsCouldNotAdd() async {
    let joins = LockIsolated(0)
    let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
    let center = NotificationCenter()
    let posts = observePosts(on: center)
    let model = await makeModel(slot: slot, episodes: [tourStories], finishes: finishes) {
      $0.notificationCenter = center
      $0.api.scheduleEpisode = { _, _, _, _ in
        throw APIError.serverError("This overlaps Fall Favorites.")
      }
      $0.api.updateEpisode = { [tourStories] _, _, _ in
        joins.withValue { $0 += 1 }
        return tourStories
      }
    }

    await model.addButtonTapped("tour-stories")
    expectNoDifference(finishes.value.count, 0)
    model.dismissed()

    expectNoDifference(joins.value, 0)
    expectNoDifference(posts.value, ["station-1"])
    expectNoDifference(
      finishes.value,
      [
        AddShowToSeriesFailure(
          title: "Couldn\u{2019}t Add", message: "This overlaps Fall Favorites.")
      ])
  }

  @Test func aLockedRefusalReportsShowLocked() async {
    let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
    let model = await makeModel(slot: slot, episodes: [backPorch], finishes: finishes) {
      $0.api.moveAiring = { _, _, _ in throw APIError.recordedShowLocked("This show is locked.") }
    }

    await model.addButtonTapped("back-porch")
    model.dismissed()

    expectNoDifference(
      finishes.value,
      [AddShowToSeriesFailure(title: "Show Locked", message: "This show is locked.")])
  }

  @Test func aStep2FailureReportsScheduledButNotInTheSeries() async {
    let requests = LockIsolated<[String]>([])
    let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
    let model = await makeModel(slot: slot, episodes: [tourStories], finishes: finishes) {
      $0.api.scheduleEpisode = { _, _, _, _ in requests.withValue { $0.append("schedule") } }
      $0.api.updateEpisode = { _, _, _ in
        requests.withValue { $0.append("join") }
        throw APIError.serverError("Series not found.")
      }
    }

    await model.addButtonTapped("tour-stories")
    model.dismissed()

    expectNoDifference(requests.value, ["schedule", "join"])
    expectNoDifference(
      finishes.value,
      [
        AddShowToSeriesFailure(
          title: "Scheduled, but Not in This One\u{2019}s For You", message: "Series not found.")
      ])
  }

  @Test func aNoSlotAddSendsOnlyTheJoin() async {
    let requests = LockIsolated<[String]>([])
    let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
    let model = await makeModel(slot: nil, episodes: [backPorch], finishes: finishes) {
      $0.api.scheduleEpisode = { _, _, _, _ in requests.withValue { $0.append("schedule") } }
      $0.api.moveAiring = { _, _, _ in requests.withValue { $0.append("move") } }
      $0.api.updateEpisode = { [backPorch] _, episodeId, _ in
        requests.withValue { $0.append("join:\(episodeId)") }
        return backPorch
      }
    }

    await model.addButtonTapped("back-porch")
    model.dismissed()

    expectNoDifference(requests.value, ["join:back-porch"])
    expectNoDifference(finishes.value, [nil])
  }

  @Test func aRefusedNoSlotJoinReportsCouldNotAdd() async {
    let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
    let model = await makeModel(slot: nil, episodes: [tourStories], finishes: finishes) {
      $0.api.updateEpisode = { _, _, _ in throw APIError.serverError("Nope.") }
    }

    await model.addButtonTapped("tour-stories")
    model.dismissed()

    expectNoDifference(
      finishes.value, [AddShowToSeriesFailure(title: "Couldn\u{2019}t Add", message: "Nope.")])
  }

  @Test func whenDismissalFinishesFirstTheFailureReportsAsSoonAsItArrives() async {
    await withMainSerialExecutor {
      let (gate, open) = AsyncStream<Void>.makeStream()
      let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
      let model = await makeModel(slot: slot, episodes: [tourStories], finishes: finishes) {
        $0.api.scheduleEpisode = { _, _, _, _ in
          for await _ in gate { break }
          throw APIError.serverError("Too soon.")
        }
      }

      let add = Task { await model.addButtonTapped("tour-stories") }
      await Task.megaYield()
      model.dismissed()
      expectNoDifference(finishes.value.count, 0)

      open.yield()
      open.finish()
      await add.value

      expectNoDifference(
        finishes.value,
        [AddShowToSeriesFailure(title: "Couldn\u{2019}t Add", message: "Too soon.")])
    }
  }

  @Test func aCancelledAddReportsNothing() async {
    let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
    let reports = LockIsolated(0)
    let model = await makeModel(slot: slot, episodes: [tourStories], finishes: finishes) {
      $0.api.scheduleEpisode = { _, _, _, _ in throw CancellationError() }
      $0.errorReporting.reportError = { _, _ in reports.withValue { $0 += 1 } }
    }

    await model.addButtonTapped("tour-stories")
    model.dismissed()

    expectNoDifference(finishes.value, [nil])
    expectNoDifference(reports.value, 0)
  }

  @Test func swipingAwayWithoutAddingReportsNothing() async {
    let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
    let model = await makeModel(slot: slot, episodes: [tourStories], finishes: finishes)

    model.dismissed()

    expectNoDifference(finishes.value.count, 0)
  }

  // MARK: - A near slot

  @Test func aNearSlotHandsOffToTheScheduleSheet() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
    let requests = LockIsolated<[String]>([])
    // Sunday 7pm slots: the moving Show's own airing (Nov 8) stays open; another Show's two
    // airings at this station (Nov 15 and 22) take theirs.
    let other = episode(
      "other", seriesId: "s1", at: [stationTime(2026, 11, 15, 19), stationTime(2026, 11, 22, 19)])
    let moving = episode("moving", at: [stationTime(2026, 11, 8, 19)])
    let model = await makeModel(
      slot: nearSlot, episodes: [moving, other], finishes: finishes
    ) {
      $0.api.moveAiring = { _, _, _ in requests.withValue { $0.append("move") } }
    }
    coordinator.presentedSheet = .addShowToSeries(model)

    await model.addButtonTapped("moving")

    guard case .scheduleShow(let schedule) = coordinator.presentedSheet else {
      Issue.record("Expected the Schedule sheet")
      return
    }
    expectNoDifference(schedule.pickedTime, nearSlot)
    expectNoDifference(schedule.episode.id, "moving")
    expectNoDifference(schedule.series, thisSeries)
    expectNoDifference(schedule.lockNotes.map(\.title), ["Locks right away"])
    expectNoDifference(requests.value, [])
    expectNoDifference(
      Array(schedule.slotRows.map(\.id).prefix(2)),
      [stationTime(2026, 11, 8, 19), stationTime(2026, 11, 29, 19)])

    model.dismissed()
    expectNoDifference(finishes.value.count, 0)
  }

  @Test func theScheduleClosureRunsStep1ThenTheJoin() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let requests = LockIsolated<[String]>([])
    let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
    let center = NotificationCenter()
    let posts = observePosts(on: center)
    let model = await makeModel(slot: nearSlot, episodes: [tourStories], finishes: finishes) {
      $0.notificationCenter = center
      $0.api.scheduleEpisode = { _, _, _, _ in
        requests.withValue { $0.append("schedule") }
      }
      $0.api.updateEpisode = { [tourStories] _, _, _ in
        requests.withValue { $0.append("join") }
        return tourStories
      }
    }
    coordinator.presentedSheet = .addShowToSeries(model)
    await model.addButtonTapped("tour-stories")
    model.dismissed()
    guard case .scheduleShow(let schedule) = coordinator.presentedSheet else {
      Issue.record("Expected the Schedule sheet")
      return
    }

    await schedule.scheduleButtonTapped()

    expectNoDifference(requests.value, ["schedule", "join"])
    expectNoDifference(posts.value, ["station-1"])
    expectNoDifference(coordinator.presentedSheet, nil)
    expectNoDifference(finishes.value.count, 0)
    schedule.dismissed()
    expectNoDifference(finishes.value, [nil])
  }

  @Test func aStep1RefusalInTheScheduleSheetStaysInline() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let joins = LockIsolated(0)
    let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
    let center = NotificationCenter()
    let posts = observePosts(on: center)
    let model = await makeModel(slot: nearSlot, episodes: [backPorch], finishes: finishes) {
      $0.notificationCenter = center
      $0.api.moveAiring = { _, _, _ in
        throw APIError.serverError("This overlaps Fall Favorites.")
      }
      $0.api.updateEpisode = { [backPorch] _, _, _ in
        joins.withValue { $0 += 1 }
        return backPorch
      }
    }
    coordinator.presentedSheet = .addShowToSeries(model)
    await model.addButtonTapped("back-porch")
    guard case .scheduleShow(let schedule) = coordinator.presentedSheet else {
      Issue.record("Expected the Schedule sheet")
      return
    }

    await schedule.scheduleButtonTapped()

    expectNoDifference(schedule.errorLines, ["This overlaps Fall Favorites."])
    expectNoDifference(coordinator.presentedSheet, .scheduleShow(schedule))
    expectNoDifference(joins.value, 0)
    expectNoDifference(posts.value, ["station-1"])

    schedule.cancelButtonTapped()
    schedule.dismissed()
    expectNoDifference(finishes.value, [nil])
  }

  @Test func aRetryAfterAFailedScheduleThatCommittedMovesTheNewAiring() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let requests = LockIsolated<[String]>([])
    let committed = episode("tour-stories", title: "Tour Stories", at: [nearSlot])
    let model = await makeModel(slot: nearSlot, episodes: [tourStories]) {
      $0.api.scheduleEpisode = { _, _, _, _ in
        requests.withValue { $0.append("schedule") }
        throw URLError(.timedOut)
      }
      $0.api.getCuratorEpisode = { _, _ in committed }
      $0.api.moveAiring = { _, airingId, _ in requests.withValue { $0.append("move \(airingId)") } }
    }
    coordinator.presentedSheet = .addShowToSeries(model)
    await model.addButtonTapped("tour-stories")
    guard case .scheduleShow(let schedule) = coordinator.presentedSheet else {
      Issue.record("Expected the Schedule sheet")
      return
    }

    await schedule.scheduleButtonTapped()
    schedule.pickedTime = nearSlot.addingTimeInterval(3600)
    await schedule.scheduleButtonTapped()

    expectNoDifference(requests.value, ["schedule", "move tour-stories-airing-0"])
  }

  @Test func aRetryAtTheTimeAFailedScheduleCommittedGoesStraightToTheJoin() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let requests = LockIsolated<[String]>([])
    let committed = episode("tour-stories", title: "Tour Stories", at: [nearSlot])
    let model = await makeModel(slot: nearSlot, episodes: [tourStories]) {
      $0.api.scheduleEpisode = { _, _, _, _ in
        requests.withValue { $0.append("schedule") }
        throw URLError(.timedOut)
      }
      $0.api.getCuratorEpisode = { _, _ in committed }
      $0.api.moveAiring = { _, _, _ in
        requests.withValue { $0.append("move") }
        throw APIError.recordedShowLocked("Locked.")
      }
      $0.api.updateEpisode = { _, _, _ in
        requests.withValue { $0.append("join") }
        return committed
      }
    }
    coordinator.presentedSheet = .addShowToSeries(model)
    await model.addButtonTapped("tour-stories")
    guard case .scheduleShow(let schedule) = coordinator.presentedSheet else {
      Issue.record("Expected the Schedule sheet")
      return
    }

    await schedule.scheduleButtonTapped()
    await schedule.scheduleButtonTapped()

    expectNoDifference(requests.value, ["schedule", "join"])
    expectNoDifference(coordinator.presentedSheet, nil)
  }

  @Test func aFailedRefetchAfterAFailedScheduleIsReported() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let endpoints = LockIsolated<[String]>([])
    let model = await makeModel(slot: nearSlot, episodes: [tourStories]) {
      $0.api.scheduleEpisode = { _, _, _, _ in throw AddShowTestError() }
      $0.api.getCuratorEpisode = { _, _ in throw AddShowTestError() }
      $0.errorReporting.reportError = { _, tags in
        endpoints.withValue { $0.append(tags["endpoint"] ?? "nil") }
      }
    }
    coordinator.presentedSheet = .addShowToSeries(model)
    await model.addButtonTapped("tour-stories")
    guard case .scheduleShow(let schedule) = coordinator.presentedSheet else {
      Issue.record("Expected the Schedule sheet")
      return
    }

    await schedule.scheduleButtonTapped()

    expectNoDifference(endpoints.value, ["scheduleInSeriesSlot", "getCuratorEpisode"])
  }

  @Test func cancellingTheScheduleSheetBeforeSchedulingDoesNothing() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let requests = LockIsolated(0)
    let finishes = LockIsolated<[AddShowToSeriesFailure?]>([])
    let model = await makeModel(slot: nearSlot, episodes: [tourStories], finishes: finishes) {
      $0.api.scheduleEpisode = { _, _, _, _ in requests.withValue { $0 += 1 } }
      $0.api.updateEpisode = { [tourStories] _, _, _ in
        requests.withValue { $0 += 1 }
        return tourStories
      }
    }
    coordinator.presentedSheet = .addShowToSeries(model)
    await model.addButtonTapped("tour-stories")
    model.dismissed()
    guard case .scheduleShow(let schedule) = coordinator.presentedSheet else {
      Issue.record("Expected the Schedule sheet")
      return
    }

    schedule.cancelButtonTapped()
    schedule.dismissed()

    expectNoDifference(coordinator.presentedSheet, nil)
    expectNoDifference(requests.value, 0)
    expectNoDifference(finishes.value.count, 0)
  }

  // MARK: - Record a New Show

  @Test func recordNewShowFromASlotPushesTheBuilderForTheSeriesAndSlot() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let requests = LockIsolated(0)
    let model = await makeModel(slot: slot) {
      $0.api.scheduleEpisode = { _, _, _, _ in requests.withValue { $0 += 1 } }
      $0.api.createEpisodeInSeries = { _, _, _ in
        requests.withValue { $0 += 1 }
        throw AddShowTestError()
      }
    }
    coordinator.presentedSheet = .addShowToSeries(model)

    model.recordNewShowTapped()

    expectNoDifference(coordinator.presentedSheet, nil)
    guard case .showBuilderPage(let builder) = coordinator.path.last else {
      Issue.record("Expected the builder")
      return
    }
    expectNoDifference(builder.episodeId, nil)
    expectNoDifference(builder.seriesId, "s1")
    expectNoDifference(builder.slot, slot)
    expectNoDifference(builder.stationId, stationId)
    expectNoDifference(requests.value, 0)
  }

  @Test func recordNewShowWithNoSlotPushesTheBuilderWithNoSlot() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = await makeModel(slot: nil)
    coordinator.presentedSheet = .addShowToSeries(model)

    model.recordNewShowTapped()

    guard case .showBuilderPage(let builder) = coordinator.path.last else {
      Issue.record("Expected the builder")
      return
    }
    expectNoDifference(builder.seriesId, "s1")
    expectNoDifference(builder.slot, nil)
    expectNoDifference(model.recordNewShowSubtitle, "Start from scratch")
  }
}
