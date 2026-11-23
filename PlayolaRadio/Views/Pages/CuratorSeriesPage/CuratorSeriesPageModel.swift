//
//  CuratorSeriesPageModel.swift
//  PlayolaRadio
//
//  One Series for its curator: its drafts, its upcoming Shows and its next open slots.
//

import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

struct CuratorSeriesDraftRow: Identifiable, Equatable {
  let id: String
  let title: String
  let subtitle: String
}

struct CuratorSeriesUpcomingRow: Identifiable {
  enum Kind {
    case show(episodeId: String)
    case slot
  }

  struct Tile {
    let date: Date
    let timeZone: TimeZone
  }

  struct ShowContent: Identifiable {
    let id: String
    let episodeId: String
    let title: String
    let subtitle: String
    let tile: Tile
  }

  struct SlotContent: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let addButtonTitle: String
    let tile: Tile
  }

  let id: String
  let date: Date
  let timeZone: TimeZone
  let title: String
  let subtitle: String
  let kind: Kind

  var shows: [ShowContent] {
    guard case .show(let episodeId) = kind else { return [] }
    return [
      ShowContent(id: id, episodeId: episodeId, title: title, subtitle: subtitle, tile: tile)
    ]
  }

  var slots: [SlotContent] {
    guard case .slot = kind else { return [] }
    return [
      SlotContent(
        id: id, title: title, subtitle: subtitle, addButtonTitle: "Add show", tile: tile)
    ]
  }

  private var tile: Tile { Tile(date: date, timeZone: timeZone) }
}

@MainActor
@Observable
class CuratorSeriesPageModel: ViewModel {

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

  init(stationId: String, series: CuratorSeries) {
    self.stationId = stationId
    self.series = series
    super.init()
  }

  // MARK: - Properties

  static let slotLimit = 8

  let stationId: String
  var series: CuratorSeries
  var episodes: [CuratorEpisode] = []
  var airings: [Airing] = []
  var settings: StationSchedulingSettings?
  var isLoading = false
  var hasLoaded = false
  var presentedAlert: PlayolaAlert?
  @ObservationIgnored private var isLoadingStationSchedule = false
  /// Counts loads so an older one that finishes late can't overwrite a newer one's result.
  @ObservationIgnored private var latestLoad = 0

  var navigationTitle: String { series.title }
  var editButtonTitle: String { "Edit" }
  var draftsHeader: String { "NOT SCHEDULED YET" }
  var upcomingHeader: String { "UPCOMING" }
  var addShowButtonTitle: String { "Add a Show" }
  var loadErrorMessage: String { "This series couldn\u{2019}t load." }
  var isProgressVisible: Bool { isLoading && !hasLoaded }
  var loadingOpacity: Double { isProgressVisible ? 1 : 0 }

  // MARK: - User Actions

  func viewAppeared() async {
    await loadSeries()
  }

  func observeRecordedShowsChanges(onReady: @escaping @MainActor () -> Void = {}) async {
    let notifications = notificationCenter.notifications(named: .recordedShowsChanged)
    onReady()
    for await notification in notifications {
      guard !Task.isCancelled else { return }
      guard notification.userInfo?["stationId"] as? String == stationId else { continue }
      await loadSeries()
    }
  }

  func editButtonTapped() {
    let details = withDependencies(from: self) {
      SeriesDetailsSheetModel(stationId: stationId, timeZone: timeZone, editing: series)
    }
    details.onSaved = { [weak self, weak details] _ in self?.dismiss(details) }
    details.onCancel = { [weak self, weak details] in self?.dismiss(details) }
    navigationCoordinator.presentedSheet = .seriesDetails(details)
  }

  func showTapped(_ episodeId: String) {
    navigationCoordinator.push(
      .showBuilderPage(
        ShowBuilderPageModel(stationId: stationId, episodeId: episodeId, seriesId: nil, slot: nil)))
  }

  /// A slot only exists once settings and airings have loaded, so they are always here.
  func addShowTapped(slot: Date) {
    guard let settings else { return }
    presentAddShow(slot: slot, settings: settings)
  }

  /// After a failed first load, loads the station's settings and airings before presenting.
  func addAShowButtonTapped() async {
    guard !isLoadingStationSchedule else { return }
    if let settings {
      presentAddShow(slot: nil, settings: settings)
      return
    }
    guard let token = auth.jwt else { return }
    isLoadingStationSchedule = true
    defer { isLoadingStationSchedule = false }
    do {
      async let loadedAirings = api.getAirings(token, stationId)
      async let loadedSettings = api.getStationSchedulingSettings(token, stationId)
      let (newAirings, newSettings) = try await (loadedAirings, loadedSettings)
      airings = newAirings
      settings = newSettings
      presentAddShow(slot: nil, settings: newSettings)
    } catch {
      await loadFailed(error, endpoint: "curatorSeriesPageAddShow")
    }
  }

  // MARK: - View Helpers

  var timeZone: TimeZone {
    settings?.timeZone
      ?? TimeZone(identifier: StationSchedulingSettings.fallbackTimeZoneIdentifier) ?? .gmt
  }

