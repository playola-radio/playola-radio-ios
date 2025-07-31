import Combine
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

  @ObservationIgnored var stationPlayer: StationPlayer

  var forYouStations: IdentifiedArrayOf<RadioStation> = []
  var presentedAlert: PlayolaAlert?

  var welcomeMessage: String {
    if let currentUser = auth.currentUser {
      return "Welcome, \(currentUser.firstName)"
    } else {
      return "Welcome to Playola"
    }
  }

  var listeningTimeTileModel: ListeningTimeTileModel {
    ListeningTimeTileModel(
      buttonText: "Redeem Your Rewards!",
      buttonAction: {
        self.$activeTab.withLock { $0 = .rewards }
      }
    )
  }

  init(stationPlayer: StationPlayer? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
  }

  // MARK: Actions
  func viewAppeared() async {
    $stationLists.publisher
      .sink { lists in
        guard let artistList = lists.first(where: { $0.id == StationList.artistListId }) else {
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

  func handleStationTapped(_ station: RadioStation) {
    stationPlayer.play(station: station)
  }
}