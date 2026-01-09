//
//  AiringTileModel.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//
import Dependencies
import Foundation
import Observation
import PlayolaPlayer
import Sharing

@MainActor
@Observable
class AiringTileModel {
  @ObservationIgnored
  @Dependency(\.date.now) var now
  @ObservationIgnored
  @Dependency(\.continuousClock) var clock

  @ObservationIgnored
  @Dependency(\.pushNotifications) var pushNotifications
  @ObservationIgnored
  @Dependency(\.analytics) var analytics
  @ObservationIgnored var stationPlayer: StationPlayer

  @ObservationIgnored
  @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  var airing: Airing
  var presentedAlert: PlayolaAlert?
  var buttonType: AiringTileButtonType = .notifyMe
  var isSubscribedToStationNotifications: Bool = false

  init(airing: Airing, stationPlayer: StationPlayer? = nil) {
    self.airing = airing
    self.stationPlayer = stationPlayer ?? .shared
    self.buttonType = computeButtonType()
  }

  var stationTitle: String {
    guard let station = airing.station else { return "Unknown Station" }
    return "\(station.curatorName)'s \(station.name)"
  }

  var stationSubtitle: String {
    guard let station = airing.station else { return "" }
    return "on \(station.curatorName)'s \(station.name)"
  }

  var showTitle: String { airing.episode?.show?.title ?? "Unknown Show" }

  var episodeTitle: String { airing.episode?.title ?? "" }

  var scheduleDisplayString: String {
    if isLive {
      return "LIVE NOW"
    }

    if let rrule = airing.episode?.show?.rrule,
      let formatted = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airing.airtime)
    {
      return formatted
    }

    return timeDisplayString
  }

  var timeDisplayString: String {
    let formatter = DateFormatter()

    formatter.dateFormat = "E, MMM d"
    let dateString = formatter.string(from: airing.airtime)

    formatter.dateFormat = "h:mma"
    let startTimeString = formatter.string(from: airing.airtime).lowercased()
    let endTimeString = formatter.string(from: endTime).lowercased()

    return "\(dateString) at \(startTimeString) - \(endTimeString)"
  }

  var isLive: Bool {
    airing.airtime <= now && endTime > now
  }

  var endTime: Date {
    let durationMS = airing.episode?.durationMS ?? 0
    return airing.airtime.addingTimeInterval(TimeInterval(durationMS) / 1000.0)
  }

  enum AiringTileButtonType {
    case listenIn
    case notifyMe
    case subscribed
  }

  private func computeButtonType() -> AiringTileButtonType {
    if airing.airtime.addingTimeInterval(-5 * 60) > self.now {
      return isSubscribedToStationNotifications ? .subscribed : .notifyMe
    }
    return .listenIn
  }

  func viewAppeared() async {
    let showStartWindow = airing.airtime.addingTimeInterval(-5 * 60)
    let delay = showStartWindow.timeIntervalSince(now) + 5
    guard delay > 0 else { return }
    try? await clock.sleep(for: .seconds(delay))
    buttonType = .listenIn
  }

  func notifyMeButtonTapped() async {
    do {
      let authorized = try await pushNotifications.requestAuthorization()
      guard authorized else {
        presentedAlert = .notificationsDisabled
        return
      }

      guard let station = airing.station else {
        presentedAlert = .errorLoadingStation
        return
      }

      let notificationDate = airing.airtime.addingTimeInterval(-5 * 60)

      let message =
        "\(station.curatorName)'s \(station.name) is going live in about 5 minutes!"

      try await pushNotifications.scheduleNotification(
        airing.id,
        "Playola Radio",
        message,
        notificationDate
      )

      await analytics.track(
        .notifyMeRequested(
          showId: airing.episode?.showId ?? "",
          showName: airing.episode?.show?.title ?? "Unknown",
          stationName: station.name
        )
      )

      presentedAlert = .notificationScheduled
    } catch {
      presentedAlert = .errorSchedulingNotification
    }
  }

  func subscribedButtonTapped() {
    let model = NotificationsSettingsPageModel()
    navigationCoordinator.push(.notificationsSettingsPage(model))
  }

  func listenInButtonTapped() {
    guard let station = airing.station else {
      presentedAlert = .errorLoadingStation
      return
    }
    stationPlayer.play(station: .playola(station))
  }
}
