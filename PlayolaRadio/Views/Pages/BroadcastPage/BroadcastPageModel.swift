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

  @ObservationIgnored @Dependency(\.api) var api

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
      let spins = try await api.fetchSchedule(stationId, 500)
      schedule = Schedule(
        stationId: stationId, spins: spins, dateProvider: DependencyDateProvider())
    } catch {
      presentedAlert = .errorLoadingSchedule
    }
  }

  var nowPlaying: Spin? {
    schedule?.nowPlaying()
  }

  var upcomingSpins: [Spin] {
    guard let schedule else { return [] }
    return schedule.current().filter { $0.id != nowPlaying?.id }
  }
}

extension PlayolaAlert {
  static var errorLoadingSchedule: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "Unable to load the station schedule. Please try again.",
      dismissButton: .cancel(Text("OK")))
  }
}
