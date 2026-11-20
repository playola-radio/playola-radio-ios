//
//  CuratorSeriesListPageModel.swift
//  PlayolaRadio
//
//  The curator's list of a station's Series (backend `Show`s), each card showing its next Shows
//  and open weekly slots. Named apart from the listener app's `SeriesListPage`.
//

import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

/// One thing coming up in a Series: a scheduled Show at its next airing, or an open slot.
enum CuratorSeriesUpcomingEntry {
  case show(CuratorEpisode, airing: CuratorAiring)
  case slot(Date)

  var date: Date {
    switch self {
    case .show(_, let airing): return airing.airtime
    case .slot(let date): return date
    }
  }
}

/// Shared by the Series list and the Series page so both read a Series' future the same way.
struct CuratorSeriesUpcoming {
  let episodes: [CuratorEpisode]
  let airings: [Airing]
  let timeZone: TimeZone
  let now: Date

  static func scheduleBadge(for series: CuratorSeries) -> String? {
    guard let rrule = series.rrule else { return nil }
    return SeriesSchedule(rrule: rrule)?.text ?? "Custom schedule"
  }

  static func formatted(_ date: Date, _ format: String, in timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = format
    return formatter.string(from: date)
  }

  /// The Series' upcoming Shows (each once, at its next airing; aired Shows and drafts never) and
  /// up to `slotLimit` open slots no station Airing covers, merged by date.
  func entries(for series: CuratorSeries, slotLimit: Int) -> [CuratorSeriesUpcomingEntry] {
    let shows: [CuratorSeriesUpcomingEntry] = episodes.filter { $0.showId == series.id }
      .compactMap { episode in
        episode.upcomingAiring(now: now).map { .show(episode, airing: $0) }
      }
    let slots: [CuratorSeriesUpcomingEntry] =
      series.rrule.flatMap(SeriesSchedule.init(rrule:))?
      .openSlots(
        after: now, in: timeZone, occupiedIntervals: occupiedIntervals(from: airings),
        limit: slotLimit
      )
      .map { .slot($0) } ?? []
    return (shows + slots).enumerated()
      .sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
      .map(\.element)
  }
}

struct CuratorSeriesCardItem: Identifiable {
  enum Kind: Equatable {
    case show(episodeId: String, title: String)
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
    let subtitle: String
    let addButtonTitle: String
    let tile: Tile
  }

  let id: String
  let date: Date
  let timeZone: TimeZone
  let subtitle: String
  let kind: Kind

  var shows: [ShowContent] {
    guard case .show(let episodeId, let title) = kind else { return [] }
    return [
      ShowContent(id: id, episodeId: episodeId, title: title, subtitle: subtitle, tile: tile)
    ]
  }

  var slots: [SlotContent] {
    guard case .slot = kind else { return [] }
    return [SlotContent(id: id, subtitle: subtitle, addButtonTitle: "Add show", tile: tile)]
  }

  private var tile: Tile { Tile(date: date, timeZone: timeZone) }
}

struct CuratorSeriesCard: Identifiable {
  let series: CuratorSeries
  let badges: [String]
  let countLabels: [String]
  let items: IdentifiedArrayOf<CuratorSeriesCardItem>
  let emptyMessages: [String]

  var id: String { series.id }
  var title: String { series.title }
  var upcomingHeader: String { "UPCOMING SHOWS" }
}

@MainActor
@Observable
class CuratorSeriesListPageModel: ViewModel {

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

  init(stationId: String) {
    self.stationId = stationId
    super.init()
  }

  // MARK: - Properties

  static let itemsPerCard = 3

  let stationId: String
  var series: [CuratorSeries] = []
  var episodes: [CuratorEpisode] = []
  var airings: [Airing] = []
  var settings: StationSchedulingSettings?
  var isLoading = false
  var hasLoaded = false
  /// Counts loads so an older one that finishes late can't overwrite a newer one's result.
  @ObservationIgnored private var latestLoad = 0

  var navigationTitle: String { "Series" }
  var createButtonTitle: String { "Create a New Series" }
  var loadErrorMessage: String { "Series couldn\u{2019}t load." }
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

  func seriesNameTapped(_ card: CuratorSeriesCard) {
    navigationCoordinator.push(
      .curatorSeriesPage(CuratorSeriesPageModel(stationId: stationId, series: card.series)))
  }

  func showTapped(_ episodeId: String) {
    navigationCoordinator.push(
      .showBuilderPage(
        ShowBuilderPageModel(stationId: stationId, episodeId: episodeId, seriesId: nil, slot: nil)))
  }

  func addShowTapped(slot: Date) {}

