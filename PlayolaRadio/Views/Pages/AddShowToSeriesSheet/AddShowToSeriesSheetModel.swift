//
//  AddShowToSeriesSheetModel.swift
//  PlayolaRadio
//
//  Fills a Series' open slot (or, with no slot, just the Series) with a new Show or one of the
//  curator's existing Shows. UX "Show" = server `Episode`; UX "Series" = server `Show`.
//

import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

/// Why an add didn't fully go through, for the presenter's alert once the sheet has closed.
struct AddShowToSeriesFailure: Equatable {
  let title: String
  let message: String

  @MainActor var alert: PlayolaAlert {
    PlayolaAlert(title: title, message: message, dismissButton: .cancel(Text("OK")))
  }
}

struct AddShowToSeriesRow: Identifiable {
  struct Tile {
    let date: Date
    let timeZone: TimeZone
  }

  struct DraftContent: Identifiable {
    let id: String
  }

  struct ScheduledContent: Identifiable {
    let id: String
    let tile: Tile
  }

  let id: String
  let title: String
  let subtitle: String
  let airtime: Date?
  let timeZone: TimeZone
  let isBusy: Bool
  let isAddEnabled: Bool

  var drafts: IdentifiedArrayOf<DraftContent> { airtime == nil ? [DraftContent(id: id)] : [] }

  var scheduled: IdentifiedArrayOf<ScheduledContent> {
    airtime.map { [ScheduledContent(id: id, tile: Tile(date: $0, timeZone: timeZone))] } ?? []
  }

  var addButtonTitles: [String] { isBusy ? [] : ["Add"] }

  var addButtonAccessibilityLabel: String { "Add \(title)" }

  var busySpinners: [String] { isBusy ? ["busy"] : [] }

  var addButtonOpacity: Double { isAddEnabled ? 1 : 0.4 }
}

