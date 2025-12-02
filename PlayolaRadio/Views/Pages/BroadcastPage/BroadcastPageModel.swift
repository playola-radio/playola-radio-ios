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
  private let providedStationName: String?
  private var fetchedStationName: String?
  var schedule: Schedule?
  var isLoading: Bool = false
  var presentedAlert: PlayolaAlert?
  var currentNowPlayingId: String?
  private var reorderedSpinIds: [String]?  // nil means use default order

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Shared(.auth) var auth

  var navigationTitle: String {
    providedStationName ?? fetchedStationName ?? "My Station"
  }

  init(stationId: String, stationName: String? = nil) {
    self.stationId = stationId
    self.providedStationName = stationName
    super.init()
  }

  func viewAppeared() async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.loadSchedule() }
      group.addTask { await self.loadStation() }
    }
  }

  private func loadStation() async {
    guard providedStationName == nil else { return }
    guard let jwt = auth.jwt else { return }
    do {
      if let station = try await api.fetchStation(jwt, stationId) {
        fetchedStationName = station.name
      }
    } catch {
      // Silently fail - we'll just show the default title
    }
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
    let futureSpins = schedule.current().filter { $0.airtime > now }

    // If we have a custom order, use it
    if let orderedIds = reorderedSpinIds {
      let spinDict = Dictionary(uniqueKeysWithValues: futureSpins.map { ($0.id, $0) })
      // Return spins in the custom order, filtering out any that are no longer in futureSpins
      return orderedIds.compactMap { spinDict[$0] }
    }

    return futureSpins
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

  /// Handles moving spins in the list, automatically including grouped spins
  func moveSpins(from source: IndexSet, to destination: Int) {
    var spins = upcomingSpins

    // Get the indices being moved and check for grouped spins
    var indicesToMove = source
    for index in source {
      guard index < spins.count else { continue }
      let spin = spins[index]
      if let groupId = spin.spinGroupId {
        // Find all spins in the same group and add their indices
        for (i, s) in spins.enumerated() where s.spinGroupId == groupId {
          indicesToMove.insert(i)
        }
      }
    }

    // Sort indices to maintain relative order
    let sortedIndices = indicesToMove.sorted()

    // Extract the spins to move (in order)
    let spinsToMove = sortedIndices.map { spins[$0] }

    // Remove from original positions (in reverse to maintain indices)
    for index in sortedIndices.reversed() {
      spins.remove(at: index)
    }

    // Calculate adjusted destination
    let adjustedDestination = min(
      destination - sortedIndices.filter { $0 < destination }.count,
      spins.count
    )

    // Insert at destination
    spins.insert(contentsOf: spinsToMove, at: max(0, adjustedDestination))

    // Store the new order
    reorderedSpinIds = spins.map { $0.id }

    // TODO: Sync to API
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
