import Combine
import Dependencies
import IdentifiedCollections
//
//  HomePageViewModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import Sharing
import SwiftUI

@MainActor
@Observable
class HomePageModel: ViewModel {
  var disposeBag = Set<AnyCancellable>()
  // MARK: State
  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []
  @ObservationIgnored @Shared(.auth) var auth: Auth
  @ObservationIgnored @Shared(.activeTab) var activeTab
  @ObservationIgnored @Dependency(\.analytics) var analytics

  @ObservationIgnored var stationPlayer: StationPlayer

  var forYouStations: IdentifiedArrayOf<AnyStation> = []
  var presentedAlert: PlayolaAlert?

  var welcomeMessage: String {
    if let currentUser = auth.currentUser {
      return "Welcome, \(currentUser.firstName)"
    } else {
      return "Welcome to Playola"
    }
  }

  @ObservationIgnored lazy var listeningTimeTileModel: ListeningTimeTileModel =
    ListeningTimeTileModel(
      buttonText: "Redeem Your Rewards!",
      buttonAction: { [weak self] in
        guard let self = self else { return }
        await self.analytics.track(.navigatedToRewardsFromListeningTile)
        await self.$activeTab.withLock { $0 = .rewards }
      }
    )

  init(stationPlayer: StationPlayer? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
  }

  // MARK: Actions
  func viewAppeared() async {
    $stationLists.publisher
      .sink { lists in
        guard let artistList = lists.first(where: { $0.slug == StationList.artistListSlug }) else {
          return
        }
        self.forYouStations = IdentifiedArray(uniqueElements: artistList.stations)
      }
      .store(in: &disposeBag)
  }

  func handlePlayolaIconTapped10Times() {
    $showSecretStations.withLock { $0 = !$0 }
    presentedAlert = showSecretStations ? .secretStationsTurnedOnAlert : .secretStationsHiddenAlert
  }

  func handleStationTapped(_ station: AnyStation) async {
    await analytics.track(
      .startedStation(
        station: StationInfo(from: station),
        entryPoint: "home_recommendations"
      ))
    stationPlayer.play(station: station)
  }
}
