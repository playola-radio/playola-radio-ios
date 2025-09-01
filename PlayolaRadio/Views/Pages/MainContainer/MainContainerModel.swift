//
//  MainContainerModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/22/25.
//

import Combine
import Dependencies
import Sharing
import SwiftUI

@MainActor
@Observable
class MainContainerModel: ViewModel {
  var cancellables: Set<AnyCancellable> = []

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.toast) var toast
  @ObservationIgnored var stationPlayer: StationPlayer!
  @ObservationIgnored @Shared(.stationLists) var stationLists
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool = false
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.activeTab) var activeTab
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator
  @ObservationIgnored @Shared(.hasBeenUnlocked) var hasBeenUnlocked

  enum ActiveTab {
    case home
    case stationsList
    case rewards
    case profile
  }

  var presentedAlert: PlayolaAlert?
  var presentedToast: PlayolaToast?

  var homePageModel = HomePageModel()
  var stationListModel = StationListModel()
  var rewardsPageModel = RewardsPageModel()
  var contactPageModel = ContactPageModel()

  var shouldShowSmallPlayer: Bool = false

  init(stationPlayer: StationPlayer? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
    super.init()
  }

  func viewAppeared() async {
    // Mark that the main container has been unlocked/shown
    $hasBeenUnlocked.withLock { $0 = true }

    // Exit early if we already have the data.
    guard !stationListsLoaded else { return }

    do {
      let retrievedStationsLists = try await api.getStations()
      self.$stationLists.withLock { $0 = retrievedStationsLists }
      self.$stationListsLoaded.withLock { $0 = true }
    } catch {
      presentedAlert = .errorLoadingStations
      await analytics.track(
        .apiError(
          endpoint: "getStations",
          error: error.localizedDescription
        ))
    }

    // NOTE: For now, this has to stay connected to the Singleton in order to avoid reloading
    // the entire app every time a nowPlaying.publisher event is received.  That seems to be
    // what happens when we use the Shared nowPlaying value.  In the future we should figure out
    // how to get this to work with the nowPlaying shared state.
    stationPlayer.$state.sink { self.processNewStationState($0) }.store(in: &cancellables)

    observeToasts()

    await loadListeningTracker()
  }

  func loadListeningTracker() async {
    guard let authJWT = auth.jwt else {
      print("Error not signed in")
      return
    }
    do {
      let rewards = try await api.getRewardsProfile(authJWT)
      self.$listeningTracker.withLock { $0 = ListeningTracker(rewardsProfile: rewards) }
    } catch let err {
      print(err)
    }
  }
  func dismissButtonInSheetTapped() {
    self.mainContainerNavigationCoordinator.presentedSheet = nil
  }

  func processNewStationState(_ newState: StationPlayer.State) {
    switch newState.playbackStatus {
    case .startingNewStation:
      self.mainContainerNavigationCoordinator.presentedSheet = .player(
        PlayerPageModel(onDismiss: {
          self.mainContainerNavigationCoordinator.presentedSheet = nil
        }))
    default: break
    }
    self.setShouldShowSmallPlayer(newState)
  }

  func setShouldShowSmallPlayer(_ stationPlayerState: StationPlayer.State) {
    withAnimation {
      switch stationPlayerState.playbackStatus {
      case .playing, .startingNewStation, .loading:
        self.shouldShowSmallPlayer = true
      default:
        self.shouldShowSmallPlayer = false
      }
    }
  }

  func onSmallPlayerTapped() {
    self.mainContainerNavigationCoordinator.presentedSheet = .player(
      PlayerPageModel(onDismiss: { self.mainContainerNavigationCoordinator.presentedSheet = nil }))
  }

  // Test method for showing toasts
  func testShowToast() {
    Task {
      await toast.show(
        PlayolaToast(
          message: "Added to Liked Songs",
          buttonTitle: "View all",
          action: {
            print("View all tapped!")
          }
        )
      )
    }
  }

  func observeToasts() {
    Task { @MainActor in
      while true {
        if let currentToast = await toast.currentToast() {
          self.presentedToast = currentToast
        } else {
          self.presentedToast = nil
        }
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }
}

extension PlayolaAlert {
  static var errorLoadingStations: PlayolaAlert {
    PlayolaAlert(
      title: "Error Loading Stations",
      message:
        "There was an error loading the stations. Please check your connection and try again.",
      dismissButton: .cancel(Text("OK"))
    )
  }
}
