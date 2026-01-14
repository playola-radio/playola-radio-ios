//
//  LiveStationsPoller.swift
//  PlayolaRadio
//
//  Created by Brian Keane on 1/14/26.
//

import Dependencies
import Foundation
import Sharing

@MainActor
@Observable
final class LiveStationsPoller {
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

  private var pollingTask: Task<Void, Never>?

  private static let pollingInterval: Duration = .seconds(30)

  func startPolling() {
    guard pollingTask == nil else { return }

    pollingTask = Task {
      while !Task.isCancelled {
        await fetchLiveStations()
        try? await Task.sleep(for: Self.pollingInterval)
      }
    }
  }

  func stopPolling() {
    pollingTask?.cancel()
    pollingTask = nil
  }

  func fetchLiveStations() async {
    do {
      let stations = try await api.fetchLiveStations()
      $liveStations.withLock { $0 = stations }
    } catch {
      // Silently fail, keep existing data
    }
  }
}
