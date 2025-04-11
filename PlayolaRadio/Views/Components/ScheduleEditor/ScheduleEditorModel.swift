//
//  ScheduleEditorModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/10/25.
//

import Combine
import SwiftUI
import PlayolaPlayer
import Dependencies
import Sharing

@MainActor
@Observable
class ScheduleEditorModel: ViewModel {
  var station: Station
  var stagingAreaAudioBlocks: [AudioBlock] = []
  var nowPlaying: Spin? = nil {
    didSet {
      if oldValue != nowPlaying {
        scheduleNextNowPlayingUpdate()
      }
    }
  }
  var upcomingSpins: [Spin] = []
  var nowPlayingTimer: Timer? = nil
  var schedule: Schedule? = nil {
    didSet {
      updateFromSchedule()
    }
  }

  @ObservationIgnored private var cancellables = Set<AnyCancellable>()
  @ObservationIgnored private var refreshTimer: Timer?
  @ObservationIgnored @Dependency(GenericApiClient.self) var genericApiClient
  @ObservationIgnored @Dependency(\.date.now) var now

  @ObservationIgnored @Shared(.auth) var auth

  public init(station: Station) {
    self.station = station
    super.init()
  }

  func viewAppeared() async {
    await refreshSchedule()
    setupRefreshTimer()
  }

  func viewDisappeared() {
    refreshTimer?.invalidate()
    refreshTimer = nil
  }

  private func setupRefreshTimer() {
    refreshTimer?.invalidate()
    if let fireTime = nextAirtime(for: schedule) {
      refreshTimer = Timer.scheduledTimer(withTimeInterval: Date().timeIntervalSince(fireTime), repeats: false) { [weak self] _ in
        guard let self = self else { return }
        Task { @MainActor in
          if self.nowPlaying != self.schedule?.nowPlaying {
            Task { @MainActor in
              self.updateFromSchedule()
              self.scheduleNextNowPlayingUpdate()
            }
          } else {
            print("nowPlaying was equal")
          }
        }
      }
    }

  }

  func refreshSchedule() async {
    do {
      self.schedule = try await genericApiClient.fetchSchedule(station.id, true, auth)
    } catch (let err) {
      print("error downloading schedule: \(err)")
    }
  }

  private func updateFromSchedule() {
    print("updateFromSchedule")
    if let schedule {
      let calculatedUpcomingSpins = schedule.current
        .filter {
          $0.endtime > now &&
          $0.airtime > now &&
          $0 != schedule.nowPlaying &&
          $0 != self.nowPlaying
      }
      print("setting nowPlaying")
      self.nowPlaying = schedule.nowPlaying
      self.upcomingSpins = calculatedUpcomingSpins
    }
  }

  private func nextAirtime(for schedule: Schedule?) -> Date? {
    guard let schedule else { return nil }
    return schedule.spins.filter { $0.airtime > now }.first?.airtime
  }

  private func scheduleNextNowPlayingUpdate() {
    print("scheduling")
    nowPlayingTimer?.invalidate()

    if let fireTime = nextAirtime(for: self.schedule) {
      print("scheduling for firetime \(fireTime)")
      nowPlayingTimer = Timer.scheduledTimer(withTimeInterval: -now.timeIntervalSince(fireTime), repeats: false) { [weak self] _ in
        Task { @MainActor in self?.updateFromSchedule() }
      }
    }
  }
}
