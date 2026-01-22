//
//  SeriesCardModel.swift
//  PlayolaRadio
//

import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class SeriesCardModel: ViewModel {
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Dependency(\.api) var api

  let showWithAirings: ShowWithAirings
  var subscriptionStatus: SubscriptionStatus
  var isSubscribing = false
  var presentedAlert: PlayolaAlert?

  init(showWithAirings: ShowWithAirings, subscriptionStatus: SubscriptionStatus) {
    self.showWithAirings = showWithAirings
    self.subscriptionStatus = subscriptionStatus
    super.init()
  }

  func remindMeTapped() async {
    guard let jwt = auth.jwt else { return }
    guard let stationId = showWithAirings.station?.id else { return }
    guard !isSubscribing else { return }

    isSubscribing = true
    defer { isSubscribing = false }

    do {
      _ = try await api.subscribeToStationNotifications(jwt, stationId)
      subscriptionStatus = .subscribed
    } catch {
      presentedAlert = .subscribeErrorAlert
    }
  }
}

extension PlayolaAlert {
  static var subscribeErrorAlert: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "Unable to subscribe to notifications. Please try again.",
      dismissButton: .cancel(Text("OK")))
  }
}
