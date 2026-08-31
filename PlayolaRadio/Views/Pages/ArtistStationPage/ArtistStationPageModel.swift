//
//  ArtistStationPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

import Combine
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import SwiftUI

// NOTE: The now-playing / up-next broadcast card is wired to the station's live schedule.
// The surrounding chrome (station name, "ON AIR NOW" / broadcast status, "last went live")
// are still hard-coded placeholders pending follow-up wiring.
@MainActor
@Observable
class ArtistStationPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now

  // MARK: - Shared State

  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Properties

  var schedule: Schedule?
  var isLoading = false
  var hasLoadError = false

  @ObservationIgnored private var scheduleUpdateCancellable: AnyCancellable?
  @ObservationIgnored private var loadGeneration = 0

  var navigationTitle: String { "Station" }
  var stationName: String { "Reckless Radio" }

  var onAirLabel: String { "ON AIR NOW" }
  var broadcastStatusLabel: String { "Auto DJ" }
  var broadcastStatusColor: Color { Color(hex: "#34C759") }

  var nowPlayingTitle: String {
    if let spin = nowPlayingSpin { return spin.audioBlock.title }
    if isLoading { return "Loading…" }
    if hasLoadError { return "Unable to load broadcast" }
    return "Nothing playing right now"
  }

  var nowPlayingSubtitle: String {
    guard let spin = nowPlayingSpin else { return "" }
    let artist = spin.audioBlock.artist
    guard let upNext = upNextSpin else { return artist }
    return "\(artist) · up next: \(upNext.audioBlock.title)"
  }

  var nowPlayingProgress: Double {
    guard let spin = nowPlayingSpin else { return 0 }
    return spin.progress(at: now)
  }

  var lastWentLiveLabel: String { "Last went live 4 days ago" }
  var viewFullScheduleLabel: String { "View Full Schedule" }

  var showsLinkTitle: String { "Shows" }
  var musicLibraryLinkTitle: String { "Music Library" }
  var breakersLibraryLinkTitle: String { "Breakers Library" }

  // MARK: - View Helpers

  var nowPlayingSpin: Spin? { schedule?.nowPlaying() }
  var upNextSpin: Spin? { schedule?.current().first { $0.airtime > now } }

  // MARK: - User Actions

  func viewAppeared() async {
    startObservingScheduleUpdates()
    await loadSchedule()
  }

  func broadcastCardTapped() {
    guard let stationId else { return }
    navigationCoordinator.push(.broadcastPage(BroadcastPageModel(stationId: stationId)))
  }

  func showsRowTapped() {}

  func musicLibraryRowTapped() {}

  func breakersLibraryRowTapped() {
    guard let stationId else { return }
    navigationCoordinator.push(.breakersLibraryPage(BreakersLibraryPageModel(stationId: stationId)))
  }

  // MARK: - Private Helpers

  private var stationId: String? {
    if case .broadcasting(let stationId) = navigationCoordinator.appMode {
      return stationId
    }
    return nil
  }

  private func loadSchedule() async {
    guard let stationId else { return }
    loadGeneration += 1
    let generation = loadGeneration
    isLoading = true
    hasLoadError = false
    do {
      let spins = try await api.fetchSchedule(stationId, true)
      guard generation == loadGeneration else { return }
      schedule = Schedule(
        stationId: stationId, spins: spins, dateProvider: DependencyDateProvider())
    } catch {
      guard generation == loadGeneration else { return }
      hasLoadError = true
    }
    isLoading = false
  }

  private func startObservingScheduleUpdates() {
    guard scheduleUpdateCancellable == nil, stationId != nil else { return }
    scheduleUpdateCancellable = NotificationCenter.default.publisher(for: .scheduleUpdated)
      .compactMap { $0.userInfo?["stationId"] as? String }
      .sink { [weak self] notificationStationId in
        guard let self, notificationStationId == self.stationId else { return }
        Task { [weak self] in await self?.loadSchedule() }
      }
  }
}
