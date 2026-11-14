//
//  IndividualShowsPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Sharing
import SwiftUI

struct IndividualShowRow: Identifiable, Equatable {
  enum Kind: Equatable {
    case draft
    case scheduled(airtime: Date, timeZone: TimeZone)
  }

  let id: String
  let title: String
  let subtitle: String
  let seriesBadges: [String]
  let kind: Kind
}

@MainActor
@Observable
class IndividualShowsPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.errorReporting) var errorReporting
  @ObservationIgnored @Dependency(\.toast) var toast

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth

  // MARK: - Initialization

  init(stationId: String) {
    self.stationId = stationId
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  var episodes: [CuratorEpisode] = []
  var series: [CuratorSeries] = []
  var timeZone: TimeZone = .gmt
  var isLoading = false
  var hasLoaded = false

  var navigationTitle: String { "Individual Shows" }
  var recordNewShowButtonTitle: String { "Record a New Show" }
  var emptyStateTitle: String { "No shows scheduled" }
  var emptyStateMessage: String { "Record a show and pick when it airs. It'll show up here." }
  var loadingOpacity: Double { isLoading ? 1 : 0 }
  var isEmptyStateVisible: Bool { hasLoaded && rows.isEmpty }
  var emptyStateOpacity: Double { isEmptyStateVisible ? 1 : 0 }

  // MARK: - User Actions

  func viewAppeared() async {
    await loadShows()
  }

  func showRowTapped(_ row: IndividualShowRow) {}

  func recordNewShowButtonTapped() {}

  // MARK: - View Helpers

  var rows: [IndividualShowRow] {
    let drafts = episodes.filter(\.isDraft).map { draftRow(for: $0) }
    let scheduled = episodes.compactMap { episode in
      episode.upcomingAiring(now: now).map { (episode: episode, airing: $0) }
    }
    .sorted { $0.airing.airtime < $1.airing.airtime }
    .map { scheduledRow(for: $0.episode, airing: $0.airing) }
    return drafts + scheduled
  }

  // MARK: - Private Helpers

  private func draftRow(for episode: CuratorEpisode) -> IndividualShowRow {
    IndividualShowRow(
      id: episode.id, title: episode.title,
      subtitle: ["Not scheduled yet", lengthLabel(for: episode)].compactMap { $0 }
        .joined(separator: " · "),
      seriesBadges: seriesBadges(for: episode), kind: .draft)
  }

  private func scheduledRow(for episode: CuratorEpisode, airing: CuratorAiring)
    -> IndividualShowRow
  {
    IndividualShowRow(
      id: episode.id, title: episode.title,
      subtitle: [
        formatted(airing.airtime, "EEEE"), formatted(airing.airtime, "h:mm a"),
        lengthLabel(for: episode),
      ].compactMap { $0 }.joined(separator: " · "),
      seriesBadges: seriesBadges(for: episode),
      kind: .scheduled(airtime: airing.airtime, timeZone: timeZone))
  }

  private func seriesBadges(for episode: CuratorEpisode) -> [String] {
    let owner = series.first { $0.id == episode.showId } ?? episode.show
    guard let owner, !owner.isOneTime else { return [] }
    return [owner.title]
  }

  private func lengthLabel(for episode: CuratorEpisode) -> String? {
    guard episode.hasAudio else { return nil }
    return "\(Int((Double(episode.durationMS) / 60_000).rounded())) min"
  }

  private func formatted(_ date: Date, _ format: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.timeZone = timeZone
    formatter.dateFormat = format
    return formatter.string(from: date)
  }

  private func loadShows() async {
    guard let token = auth.jwt else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      async let loadedEpisodes = api.getCuratorEpisodes(token, stationId, nil)
      async let loadedSeries = api.getCuratorSeries(token, stationId)
      async let loadedSettings = api.getStationSchedulingSettings(token, stationId)
      let (newEpisodes, newSeries, settings) = try await (
        loadedEpisodes, loadedSeries, loadedSettings
      )
      guard !Task.isCancelled else { return }
      episodes = newEpisodes
      series = newSeries
      timeZone = settings.timeZone
      hasLoaded = true
    } catch {
      guard !Task.isCancelled, !(error is CancellationError),
        (error as? URLError)?.code != .cancelled
      else { return }
      if !NetworkErrorClassifier.isNetworkError(error) {
        var tags = NetworkErrorClassifier.errorTags(for: error)
        tags["endpoint"] = "individualShows"
        await errorReporting.reportError(error, tags)
      }
      guard !Task.isCancelled else { return }
      await toast.show(PlayolaToast(message: "Individual shows couldn't load.", buttonTitle: "OK"))
    }
  }
}
