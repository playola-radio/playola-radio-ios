//
//  ScheduledShowTileModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/16/25.
//
import Dependencies
import Observation

@MainActor
@Observable
class ScheduledShowTileModel {
  var scheduledShow: ScheduledShow
  var presentedAlert: PlayolaAlert?

  init(scheduledShow: ScheduledShow, stationPlayer: StationPlayer? = nil ) {
    self.scheduledShow = scheduledShow
    self.stationPlayer = stationPlayer ?? .shared
  }

  @ObservationIgnored
  @Dependency(\.date.now) var now

  @ObservationIgnored
  @Dependency(\.pushNotifications) var pushNotifications

  @ObservationIgnored var stationPlayer: StationPlayer

  var isLive: Bool { return scheduledShow.isLive }

  enum ScheduledShowTileButtonType
  {
    case listenNow
    case remindMe
  }

  var buttonType: ScheduledShowTileButtonType {
    if scheduledShow.airtime.addingTimeInterval(60 * -5) > self.now {
      return .remindMe
    }
    return .listenNow
  }

  func remindMeButtonTapped() async {
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

      print("Notification scheduled for \(station.name)")
    } catch {
      print("Error scheduling notification: \(error)")
    }
  }
  
  func listenNowButtonTapped() {
    guard let station = scheduledShow.station else {
      presentedAlert = .errorLoadingStation
      return
    }
    stationPlayer.play(station: .playola(station))
  }
}
