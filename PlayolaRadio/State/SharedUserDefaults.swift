//
//  SharedUserDefaults.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/18/25.
//
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
where Self == FileStorageKey<IdentifiedArrayOf<ScheduledShow>>.Default {
  static var scheduledShows: Self {
    Self[
      .fileStorage(
        dump(.documentsDirectory.appending(component: "scheduled-shows.json"))),
      default: []]
  }
}

extension SharedKey where Self == InMemoryKey<Bool>.Default {
  static var scheduledShowsLoaded: Self {
    Self[.inMemory("scheduledShowsLoaded"), default: false]
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

extension SharedKey where Self == InMemoryKey<PlayolaAlert?>.Default {
  static var presentedAlert: Self {
    Self[.inMemory("presentedAlert"), default: nil]
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

extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var hasBeenUnlocked: Self {
    Self[.appStorage("hasBeenUnlocked"), default: false]
  }
}

extension SharedKey where Self == AppStorageKey<String?>.Default {
  static var invitationCode: Self {
    Self[.appStorage("invitationCode"), default: nil]
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
