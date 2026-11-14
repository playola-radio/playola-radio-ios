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

  let stationId: String
  var episodes: [CuratorEpisode] = []
  var series: [CuratorSeries] = []
  var isLoading = false

  var navigationTitle: String { "Upcoming" }
  var seriesRowTitle: String { "Series" }
  var individualShowsRowTitle: String { "Individual Shows" }
  var loadingOpacity: Double { isLoading ? 1 : 0 }

  // MARK: - User Actions

  func viewAppeared() async {
    await loadShows()
  }

  func observeRecordedShowsChanges(onReady: @escaping @MainActor () -> Void = {}) async {
    let notifications = notificationCenter.notifications(named: .recordedShowsChanged)
    onReady()
    for await notification in notifications {
      guard !Task.isCancelled else { return }
      guard notification.userInfo?["stationId"] as? String == stationId else { continue }
      await loadShows()
    }
  }

  func seriesRowTapped() {}

  func individualShowsRowTapped() {
    navigationCoordinator.push(.individualShowsPage(IndividualShowsPageModel(stationId: stationId)))
  }

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

  // MARK: - Private Helpers

  private var regularSeriesIds: Set<String> {
    Set(series.filter { !$0.isOneTime }.map(\.id))
  }

  private var draftCount: Int {
    episodes.filter(\.isDraft).count
  }

  private var comingUpEpisodes: [CuratorEpisode] {
    episodes.filter { $0.upcomingAiring(now: now) != nil }
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
      guard !Task.isCancelled else { return }
      await toast.show(PlayolaToast(message: "Upcoming shows couldn't load.", buttonTitle: "OK"))
    }
  }
}