  func createSeriesButtonTapped() {
    let details = withDependencies(from: self) {
      SeriesDetailsSheetModel(stationId: stationId, timeZone: timeZone)
    }
    details.onSaved = { [weak self, weak details] _ in self?.dismiss(details) }
    details.onCancel = { [weak self, weak details] in self?.dismiss(details) }
    navigationCoordinator.presentedSheet = .seriesDetails(details)
  }

  // MARK: - View Helpers

  var timeZone: TimeZone {
    settings?.timeZone
      ?? TimeZone(identifier: StationSchedulingSettings.fallbackTimeZoneIdentifier) ?? .gmt
  }

  var cards: IdentifiedArrayOf<CuratorSeriesCard> {
    IdentifiedArray(uniqueElements: series.filter { !$0.isOneTime }.map(card(for:)))
  }

  // MARK: - Private Helpers

  private var upcoming: CuratorSeriesUpcoming {
    CuratorSeriesUpcoming(episodes: episodes, airings: airings, timeZone: timeZone, now: now)
  }

  private func card(for series: CuratorSeries) -> CuratorSeriesCard {
    let entries = upcoming.entries(for: series, slotLimit: Self.itemsPerCard)
      .prefix(Self.itemsPerCard)
    let items = entries.map(item(for:))
    let countLabel = Self.countLabel(
      shows: items.filter { $0.kind != .slot }.count, open: items.filter { $0.kind == .slot }.count)
    return CuratorSeriesCard(
      series: series, badges: CuratorSeriesUpcoming.scheduleBadge(for: series).map { [$0] } ?? [],
      countLabels: countLabel.map { [$0] } ?? [],
      items: IdentifiedArray(uniqueElements: items),
      emptyMessages: items.isEmpty ? ["No upcoming shows."] : [])
  }

  private func item(for entry: CuratorSeriesUpcomingEntry) -> CuratorSeriesCardItem {
    switch entry {
    case .show(let episode, let airing):
      return CuratorSeriesCardItem(
        id: "show-\(episode.id)", date: airing.airtime, timeZone: timeZone,
        subtitle: "\(dayText(airing.airtime)) at \(timeText(airing.airtime))",
        kind: .show(episodeId: episode.id, title: episode.title))
    case .slot(let date):
      return CuratorSeriesCardItem(
        id: "slot-\(date.timeIntervalSince1970)", date: date, timeZone: timeZone,
        subtitle: "\(dayText(date)) \u{00B7} open", kind: .slot)
    }
  }

  /// "Sunday the 8th".
  private func dayText(_ date: Date) -> String {
    let weekday = CuratorSeriesUpcoming.formatted(date, "EEEE", in: timeZone)
    let day = Int(CuratorSeriesUpcoming.formatted(date, "d", in: timeZone)) ?? 0
    return "\(weekday) the \(Self.ordinal(day))"
  }

  /// "7pm", or "7:30pm".
  private func timeText(_ date: Date) -> String {
    let minutes = CuratorSeriesUpcoming.formatted(date, "mm", in: timeZone)
    let hour = CuratorSeriesUpcoming.formatted(date, "h", in: timeZone)
    let suffix = CuratorSeriesUpcoming.formatted(date, "a", in: timeZone).lowercased()
    return minutes == "00" ? "\(hour)\(suffix)" : "\(hour):\(minutes)\(suffix)"
  }

  private static func ordinal(_ day: Int) -> String {
    let suffix: String
    switch (day % 10, day % 100) {
    case (_, 11...13): suffix = "th"
    case (1, _): suffix = "st"
    case (2, _): suffix = "nd"
    case (3, _): suffix = "rd"
    default: suffix = "th"
    }
    return "\(day)\(suffix)"
  }

  private static func countLabel(shows: Int, open: Int) -> String? {
    var parts: [String] = []
    if shows > 0 { parts.append(shows == 1 ? "1 show" : "\(shows) shows") }
    if open > 0 { parts.append("\(open) open") }
    return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
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
      async let loadedSeries = api.getCuratorSeries(token, stationId)
      async let loadedEpisodes = api.getCuratorEpisodes(token, stationId, nil)
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
      guard !Task.isCancelled, !(error is CancellationError),
        (error as? URLError)?.code != .cancelled
      else { return }
      if !NetworkErrorClassifier.isNetworkError(error) {
        var tags = NetworkErrorClassifier.errorTags(for: error)
        tags["endpoint"] = "curatorSeriesList"
        await errorReporting.reportError(error, tags)
      }
      guard !Task.isCancelled else { return }
      await toast.show(PlayolaToast(message: loadErrorMessage, buttonTitle: "OK"))
    }
  }
}
