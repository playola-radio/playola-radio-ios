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
    var showDict: [String: ShowWithAirings] = [:]

    // Filter to only include airings that haven't ended yet
    let upcomingAirings = airings.filter { airing in
      let durationMS = airing.episode?.durationMS ?? 0
      let endTime = airing.airtime.addingTimeInterval(TimeInterval(durationMS) / 1000.0)
      return endTime > now
    }

    for airing in upcomingAirings {
      guard let episode = airing.episode,
        let show = episode.show
      else { continue }

      if var existing = showDict[show.id] {
        existing.airings.append(airing)
        showDict[show.id] = existing
      } else {
        showDict[show.id] = ShowWithAirings(
          show: show,
          station: airing.station,
          airings: [airing]
        )
      }
    }

    // Sort airings within each show by airtime
    for (id, var showWithAirings) in showDict {
      showWithAirings.airings.sort { $0.airtime < $1.airtime }
      showDict[id] = showWithAirings
    }

    return showDict.values
      .sorted {
        $0.nextAiring?.airtime ?? .distantFuture < $1.nextAiring?.airtime ?? .distantFuture
      }
  }
}

// MARK: - Supporting Types

struct ShowWithAirings: Identifiable {
  let show: Show
  let station: Station?
  var airings: [Airing]

  var id: String { show.id }

  var nextAiring: Airing? {
    airings
      .filter { $0.airtime > Date() }
      .sorted { $0.airtime < $1.airtime }
      .first
  }

  var upcomingAiringsCount: Int {
    airings.filter { $0.airtime > Date() }.count
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
