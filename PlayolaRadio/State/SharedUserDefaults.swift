//
//  SharedUserDefaults.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var showSecretStations: Self {
    Self[.appStorage("showSecretStations"), default: false]
  }
}

extension SharedKey
where Self == FileStorageKey<IdentifiedArrayOf<StationList>>.Default {
  static var stationLists: Self {
    Self[
      .fileStorage(
        dump(.documentsDirectory.appending(component: "station-lists.json"))),
      default: []]
  }
}

extension SharedKey where Self == InMemoryKey<Bool>.Default {
  static var stationListsLoaded: Self {
    Self[.inMemory("stationListsLoaded"), default: false]
  }
}

extension SharedKey
where Self == FileStorageKey<IdentifiedArrayOf<Airing>>.Default {
  static var airings: Self {
    Self[
      .fileStorage(
        dump(.documentsDirectory.appending(component: "airings.json"))),
      default: []]
  }
}

extension SharedKey where Self == FileStorageKey<Auth>.Default {
  static var auth: Self {
    Self[
      .fileStorage(dump(.documentsDirectory.appending(component: "auth.json"))),
      default: Auth()]
  }
}

extension SharedKey where Self == InMemoryKey<NowPlaying?>.Default {
  static var nowPlaying: Self {
    Self[.inMemory("nowPlaying"), default: nil]
  }
}

extension SharedKey where Self == InMemoryKey<ListeningTracker?>.Default {
  static var listeningTracker: Self {
    Self[.inMemory("listeningTracker"), default: nil]
  }
}

extension SharedKey where Self == InMemoryKey<MainContainerModel.ActiveTab>.Default {
  static var activeTab: Self {
    Self[.inMemory("activeTab"), default: .home]
  }
}

extension SharedKey where Self == InMemoryKey<MainContainerNavigationCoordinator>.Default {
  static var mainContainerNavigationCoordinator: Self {
    Self[
      .inMemory("mainContainerNavigationCoordinator"), default: MainContainerNavigationCoordinator()
    ]
  }
}

// MARK: - Likes

extension SharedKey where Self == FileStorageKey<[String: UserSongLike]>.Default {
  static var userLikes: Self {
    Self[
      .fileStorage(.documentsDirectory.appending(component: "user-likes.json")),
      default: [:]
    ]
  }
}

extension SharedKey where Self == FileStorageKey<[LikeOperation]>.Default {
  static var pendingLikeOperations: Self {
    Self[
      .fileStorage(.documentsDirectory.appending(component: "pending-like-operations.json")),
      default: []
    ]
  }
}

// MARK: - Live Stations

extension SharedKey where Self == InMemoryKey<[LiveStationInfo]>.Default {
  static var liveStations: Self {
    Self[.inMemory("liveStations"), default: []]
  }
}

// MARK: - Push Notifications

extension SharedKey where Self == AppStorageKey<String?>.Default {
  static var registeredDeviceId: Self {
    Self[.appStorage("registeredDeviceId"), default: nil]
  }
}

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var hasAskedForNotificationPermission: Self {
    Self[.appStorage("hasAskedForNotificationPermission"), default: false]
  }
}

extension SharedKey where Self == FileStorageKey<[String: Date]>.Default {
  static var lastNotificationSentAt: Self {
    Self[
      .fileStorage(.documentsDirectory.appending(component: "last-notification-sent.json")),
      default: [:]
    ]
  }
}

// MARK: - Support

extension SharedKey where Self == InMemoryKey<Int>.Default {
  static var unreadSupportCount: Self {
    Self[.inMemory("unreadSupportCount"), default: 0]
  }
}

// MARK: - Version Enforcement

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var isBroadcaster: Self {
    Self[.appStorage("isBroadcaster"), default: false]
  }
}

extension SharedKey where Self == InMemoryKey<AppVersionRequirements?>.Default {
  static var appVersionRequirements: Self {
    Self[.inMemory("appVersionRequirements"), default: nil]
  }
}

// MARK: - App Rating

extension SharedKey where Self == AppStorageKey<Date?>.Default {
  static var appInstallDate: Self {
    Self[.appStorage("appInstallDate"), default: nil]
  }
}

extension SharedKey where Self == AppStorageKey<String?>.Default {
  static var lastRatingPromptVersion: Self {
    Self[.appStorage("lastRatingPromptVersion"), default: nil]
  }
}

extension SharedKey where Self == AppStorageKey<Date?>.Default {
  static var lastRatingPromptDismissDate: Self {
    Self[.appStorage("lastRatingPromptDismissDate"), default: nil]
  }
}

// MARK: - TLS Probe

extension SharedKey where Self == AppStorageKey<String?>.Default {
  static var tls13ProbeLastSentBuild: Self {
    Self[.appStorage("tls13ProbeLastSentBuild"), default: nil]
  }
}
