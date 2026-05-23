//
//  SeriesListPageModel.swift
//  PlayolaRadio
//

import Combine
import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class SeriesListPageModel: ViewModel {
  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Shared(.auth) var auth

  // MARK: - State

  var shows: [ShowWithAirings] = []
  var isLoading = false
  var presentedAlert: PlayolaAlert?

  // MARK: - Init

  override init() {
    super.init()
  }

  // MARK: - Actions

  func viewAppeared() async {
    await loadShows()
  }

  private func loadShows() async {
    guard let jwtToken = auth.jwt else { return }

    isLoading = true
    defer { isLoading = false }

    do {
      let airings = try await api.getAirings(jwtToken, nil)
      shows = groupAiringsByShow(airings)
    } catch {
      presentedAlert = .loadShowsErrorAlert
    }
  }

  private func groupAiringsByShow(_ airings: [Airing]) -> [ShowWithAirings] {
    let currentTime = now

    let upcomingAirings = airings.filter { airing in
      let durationMS = airing.episode?.durationMS ?? 0
      let endTime = airing.airtime.addingTimeInterval(TimeInterval(durationMS) / 1000.0)
      return endTime > currentTime
    }

    var airingsByShowId: [String: [Airing]] = [:]
    var showsById: [String: Show] = [:]
    var stationsByShowId: [String: Station?] = [:]

    for airing in upcomingAirings {
      guard let episode = airing.episode,
        let show = episode.show
      else { continue }

      airingsByShowId[show.id, default: []].append(airing)
      showsById[show.id] = show
      if stationsByShowId[show.id] == nil {
        stationsByShowId[show.id] = airing.station
      }
    }

    let shows = airingsByShowId.compactMap { showId, airings -> ShowWithAirings? in
      guard let show = showsById[showId] else { return nil }
      return ShowWithAirings(
        show: show,
        station: stationsByShowId[showId] ?? nil,
        airings: airings.sorted { $0.airtime < $1.airtime },
        now: currentTime
      )
    }

    return shows.sorted {
      $0.nextAiring?.airtime ?? .distantFuture < $1.nextAiring?.airtime ?? .distantFuture
    }
  }
}

// MARK: - Supporting Types

struct ShowWithAirings: Identifiable {
  let show: Show
  let station: Station?
  let airings: [Airing]
  let nextAiring: Airing?
  let upcomingAiringsCount: Int

  var id: String { show.id }

  init(show: Show, station: Station?, airings: [Airing], now: Date) {
    self.show = show
    self.station = station
    self.airings = airings
    let upcoming = airings.filter { $0.airtime > now }
    self.nextAiring = upcoming.sorted { $0.airtime < $1.airtime }.first
    self.upcomingAiringsCount = upcoming.count
  }
}

// MARK: - Alerts

extension PlayolaAlert {
  static var loadShowsErrorAlert: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "Unable to load shows. Please try again later.",
      dismissButton: .cancel(Text("OK")))
  }
}
