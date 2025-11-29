//
//  ScheduledShowTileModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/16/25.
//
import Dependencies
import Foundation
import Observation

@MainActor
@Observable
class ScheduledShowTileModel {
  @ObservationIgnored
  @Dependency(\.date.now) var now

  @ObservationIgnored
  @Dependency(\.pushNotifications) var pushNotifications
  @ObservationIgnored var stationPlayer: StationPlayer

  var scheduledShow: ScheduledShow
  var presentedAlert: PlayolaAlert?

  init(scheduledShow: ScheduledShow, stationPlayer: StationPlayer? = nil) {
    self.scheduledShow = scheduledShow
    self.stationPlayer = stationPlayer ?? .shared
  }

  var stationTitle: String {
    "\(scheduledShow.station!.curatorName)'s \(scheduledShow.station!.name)"
  }
  var showTitle: String { scheduledShow.show!.title }

  var timeDisplayString: String {
    let formatter = DateFormatter()

    // Format date part: "Wed, Oct 1"
    formatter.dateFormat = "E, MMM d"
    let dateString = formatter.string(from: scheduledShow.airtime)

    formatter.dateFormat = "h:mma"
    let startTimeString = formatter.string(from: scheduledShow.airtime).lowercased()

    let endTimeString = formatter.string(from: scheduledShow.endTime).lowercased()
    return "\(dateString) at \(startTimeString) - \(endTimeString)"
  }

  var isLive: Bool { return scheduledShow.isLive }

  enum ScheduledShowTileButtonType {
    case listenIn
    case notifyMe
  }

  var buttonType: ScheduledShowTileButtonType {
    if scheduledShow.airtime.addingTimeInterval(60 * -5) > self.now {
      return .notifyMe
    }
    return .listenIn
  }

  func notifyMeButtonTapped() async {
    do {
      // Request authorization first
      let authorized = try await pushNotifications.requestAuthorization()
      guard authorized else {
        presentedAlert = .notificationsDisabled
        return
      }

      guard let station = scheduledShow.station else {
        presentedAlert = .errorLoadingStation
        return
      }

      // Schedule notification 5 minutes before the show starts
      let notificationDate = scheduledShow.airtime.addingTimeInterval(-5 * 60)

      let message =
        "\(station.curatorName)'s \(station.name) is going live in about 5 minutes!"

      try await pushNotifications.scheduleNotification(
        scheduledShow.id,
        "Playola Radio",
        message,
        notificationDate
      )
      presentedAlert = .notificationScheduled
    } catch {
      presentedAlert = .errorSchedulingNotification
    }
  }

  func listenInButtonTapped() {
    guard let station = scheduledShow.station else {
      presentedAlert = .errorLoadingStation
      return
    }
    stationPlayer.play(station: .playola(station))
  }
}
