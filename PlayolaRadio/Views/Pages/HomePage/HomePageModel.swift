//
//  HomePageViewModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import Sharing
import SwiftUI
import IdentifiedCollections
import Combine

@MainActor
@Observable
class HomePageModel: ViewModel {
  var disposeBag = Set<AnyCancellable>()
  // MARK: State
  @ObservationIgnored @Shared(.showSecretStations) var showSecretStations: Bool
  @ObservationIgnored @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  @ObservationIgnored @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList> = []

  var forYouStations: IdentifiedArrayOf<RadioStation> = []
  var presentedAlert: PlayolaAlert? = nil

  // MARK: Actions
  
  func viewAppeared() async {
    $stationLists.publisher
      .sink { lists in
      guard let artistList = lists.first(where: { $0.id == "artist_list" }) else { return }
      self.forYouStations = IdentifiedArray(uniqueElements: artistList.stations)
    }
    .store(in: &disposeBag)
  }

  func handlePlayolaIconTapped10Times() {
    $showSecretStations.withLock { $0 = !$0 }
    presentedAlert = showSecretStations ? .secretStationsTurnedOnAlert : .secretStationsHiddenAlert
  }
}
