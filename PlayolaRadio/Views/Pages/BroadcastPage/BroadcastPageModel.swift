//
//  BroadcastPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 11/30/25.
//

import Combine
import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI

struct DependencyDateProvider: DateProviderProtocol {
  @Dependency(\.date.now) var currentDate

  func now() -> Date {
    currentDate
  }
}

@MainActor
@Observable
class BroadcastPageModel: ViewModel {
  let stationId: String
  var schedule: Schedule?
  var isLoading: Bool = false
  var presentedAlert: PlayolaAlert?
  var currentNowPlayingId: String?

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now

  init(stationId: String) {
    self.stationId = stationId
    super.init()
  }

  func viewAppeared() async {
    await loadSchedule()
  }

  func loadSchedule() async {
    isLoading = true
    defer { isLoading = false }

    do {
      let spins = try await api.fetchSchedule(stationId, true)
      schedule = Schedule(
        stationId: stationId, spins: spins, dateProvider: DependencyDateProvider()
      )
      currentNowPlayingId = nowPlaying?.id
    } catch {
      presentedAlert = .errorLoadingSchedule
    }
  }

  var nowPlaying: Spin? {
    schedule?.nowPlaying()
  }

  var upcomingSpins: [Spin] {
    guard let schedule else { return [] }
    return schedule.current().filter { $0.airtime > now }
  }

  var nowPlayingProgress: Double {
    guard let spin = nowPlaying else { return 0 }
    let elapsed = now.timeIntervalSince(spin.airtime)
    let duration = Double(spin.audioBlock.endOfMessageMS) / 1000.0
    guard duration > 0 else { return 0 }
    return min(max(elapsed / duration, 0), 1)
  }

  func tick() {
    let newNowPlayingId = nowPlaying?.id
    if newNowPlayingId != currentNowPlayingId {
      currentNowPlayingId = newNowPlayingId
    }
  }
}

extension PlayolaAlert {
  static var errorLoadingSchedule: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "Unable to load the station schedule. Please try again.",
      dismissButton: .cancel(Text("OK"))
    )
  }
}
