//
//  UpcomingShowsPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Sharing
import SwiftUI

@MainActor
@Observable
class UpcomingShowsPageModel: ViewModel {

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
  var isLoading = false

  var navigationTitle: String { "Upcoming" }
  var seriesRowTitle: String { "Series" }
  var individualShowsRowTitle: String { "Individual Shows" }
  var loadingOpacity: Double { isLoading ? 1 : 0 }

  // MARK: - View Helpers

  var seriesCountLabel: String {
    let inSeries = comingUpEpisodes.filter { regularSeriesIds.contains($0.showId) }
    return "\(regularSeriesIds.count) series · \(Self.comingUpLabel(for: inSeries.count))"
  }

  var individualShowsCountLabel: String {
    let comingUp = Self.comingUpLabel(for: comingUpEpisodes.count)
    guard draftCount > 0 else { return comingUp }
    return "\(comingUp) · \(draftCount) not scheduled"
  }

  // MARK: - User Actions

  func viewAppeared() async {
    await loadShows()
  }

  func seriesRowTapped() {}

  func individualShowsRowTapped() {}

  // MARK: - Private Helpers

  private static let lockLengthIsIrrelevantToCounting = 0

  private var regularSeriesIds: Set<String> {
    Set(series.filter { !$0.isOneTime }.map(\.id))
  }

  private var draftCount: Int {
    episodes.filter { state(of: $0) == .draft }.count
  }

  private var comingUpEpisodes: [CuratorEpisode] {
    episodes.filter { episode in
      switch state(of: episode) {
      case .scheduled, .locked: return true
      case .draft, .aired: return false
      }
    }
  }

  private func state(of episode: CuratorEpisode) -> CuratorEpisodeState {
    episode.state(now: now, lockMS: Self.lockLengthIsIrrelevantToCounting)
  }

  private static func comingUpLabel(for count: Int) -> String {
    count == 1 ? "1 show coming up" : "\(count) shows coming up"
  }

  private func loadShows() async {
    guard let token = auth.jwt else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      async let loadedEpisodes = api.getCuratorEpisodes(token, stationId, nil)
      async let loadedSeries = api.getCuratorSeries(token, stationId)
      let (newEpisodes, newSeries) = try await (loadedEpisodes, loadedSeries)
      guard !Task.isCancelled else { return }
      episodes = newEpisodes
      series = newSeries
    } catch {
      guard !Task.isCancelled, !(error is CancellationError),
        (error as? URLError)?.code != .cancelled
      else { return }
      if !NetworkErrorClassifier.isNetworkError(error) {
        var tags = NetworkErrorClassifier.errorTags(for: error)
        tags["endpoint"] = "upcomingShows"
        await errorReporting.reportError(error, tags)
      }
      await toast.show(PlayolaToast(message: "Upcoming shows couldn't load.", buttonTitle: "OK"))
    }
  }
}