@MainActor
@Observable
class AddShowToSeriesSheetModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.errorReporting) var errorReporting
  @ObservationIgnored @Dependency(\.notificationCenter) var notificationCenter
  @ObservationIgnored @Dependency(\.toast) var toast

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(
    stationId: String,
    series: CuratorSeries,
    slot: Date?,
    settings: StationSchedulingSettings,
    airings: [Airing],
    onAddFinished: @escaping @MainActor (AddShowToSeriesFailure?) -> Void
  ) {
    self.stationId = stationId
    self.series = series
    self.slot = slot
    self.settings = settings
    self.airings = airings
    self.onAddFinished = onAddFinished
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  let series: CuratorSeries
  let slot: Date?
  let settings: StationSchedulingSettings
  let airings: [Airing]
  var episodes: [CuratorEpisode] = []
  var isLoading = true
  var busyEpisodeId: String?
  @ObservationIgnored private let onAddFinished: @MainActor (AddShowToSeriesFailure?) -> Void
  /// The add has moved to the Schedule sheet, so this sheet's own dismissal doesn't count.
  @ObservationIgnored private var isHandingOff = false
  @ObservationIgnored private var hasRunSteps = false
  @ObservationIgnored private var isRunningSteps = false
  @ObservationIgnored private var isStepsSheetDismissed = false
  @ObservationIgnored private var hasFinished = false
  @ObservationIgnored private var keptFailure: AddShowToSeriesFailure?

  var title: String { "Add a show" }
  var recordNewShowTitle: String { "Record a New Show" }
  var recordNewShowSubtitle: String {
    slot == nil ? "Start from scratch" : "Start from scratch for this slot"
  }
  var loadErrorMessage: String { "Your shows couldn\u{2019}t load." }

  // MARK: - User Actions

  func viewAppeared() async {
    guard let jwt = auth.jwt else {
      isLoading = false
      return
    }
    defer { isLoading = false }
    do {
      episodes = try await api.getCuratorEpisodes(jwt, stationId, nil)
    } catch {
      guard !isCancellation(error) else { return }
      await report(error, endpoint: "getCuratorEpisodes")
      await toast.show(PlayolaToast(message: loadErrorMessage, buttonTitle: "OK"))
    }
  }

  func recordNewShowTapped() {
    guard busyEpisodeId == nil, !isHandingOff else { return }
    dismissSheet()
    navigationCoordinator.push(
      .showBuilderPage(
        ShowBuilderPageModel(stationId: stationId, episodeId: nil, seriesId: series.id, slot: slot)
      ))
  }

  func addButtonTapped(_ episodeId: String) async {
    guard busyEpisodeId == nil, !isHandingOff,
      let episode = offeredEpisodes.first(where: { $0.id == episodeId })
    else { return }
    if let slot, slot < lockEdge {
      handOffToScheduleSheet(episode, slot: slot)
      return
    }
    busyEpisodeId = episodeId
    hasRunSteps = true
    isRunningSteps = true
    keptFailure = await addToSeries(episode, at: slot)
    isRunningSteps = false
    postRecordedShowsChanged()
    dismissSheet()
    finishIfSettled()
  }

  /// Called once SwiftUI has finished dismissing this sheet.
  func dismissed() {
    guard !isHandingOff else { return }
    isStepsSheetDismissed = true
    finishIfSettled()
  }

  // MARK: - View Helpers

  var subtitle: String {
    guard let slot else { return series.title }
    let day = CuratorSeriesUpcoming.formatted(slot, "EEEE, MMM d", in: timeZone)
    let time = CuratorSeriesUpcoming.shortTime(slot, in: timeZone)
    return "\(series.title) \u{00B7} \(day) at \(time)"
  }

  var timeZone: TimeZone { settings.timeZone }

  var loadingSpinners: [String] { isLoading ? ["loading"] : [] }

  var listHeaders: [String] { rows.isEmpty ? [] : ["OR ADD ONE OF YOUR SHOWS"] }

  var rows: IdentifiedArrayOf<AddShowToSeriesRow> {
    guard !isLoading else { return [] }
    return IdentifiedArray(uniqueElements: offeredEpisodes.map(row(for:)))
  }

  var isRecordNewShowEnabled: Bool { busyEpisodeId == nil }

  var recordNewShowOpacity: Double { isRecordNewShowEnabled ? 1 : 0.5 }

  var isSwipeDismissDisabled: Bool { busyEpisodeId != nil }

  // MARK: - Private Helpers

  private var lockEdge: Date { now.addingTimeInterval(Double(settings.airingEditLockMS) / 1000) }

  /// Drafts with audio in server order, then unlocked single-airing scheduled Shows by air time.
  /// Never this Series' own Shows, nor Shows scheduled on another station.
  private var offeredEpisodes: [CuratorEpisode] {
    let candidates = episodes.filter { $0.showId != series.id && !$0.isMultiAiring }
    let drafts = candidates.filter { episode in
      guard case .draft = state(of: episode) else { return false }
      return episode.hasAudio
    }
    let scheduled = candidates.compactMap { episode -> (CuratorEpisode, Date)? in
      guard case .scheduled(let airing) = state(of: episode), airing.stationId == stationId
      else { return nil }
      return (episode, airing.airtime)
    }
    .enumerated()
    .sorted { ($0.element.1, $0.offset) < ($1.element.1, $1.offset) }
    .map(\.element.0)
    return drafts + scheduled
  }

  private func state(of episode: CuratorEpisode) -> CuratorEpisodeState {
    episode.state(now: now, lockMS: settings.airingEditLockMS)
  }

  private func row(for episode: CuratorEpisode) -> AddShowToSeriesRow {
    let airtime = episode.upcomingAiring(now: now)?.airtime
    let lead: String
    if let airtime {
      let day = CuratorSeriesUpcoming.formatted(airtime, "EEE, MMM d", in: timeZone)
      lead = slot == nil ? day : "Moves here from \(day)"
    } else {
      lead = "Not scheduled yet"
    }
    return AddShowToSeriesRow(
      id: episode.id, title: episode.title,
      subtitle: [lead, episode.lengthLabel].compactMap { $0 }.joined(separator: " \u{00B7} "),
      airtime: airtime, timeZone: timeZone, isBusy: busyEpisodeId == episode.id,
      isAddEnabled: busyEpisodeId == nil)
  }

  private func handOffToScheduleSheet(_ episode: CuratorEpisode, slot: Date) {
    isHandingOff = true
    // The Schedule sheet holds this model strongly: once it replaces this sheet, it is the only
    // thing keeping the add (and its onAddFinished) alive.
    let sheet = withDependencies(from: self) {
      ScheduleShowSheetModel(
        episode: episode, series: series, settings: settings,
        occupiedIntervals: occupiedIntervals(from: airings, excludingEpisodeId: episode.id),
        initialTime: slot,
        schedule: { airtime in try await self.scheduleFromScheduleSheet(episode.id, at: airtime) },
        dismissed: {
          self.isStepsSheetDismissed = true
          self.finishIfSettled()
        })
    }
    $navigationCoordinator.withLock { $0.presentedSheet = .scheduleShow(sheet) }
  }

  /// The Schedule sheet's closure: a step 1 refusal throws so the sheet shows it inline and stays
  /// open; a join failure is kept for the alert after the sheet closes. A failed step 1 may still
  /// have committed, so the Show is refetched first: a retry then moves that airing rather than
  /// creating a second one, or, if it's already at the picked time, goes straight to the join.
  private func scheduleFromScheduleSheet(_ episodeId: String, at airtime: Date) async throws {
    guard let episode = episodes.first(where: { $0.id == episodeId }) else { return }
    hasRunSteps = true
    isRunningSteps = true
    defer {
      isRunningSteps = false
      finishIfSettled()
    }
    guard let jwt = auth.jwt else { throw AddShowToSeriesNotSignedIn() }
    do {
      try await moveOrSchedule(episode, at: airtime, jwt: jwt)
    } catch {
      if !isCancellation(error) { await report(error, endpoint: "scheduleInSeriesSlot") }
      await refreshEpisode(episodeId, jwt: jwt)
      postRecordedShowsChanged()
      throw error
    }
    keptFailure = await join(episode, jwt: jwt, failureTitle: scheduledButNotInSeriesTitle)
    postRecordedShowsChanged()
  }

  private func refreshEpisode(_ episodeId: String, jwt: String) async {
    do {
      let fresh = try await api.getCuratorEpisode(jwt, episodeId)
      guard let index = episodes.firstIndex(where: { $0.id == episodeId }) else { return }
      episodes[index] = fresh
    } catch {
      if !isCancellation(error) { await report(error, endpoint: "getCuratorEpisode") }
    }
  }

  /// Step 1 (schedule or move to the slot) and, only if it succeeds, step 2 (join the Series).
  /// With no slot only step 2 runs.
  private func addToSeries(_ episode: CuratorEpisode, at slot: Date?) async
    -> AddShowToSeriesFailure?
  {
    guard let jwt = auth.jwt else {
      return AddShowToSeriesFailure(
        title: couldNotAddTitle, message: AddShowToSeriesNotSignedIn().localizedDescription)
    }
    guard let slot else { return await join(episode, jwt: jwt, failureTitle: couldNotAddTitle) }
    do {
      try await moveOrSchedule(episode, at: slot, jwt: jwt)
    } catch {
      guard !isCancellation(error) else { return nil }
      await report(error, endpoint: "scheduleInSeriesSlot")
      let title = (error as? APIError).map(isLocked) == true ? "Show Locked" : couldNotAddTitle
      return AddShowToSeriesFailure(title: title, message: error.localizedDescription)
    }
    return await join(episode, jwt: jwt, failureTitle: scheduledButNotInSeriesTitle)
  }

  private func moveOrSchedule(_ episode: CuratorEpisode, at airtime: Date, jwt: String)
    async throws
  {
    if let airing = episode.upcomingAiring(now: now) {
      // Already there (an earlier attempt committed); moving it again would hit the lock.
      guard airing.airtime != airtime else { return }
      try await api.moveAiring(jwt, airing.id, airtime)
    } else {
      try await api.scheduleEpisode(jwt, episode.id, stationId, airtime)
    }
  }

  private func join(_ episode: CuratorEpisode, jwt: String, failureTitle: String) async
    -> AddShowToSeriesFailure?
  {
    do {
      _ = try await api.updateEpisode(
        jwt, episode.id, CuratorEpisodeUpdate(series: .join(series.id)))
      return nil
    } catch {
      guard !isCancellation(error) else { return nil }
      await report(error, endpoint: "joinSeries")
      return AddShowToSeriesFailure(title: failureTitle, message: error.localizedDescription)
    }
  }

  private var couldNotAddTitle: String { "Couldn\u{2019}t Add" }

  private var scheduledButNotInSeriesTitle: String { "Scheduled, but Not in \(series.title)" }

  private func isLocked(_ error: APIError) -> Bool {
    if case .recordedShowLocked = error { return true }
    return false
  }

  /// onAddFinished runs once, after the steps have ended and the sheet that ran them is gone.
  private func finishIfSettled() {
    guard hasRunSteps, !isRunningSteps, isStepsSheetDismissed, !hasFinished else { return }
    hasFinished = true
    onAddFinished(keptFailure)
  }

  private func dismissSheet() {
    guard case .addShowToSeries(let presented) = navigationCoordinator.presentedSheet,
      presented === self
    else { return }
    $navigationCoordinator.withLock { $0.presentedSheet = nil }
  }

  private func postRecordedShowsChanged() {
    notificationCenter.post(
      name: .recordedShowsChanged, object: nil, userInfo: ["stationId": stationId])
  }

  private func report(_ error: Error, endpoint: String) async {
    guard !NetworkErrorClassifier.isNetworkError(error) else { return }
    var tags = NetworkErrorClassifier.errorTags(for: error)
    tags["endpoint"] = endpoint
    await errorReporting.reportError(error, tags)
  }

  private func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
  }
}

struct AddShowToSeriesNotSignedIn: LocalizedError {
  var errorDescription: String? { "You\u{2019}re not signed in." }
}
