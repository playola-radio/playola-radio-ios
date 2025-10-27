//
//  LiveShowsModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/8/25.
//

import Dependencies
import Foundation

/// Display model for a scheduled show tile
struct ScheduledShowDisplay: Identifiable, Equatable {
  let id: String
  let showId: String
  let showTitle: String
  let airtime: Date
  let endTime: Date?
  let isLive: Bool

  var statusText: String {
    isLive ? "LIVE NOW" : "UPCOMING"
  }

  var timeDisplayString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "E, MMM d h:mma"
    let startString = formatter.string(from: airtime)

    if let endTime = endTime {
      formatter.dateFormat = "h:mma"
      let endString = formatter.string(from: endTime)
      return "\(startString) - \(endString)"
    } else {
      return startString
    }
  }

  /// Creates a display model from a ScheduledShow
  static func from(_ scheduledShow: ScheduledShow) -> ScheduledShowDisplay {
    ScheduledShowDisplay(
      id: scheduledShow.id,
      showId: scheduledShow.showId,
      showTitle: scheduledShow.show?.title ?? "Unknown Show",
      airtime: scheduledShow.airtime,
      endTime: scheduledShow.endTime,
      isLive: scheduledShow.isLive
    )
  }
}

@Observable
class LiveShowsModel {
  @ObservationIgnored
  @Dependency(\.api) var api

  var scheduledShows: [ScheduledShowDisplay] = []
  var stationId: String?

  init(stationId: String? = nil, scheduledShows: [ScheduledShowDisplay] = []) {
    self.stationId = stationId
    self.scheduledShows = scheduledShows
  }

  func loadScheduledShows(jwtToken: String) async {
    do {
      let rawScheduledShows = try await api.getScheduledShows(jwtToken, nil, stationId)
      let now = Date()

      scheduledShows = rawScheduledShows.map { scheduledShow in
        ScheduledShowDisplay.from(scheduledShow)
      }
    } catch {
      // TODO: Handle error
      print("Error loading scheduled shows: \(error)")
    }
  }

  func handleShowTapped(_ scheduledShow: ScheduledShowDisplay) async {
    // Handle show tapped - to be implemented
  }
}
