//
//  AiringsListModel.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//

import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing

@MainActor
@Observable
class AiringsListModel {
  @ObservationIgnored
  @Dependency(\.api) var api

  @ObservationIgnored
  @Dependency(\.pushNotifications) var pushNotifications

  @ObservationIgnored
  @Shared(.airings) var sharedAirings: IdentifiedArrayOf<Airing> = []

  var airings: [Airing] = [] {
    didSet {
      updateTileModels()
    }
  }
  var stationId: String?
  var presentedAlert: PlayolaAlert?
  var tileModels: [AiringTileModel] = []

  var subscribedStationIds: Set<String> = []

  init(stationId: String? = nil, airings: [Airing] = []) {
    self.stationId = stationId
    self.airings = airings
    updateTileModels()
  }

  private func updateTileModels() {
    tileModels = airings.map { airing in
      let model = AiringTileModel(airing: airing)
      model.isSubscribedToStationNotifications = subscribedStationIds.contains(airing.stationId)
      return model
    }
  }

  func loadAirings(jwtToken: String) async {
    do {
      let fetchedAirings = try await api.getAirings(jwtToken, stationId)

      $sharedAirings.withLock {
        $0 = IdentifiedArray(uniqueElements: fetchedAirings)
      }

      self.airings = fetchedAirings
    } catch {
      print("Error loading airings: \(error)")
    }
  }

  func loadSubscriptions(jwtToken: String) async {
    do {
      let subscriptions = try await api.getPushNotificationSubscriptions(jwtToken)
      subscribedStationIds = Set(
        subscriptions.filter { $0.isSubscribed }.map { $0.stationId }
      )
      updateTileModels()
    } catch {
      print("Error loading subscriptions: \(error)")
    }
  }
}
