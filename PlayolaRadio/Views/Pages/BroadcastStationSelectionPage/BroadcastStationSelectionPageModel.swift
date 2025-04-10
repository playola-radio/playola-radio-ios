//
//  BroadcastStationSelectionPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//
import Observation
import PlayolaPlayer
import Sharing
import Dependencies

@MainActor
@Observable
class BroadcastStationSelectionPageModel: ViewModel {
  // These properties will trigger updates when changed
  var stations: [PlayolaPlayer.Station] = []
  var isLoading: Bool = false
  var selectedStation: PlayolaPlayer.Station?

  // Dependencies should be marked with @ObservationIgnored
  @ObservationIgnored var navigationCoordinator: NavigationCoordinator

  @ObservationIgnored @Dependency(GenericApiClient.self) var genericApiClient

  @ObservationIgnored @Shared(.auth) var auth: Auth
  @ObservationIgnored @Shared(.currentUser) var currentUser: User?

  init(navigationCoordinator: NavigationCoordinator = .shared) {
    self.navigationCoordinator = navigationCoordinator
    super.init()
  }

  func viewAppeared() async {
    print("🔄 Starting viewAppeared")
    guard !isLoading else { return }
    
    do {
        isLoading = true
        print("🔄 Set isLoading to true")
        
      let fetchedStations = try await genericApiClient.fetchUserStations(auth.jwtUser!.id, auth)
        print("✅ Fetched \(fetchedStations.count) stations")
        
        // Update all related state together
        stations = fetchedStations
        if fetchedStations.count == 1 {
            selectedStation = fetchedStations.first!
        }
        isLoading = false
        print("✅ Set isLoading to false")
        
    } catch let error {
        print("❌ Error fetching stations: \(error)")
        isLoading = false
    }
  }

  func stationSelected(_ station: PlayolaPlayer.Station) {
    navigationCoordinator.path.append(.broadcastBase(BroadcastBaseModel(station: station)))
  }
}
