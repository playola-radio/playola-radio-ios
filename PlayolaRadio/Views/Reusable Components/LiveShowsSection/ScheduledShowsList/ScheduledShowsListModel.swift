//
//  ScheduledShowsListModel.swift
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

    // Format date part: "Wed, Oct 1"
    formatter.dateFormat = "E, MMM d"
    let dateString = formatter.string(from: airtime)

    // Format time part: "7:00pm"
    formatter.dateFormat = "h:mma"
    let startTimeString = formatter.string(from: airtime).lowercased()

    if let endTime = endTime {
      let endTimeString = formatter.string(from: endTime).lowercased()
      return "\(dateString) at \(startTimeString) - \(endTimeString)"
    } else {
      return "\(dateString) at \(startTimeString)"
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
class ScheduledShowsListModel {
  @ObservationIgnored
  @Dependency(\.api) var api

  @ObservationIgnored
  @Dependency(\.pushNotifications) var pushNotifications

  var scheduledShows: [ScheduledShowDisplay] = []
  var stationId: String?

  init(stationId: String? = nil, scheduledShows: [ScheduledShowDisplay] = []) {
    self.stationId = stationId
    self.scheduledShows = scheduledShows
  }

  func loadScheduledShows(jwtToken: String) async {
    do {
      let rawScheduledShows = try await api.getScheduledShows(jwtToken, nil, stationId)

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

  func scheduleNotification(for scheduledShow: ScheduledShowDisplay) async {
    do {
      // Request authorization first
      let authorized = try await pushNotifications.requestAuthorization()
      guard authorized else {
        print("Notification authorization denied")
        return
      }

      // Schedule notification 10 minutes before the show starts
      let notificationDate = scheduledShow.airtime.addingTimeInterval(-10 * 60)

      try await pushNotifications.scheduleNotification(
        scheduledShow.id,
        "\(scheduledShow.showTitle) is starting soon!",
        "Tune in at \(scheduledShow.timeDisplayString)",
        notificationDate
      )

      print("Notification scheduled for \(scheduledShow.showTitle)")
    } catch {
      print("Error scheduling notification: \(error)")
    }
  }
}