  var scheduleBadges: [String] {
    CuratorSeriesUpcoming.scheduleBadge(for: series).map { [$0] } ?? []
  }

  var slotsNotes: [String] {
    guard series.rrule.flatMap(SeriesSchedule.init(rrule:)) != nil else { return [] }
    return ["Open slots are only suggestions. If you leave one empty, your station plays as usual."]
  }

  var draftRows: IdentifiedArrayOf<CuratorSeriesDraftRow> {
    IdentifiedArray(
      uniqueElements: episodes.filter { $0.showId == series.id && $0.isDraft }.map { episode in
        CuratorSeriesDraftRow(
          id: episode.id, title: episode.title,
          subtitle: ["Not scheduled yet", episode.lengthLabel].compactMap { $0 }
            .joined(separator: " \u{00B7} "))
      })
  }

  var draftsEmptyMessages: [String] { draftRows.isEmpty ? ["No drafts in this series."] : [] }

  var upcomingRows: IdentifiedArrayOf<CuratorSeriesUpcomingRow> {
    let upcoming = CuratorSeriesUpcoming(
      episodes: episodes, airings: airings, timeZone: timeZone, now: now)
    // Until the station's airings have loaded, no time can be known to be open.
    let entries = upcoming.entries(for: series, slotLimit: hasLoaded ? Self.slotLimit : 0)
    return IdentifiedArray(uniqueElements: entries.map(row(for:)))
  }

  var upcomingEmptyMessages: [String] { upcomingRows.isEmpty ? ["No upcoming shows."] : [] }

  // MARK: - Private Helpers

  private func row(for entry: CuratorSeriesUpcomingEntry) -> CuratorSeriesUpcomingRow {
    switch entry {
    case .show(let episode, let airing):
      return CuratorSeriesUpcomingRow(
        id: "show-\(episode.id)", date: airing.airtime, timeZone: timeZone, title: episode.title,
        subtitle: [dayAndTime(airing.airtime), episode.lengthLabel].compactMap { $0 }
          .joined(separator: " \u{00B7} "),
        kind: .show(episodeId: episode.id))
    case .slot(let date):
      return CuratorSeriesUpcomingRow(
        id: "slot-\(date.timeIntervalSince1970)", date: date, timeZone: timeZone, title: "Open",
        subtitle: dayAndTime(date), kind: .slot)
    }
  }

  /// "Sunday · 7:00 PM".
  private func dayAndTime(_ date: Date) -> String {
    let day = CuratorSeriesUpcoming.formatted(date, "EEEE", in: timeZone)
    let time = CuratorSeriesUpcoming.formatted(date, "h:mm a", in: timeZone)
    return "\(day) \u{00B7} \(time)"
  }

  private func presentAddShow(slot: Date?, settings: StationSchedulingSettings) {
    let sheet = withDependencies(from: self) {
      AddShowToSeriesSheetModel(
        stationId: stationId, series: series, slot: slot, settings: settings, airings: airings,
        onAddFinished: { [weak self] failure in self?.presentedAlert = failure?.alert })
    }
    navigationCoordinator.presentedSheet = .addShowToSeries(sheet)
  }

  private func dismiss(_ details: SeriesDetailsSheetModel?) {
    guard let details, case .seriesDetails(let presented) = navigationCoordinator.presentedSheet,
      presented === details
    else { return }
    $navigationCoordinator.withLock { $0.presentedSheet = nil }
  }

  private func loadSeries() async {
    guard let token = auth.jwt else { return }
    latestLoad += 1
    let thisLoad = latestLoad
    isLoading = true
    defer { isLoading = false }
    do {
      async let loadedSeries = api.getCuratorSeriesById(token, series.id)
      async let loadedEpisodes = api.getCuratorEpisodes(token, nil, series.id)
      async let loadedAirings = api.getAirings(token, stationId)
      async let loadedSettings = api.getStationSchedulingSettings(token, stationId)
      let (newSeries, newEpisodes, newAirings, newSettings) = try await (
        loadedSeries, loadedEpisodes, loadedAirings, loadedSettings
      )
      guard !Task.isCancelled, thisLoad == latestLoad else { return }
      series = newSeries
      episodes = newEpisodes
      airings = newAirings
      settings = newSettings
      hasLoaded = true
    } catch {
      await loadFailed(error, endpoint: "curatorSeriesPage")
    }
  }

  private func loadFailed(_ error: Error, endpoint: String) async {
    guard !Task.isCancelled, !(error is CancellationError),
      (error as? URLError)?.code != .cancelled
    else { return }
    if !NetworkErrorClassifier.isNetworkError(error) {
      var tags = NetworkErrorClassifier.errorTags(for: error)
      tags["endpoint"] = endpoint
      await errorReporting.reportError(error, tags)
    }
    guard !Task.isCancelled else { return }
    await toast.show(PlayolaToast(message: loadErrorMessage, buttonTitle: "OK"))
  }
}
