//
//  StationListPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//
import Observation
import Combine
import IdentifiedCollections
import Sharing
import Dependencies

@MainActor
@Observable
class StationListModel: ViewModel {
  var disposeBag: Set<AnyCancellable> = Set()

  // MARK: State

  var isLoadingStationLists: Bool = false
  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations
  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList>
  @ObservationIgnored @Dependency(\.genericApiClient) var genericApiClient
  var presentedAlert: PlayolaAlert?
  var presentedSheet: PlayolaSheet?
  var stationPlayerState: StationPlayer.State = .init(playbackStatus: .stopped)

  // MARK: Dependencies

  @ObservationIgnored var stationPlayer: StationPlayer
  var navigationCoordinator: NavigationCoordinator!

  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool

  init(stationPlayer: StationPlayer? = nil, navigationCoordinator: NavigationCoordinator = .shared)
  {
    self.stationPlayer = stationPlayer ?? StationPlayer.shared
    self.navigationCoordinator = navigationCoordinator
  }

  // MARK: Actions

  func viewAppeared() async {
    isLoadingStationLists = true
    defer { self.isLoadingStationLists = false }
    do {
      if !stationListsLoaded {
        _ = try await genericApiClient.getStations()
      }
    } catch (_) {
      presentedAlert = .errorLoadingStations
    }
    stationPlayer.$state.sink { [weak self] in
      self?.stationPlayerState = $0
    }
      .store(in: &disposeBag)
  }

  func hamburgerButtonTapped() {
    self.navigationCoordinator.slideOutMenuIsShowing = true
  }

  func dismissAboutViewButtonTapped() {}
  func stationSelected(_ station: RadioStation) {
    if stationPlayer.currentStation != station {
      stationPlayer.play(station: station)
    }
    navigationCoordinator.path.append(.nowPlayingPage(NowPlayingPageModel()))
  }

  func dismissButtonInSheetTapped() {
    presentedSheet = nil
  }

  func nowPlayingToolbarButtonTapped() {
    if stationPlayer.currentStation != nil {
      navigationCoordinator.path.append(.nowPlayingPage(NowPlayingPageModel()))
    }
  }
}


