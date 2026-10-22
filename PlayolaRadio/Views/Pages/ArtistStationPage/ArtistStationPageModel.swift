//
//  ArtistStationPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/28/26.
//

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
  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.errorReporting) var errorReporting
  @ObservationIgnored @Dependency(\.notificationCenter) var notificationCenter
  @ObservationIgnored @Dependency(\.toast) var toast

  // MARK: - Shared State

  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Properties

  var schedule: Schedule?
  var currentDate: Date?
  var isLoading = false
  var hasLoadError = false
  var presentedAlert: PlayolaAlert?

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
    guard let spin = nowPlayingSpin, let currentDate else { return 0 }
    return spin.progress(at: currentDate)
  }

  var lastWentLiveLabel: String { "Last went live 4 days ago" }
  var viewFullScheduleLabel: String { "View Full Schedule" }

  var showsLinkTitle: String { "Shows" }
  var musicLibraryLinkTitle: String { "Music Library" }
  var breakersLibraryLinkTitle: String { "Breakers Library" }

  // MARK: - View Helpers

  var nowPlayingSpin: Spin? {
    guard let currentDate else { return nil }
    return schedule?.spins
      .filter { $0.airtime <= currentDate && currentDate < $0.endtime }
      .max { $0.airtime < $1.airtime }
  }

  var upNextSpin: Spin? {
    guard let currentDate else { return nil }
    return schedule?.spins
      .filter { $0.airtime > currentDate }
      .min { $0.airtime < $1.airtime }
  }

  // MARK: - User Actions

  func viewAppeared() async {
    currentDate = now
    await loadSchedule(isUserInitiated: true)
  }

  func observeScheduleUpdates(onReady: @escaping @MainActor () -> Void = {}) async {
    let notifications = notificationCenter.notifications(named: .scheduleUpdated)
    onReady()
    for await notification in notifications {
      guard !Task.isCancelled else { return }
      guard notification.userInfo?["stationId"] as? String == stationId else { continue }
      await loadSchedule(isUserInitiated: false)
    }
  }

  func stationTabVisible() async {
    currentDate = now
    while !Task.isCancelled {
      do { try await clock.sleep(for: .milliseconds(500)) } catch { break }
      currentDate = now
    }
  }

  func broadcastCardTapped() {
    guard let stationId else { return }
    navigationCoordinator.push(.broadcastPage(BroadcastPageModel(stationId: stationId)))
  }

  func showsRowTapped() {
    guard let stationId else { return }
    navigationCoordinator.push(.showsPage(ShowsPageModel(stationId: stationId)))
  }

  func musicLibraryRowTapped() {
    guard let stationId else { return }
    navigationCoordinator.push(.musicLibraryPage(MusicLibraryPageModel(stationId: stationId)))
  }

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

  private func loadSchedule(isUserInitiated: Bool) async {
    guard let stationId else { return }
    loadGeneration += 1
    let generation = loadGeneration
    isLoading = true
    defer { if generation == loadGeneration { isLoading = false } }
    do {
      let spins = try await api.fetchSchedule(stationId, true)
      guard generation == loadGeneration, !Task.isCancelled else { return }
      hasLoadError = false
      schedule = Schedule(
        stationId: stationId, spins: spins, dateProvider: DependencyDateProvider())
    } catch {
      guard generation == loadGeneration, !Task.isCancelled,
        !(error is CancellationError), (error as? URLError)?.code != .cancelled
      else { return }
      hasLoadError = true
      if !NetworkErrorClassifier.isNetworkError(error) {
        var tags = NetworkErrorClassifier.errorTags(for: error)
        tags["endpoint"] = "fetchSchedule"
        await errorReporting.reportError(error, tags)
      }
      guard generation == loadGeneration, !Task.isCancelled, isUserInitiated else { return }
      await toast.show(
        PlayolaToast(message: "The station schedule couldn't load.", buttonTitle: "OK"))
    }
  }
}
