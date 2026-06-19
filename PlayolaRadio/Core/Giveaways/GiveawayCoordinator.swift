import Combine
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

  @ObservationIgnored private var pollingTask: Task<Void, Never>?
  @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
  @ObservationIgnored private var hasObservedStation = false
  @ObservationIgnored private var lastObservedStationId: String?

  static let pollingInterval: Duration = .seconds(15)

  // MARK: - Lifecycle

  func start() {
    guard GiveawayFeature.isLiveDataEnabled else { return }
    observeStationChanges()
    startPolling()
  }

  func stop() {
    pollingTask?.cancel()
    pollingTask = nil
    cancellables.removeAll()
  }

  /// Fire an immediate poll (e.g. on foreground) without waiting for the interval.
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

  private func startPolling() {
    guard pollingTask == nil else { return }
    pollingTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.pollActiveGiveaway()
        try? await Task.sleep(for: Self.pollingInterval)
      }
    }
  }

  /// Re-poll the instant the now-playing station settles on a new value, so the overlay appears
  /// promptly after a station switch instead of waiting up to one poll interval. `nowPlaying`
  /// also changes per song, so we de-dupe on the station id.
  private func observeStationChanges() {
    guard cancellables.isEmpty else { return }
    $nowPlaying.publisher
      .sink { [weak self] _ in self?.nowPlayingChanged() }
      .store(in: &cancellables)
  }

  private func nowPlayingChanged() {
    let stationId = currentPlayolaStationId
    guard !hasObservedStation || stationId != lastObservedStationId else { return }
    hasObservedStation = true
    lastObservedStationId = stationId
    Task { await pollActiveGiveaway() }
  }

  private var currentPlayolaStationId: String? {
    guard let anyStation = nowPlaying?.currentStation,
      case .playola(let station) = anyStation
    else { return nil }
    return station.id
  }
}
