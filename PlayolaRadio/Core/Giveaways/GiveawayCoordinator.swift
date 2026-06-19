import Dependencies
import Foundation
import Sharing

/// Owns the live giveaway data path. Polls the now-playing Playola station's `/active` endpoint
/// and publishes the result into `@Shared(.activeGiveaway)`, which drives the player overlay.
///
/// Owned and started by `MainContainerModel` (mirrors `LiveStationsPoller`). Gated by
/// `GiveawayFeature.isLiveDataEnabled` so it's inert in production.
@MainActor
@Observable
final class GiveawayCoordinator {
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.nowPlaying) var nowPlaying
  @ObservationIgnored @Shared(.activeGiveaway) var activeGiveaway

  private var pollingTask: Task<Void, Never>?

  static let pollingInterval: Duration = .seconds(15)

  // MARK: - Lifecycle

  func start() {
    guard GiveawayFeature.isLiveDataEnabled else { return }
    guard pollingTask == nil else { return }
    pollingTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.pollActiveGiveaway()
        try? await Task.sleep(for: Self.pollingInterval)
      }
    }
  }

  func stop() {
    pollingTask?.cancel()
    pollingTask = nil
  }

  /// Fire an immediate poll (on foreground / now-playing change) without waiting for the interval.
  func pollNow() async {
    guard GiveawayFeature.isLiveDataEnabled else { return }
    await pollActiveGiveaway()
  }

  // MARK: - Polling

  func pollActiveGiveaway() async {
    guard let jwtToken = auth.jwt else { return }
    guard let stationId = currentPlayolaStationId else {
      // Not on a Playola station — there is authoritatively no giveaway to show.
      $activeGiveaway.withLock { $0 = nil }
      return
    }
    do {
      let giveaway = try await api.activeGiveaway(jwtToken, stationId)
      // Guard against a station switch mid-request: only publish for the station we asked about.
      guard currentPlayolaStationId == stationId else { return }
      $activeGiveaway.withLock { $0 = giveaway }
    } catch {
      // Network / decode / auth failure: keep the last known value rather than clearing it, so a
      // transient error can't make the overlay vanish. The next poll retries.
    }
  }

  // MARK: - Private Helpers

  private var currentPlayolaStationId: String? {
    guard let anyStation = nowPlaying?.currentStation,
      case .playola(let station) = anyStation
    else { return nil }
    return station.id
  }
}
