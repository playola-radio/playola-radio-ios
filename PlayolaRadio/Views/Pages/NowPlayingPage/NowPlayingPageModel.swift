//
//  NowPlayingPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//
import Observation
import Combine
import Foundation

@MainActor
@Observable
class NowPlayingPageModel: ViewModel {
    var disposeBag: Set<AnyCancellable> = Set()

    // MARK: State

    var albumArtUrl: URL?
    var nowPlayingArtist: String = ""
    var nowPlayingTitle: String = ""
    var navigationBarTitle: String = ""
    var presentedSheet: PlayolaSheet?

  var navigationCoordinator: NavigationCoordinator!

    init(stationPlayer: StationPlayer? = nil,
         navigationCoordinator: NavigationCoordinator = .shared,
         presentedSheet: PlayolaSheet? = nil)
    {
        self.stationPlayer = stationPlayer ?? StationPlayer.shared
        self.navigationCoordinator = navigationCoordinator
        self.presentedSheet = presentedSheet
    }

    // MARK: Dependencies

    @ObservationIgnored var stationPlayer: StationPlayer

    func viewAppeared() {
        processNewStationState(stationPlayer.state)

        stationPlayer.$state.sink { self.processNewStationState($0) }.store(in: &disposeBag)
    }

    func aboutButtonTapped() {
        presentedSheet = .about(AboutPageModel())
    }

    func infoButtonTapped() {}
    func shareButtonTapped() {}
    func dismissAboutSheetButtonTapped() {
        presentedSheet = nil
    }

    func stopButtonTapped() {
        stationPlayer.stop()
        navigationCoordinator.path.removeLast()
    }

    // MARK: Actions

    // MARK: Helpers

    func processNewStationState(_ state: StationPlayer.State) {
        switch state.playbackStatus {
        case let .playing(radioStation):
            navigationBarTitle = "\(radioStation.name) \(radioStation.desc)"
            nowPlayingTitle = state.titlePlaying ?? "-------"
            nowPlayingArtist = state.artistPlaying ?? "-------"
            albumArtUrl = state.albumArtworkUrl ?? URL(string: radioStation.imageURL)
        case let .loading(radioStation, progress):
            navigationBarTitle = "\(radioStation.name) \(radioStation.desc)"
            nowPlayingTitle = "\(radioStation.name) \(radioStation.desc)"
            if let progress {
                nowPlayingArtist = "Station Loading... \(Int(round(progress * 100)))%"
            } else {
                nowPlayingArtist = "Station Loading..."
            }

            albumArtUrl = URL(string: radioStation.imageURL)
        case .stopped:
            navigationBarTitle = "Playola Radio"
            nowPlayingArtist = "Player Stopped"
            nowPlayingTitle = "Player Stopped"
            albumArtUrl = nil
        case .error:
            navigationBarTitle = "Playola Radio"
            nowPlayingTitle = ""
            nowPlayingArtist = "Error Playing Station"
            albumArtUrl = nil
        }
    }
}
