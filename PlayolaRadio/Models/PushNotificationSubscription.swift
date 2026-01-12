//
//  PushNotificationSubscription.swift
//  PlayolaRadio
//
//  Created by Claude on 1/3/26.
//

import Foundation
import PlayolaPlayer

struct PushNotificationSubscription: Codable, Identifiable, Equatable {
  let id: String
  let userId: String
  let stationId: String
  let isSubscribed: Bool
  let optedOutAt: Date?
  let autoSubscribedAt: Date?
  let manualSubscribedAt: Date?
  let createdAt: Date
  let updatedAt: Date
}

struct PushNotificationSubscriptionWithStation: Codable, Identifiable, Equatable {
  let id: String
  let userId: String
  let stationId: String
  let isSubscribed: Bool
  let optedOutAt: Date?
  let autoSubscribedAt: Date?
  let manualSubscribedAt: Date?
  let createdAt: Date
  let updatedAt: Date
  let station: Station
}
