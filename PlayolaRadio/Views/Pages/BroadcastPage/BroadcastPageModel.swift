//
//  BroadcastPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//
import Sharing
import PlayolaPlayer
import Dependencies
import SwiftUI
import Combine

@MainActor
@Observable
class BroadcastPageModel: ViewModel {
  var disposeBag: Set<AnyCancellable> = Set()
  var station: Station
  var schedule: Schedule?

  var scheduleEditorModel: ScheduleEditorModel!
  var navigationCoordinator: NavigationCoordinator!

  // MARK: - State
  var recordingViewIsPresented: Bool = false
  var addSongViewIsPresented: Bool = false
  var presentedAlert: PlayolaAlert?

  // Demo data for display
  var stagingAudioBlocks: [AudioBlock] = []
  var playlist: [Spin] = []
  var nowPlaying: Spin?

  // MARK: - Dependencies
  @ObservationIgnored @Dependency(APIClient.self) var apiClient

  init(station: Station, navigationCoordinator: NavigationCoordinator = .shared) {
    self.station = station
    self.scheduleEditorModel = ScheduleEditorModel(station: station)
    print("BroadcastPageModel init with station: \(station.id)")
    self.navigationCoordinator = navigationCoordinator
    super.init()
  }

  // MARK: - Actions
  func viewAppeared() async {
    print("BroadcastPageModel viewAppeared for station: \(station.id)")
    self.schedule = try? await apiClient.fetchSchedule(stationId: station.id)
  }
  func showRecordingView() {
    recordingViewIsPresented = true
  }

  func showAddSongView() {
    addSongViewIsPresented = true
  }

  func hamburgerButtonTapped() {
    navigationCoordinator.slideOutMenuIsShowing = true
  }
}
