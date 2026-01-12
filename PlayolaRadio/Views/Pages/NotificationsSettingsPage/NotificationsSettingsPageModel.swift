//
//  NotificationsSettingsPageModel.swift
//  PlayolaRadio
//
//  Created by Claude on 1/2/26.
//

import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

struct StationNotificationItem: Identifiable, Equatable {
  let station: Station
  let isSubscribed: Bool
  let subscriptionStatus: SubscriptionStatus

  var id: String { station.id }

  enum SubscriptionStatus: Equatable {
    case subscribed
    case autoSubscribed
    case unsubscribed
    case notSubscribed
  }

  var statusText: String {
    switch subscriptionStatus {
    case .subscribed:
      return "Subscribed"
    case .autoSubscribed:
      return "Auto-subscribed"
    case .unsubscribed:
      return "Unsubscribed"
    case .notSubscribed:
      return "Not subscribed"
    }
  }

  var statusColor: Color {
    if isSubscribed {
      return Color(hex: "#4CAF50")
    } else {
      return Color(hex: "#666666")
    }
  }
}

@MainActor
@Observable
class NotificationsSettingsPageModel: ViewModel {
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  @ObservationIgnored @Dependency(\.api) var api

  var presentedAlert: PlayolaAlert?
  var isLoading = false
  private var subscriptions: [PushNotificationSubscription] = []
  var togglingStationIds: Set<String> = []

  var stationItems: [StationNotificationItem] {
    let allStations = stationLists.flatMap { $0.playolaStations }
      .filter { $0.active ?? true }
      .sorted {
        $0.curatorName.localizedCaseInsensitiveCompare($1.curatorName) == .orderedAscending
      }
    let subscriptionsByStationId = Dictionary(
      uniqueKeysWithValues: subscriptions.map { ($0.stationId, $0) }
    )

    return allStations.map { station in
      let subscription = subscriptionsByStationId[station.id]
      let isSubscribed = subscription?.isSubscribed ?? false

      let status: StationNotificationItem.SubscriptionStatus
      if let sub = subscription {
        if sub.isSubscribed {
          if sub.manualSubscribedAt != nil {
            status = .subscribed
          } else if sub.autoSubscribedAt != nil {
            status = .autoSubscribed
          } else {
            status = .subscribed
          }
        } else {
          if sub.optedOutAt != nil {
            status = .unsubscribed
          } else {
            status = .notSubscribed
          }
        }
      } else {
        status = .notSubscribed
      }

      return StationNotificationItem(
        station: station,
        isSubscribed: isSubscribed,
        subscriptionStatus: status
      )
    }
  }

  var allNotificationsEnabled: Bool {
    guard !stationItems.isEmpty else { return false }
    return stationItems.allSatisfy { $0.isSubscribed }
  }

  var someNotificationsEnabled: Bool {
    stationItems.contains { $0.isSubscribed }
  }

  func viewAppeared() async {
    await loadSubscriptions()
  }

  private func loadSubscriptions() async {
    guard let jwt = auth.jwt else { return }
    isLoading = true
    defer { isLoading = false }

    do {
      let subscriptionsWithStations = try await api.getPushNotificationSubscriptions(jwt)
      subscriptions = subscriptionsWithStations.map { sub in
        PushNotificationSubscription(
          id: sub.id,
          userId: sub.userId,
          stationId: sub.stationId,
          isSubscribed: sub.isSubscribed,
          optedOutAt: sub.optedOutAt,
          autoSubscribedAt: sub.autoSubscribedAt,
          manualSubscribedAt: sub.manualSubscribedAt,
          createdAt: sub.createdAt,
          updatedAt: sub.updatedAt
        )
      }
    } catch {
      presentedAlert = .loadSubscriptionsErrorAlert
    }
  }

  func isSubscribed(stationId: String) -> Bool {
    subscriptions.first { $0.stationId == stationId }?.isSubscribed ?? false
  }

  func isToggling(stationId: String) -> Bool {
    togglingStationIds.contains(stationId)
  }

  func toggleSubscription(for stationId: String) async {
    guard let jwt = auth.jwt else { return }
    guard !togglingStationIds.contains(stationId) else { return }

    togglingStationIds.insert(stationId)
    defer { togglingStationIds.remove(stationId) }

    let currentlySubscribed = isSubscribed(stationId: stationId)

    do {
      if currentlySubscribed {
        _ = try await api.unsubscribeFromStationNotifications(jwt, stationId)
      } else {
        _ = try await api.subscribeToStationNotifications(jwt, stationId)
      }
      await loadSubscriptions()
    } catch {
      presentedAlert = .toggleSubscriptionErrorAlert
    }
  }

  func toggleAllNotifications() async {
    guard let jwt = auth.jwt else { return }

    let shouldSubscribe = !allNotificationsEnabled
    let items = stationItems

    for item in items where item.isSubscribed != shouldSubscribe {
      togglingStationIds.insert(item.station.id)
    }

    do {
      for item in items where item.isSubscribed != shouldSubscribe {
        if shouldSubscribe {
          _ = try await api.subscribeToStationNotifications(jwt, item.station.id)
        } else {
          _ = try await api.unsubscribeFromStationNotifications(jwt, item.station.id)
        }
      }
      await loadSubscriptions()
    } catch {
      presentedAlert = .toggleSubscriptionErrorAlert
    }

    togglingStationIds.removeAll()
  }
}

extension PlayolaAlert {
  static var loadSubscriptionsErrorAlert: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "Unable to load notification settings. Please try again later.",
      dismissButton: .cancel(Text("OK")))
  }

  static var toggleSubscriptionErrorAlert: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "Unable to update notification settings. Please try again.",
      dismissButton: .cancel(Text("OK")))
  }
}
