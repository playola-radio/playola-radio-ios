//
//  ArtistDashboardTabRootModel.swift
//  PlayolaRadio
//

import Dependencies
import Observation
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class ArtistDashboardTabRootModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Types

  enum Route {
    case loading
    case active(ArtistDashboardPageModel)
    case setup(StationSetupPageModel)
    case failed
  }

  // MARK: - State

  /// Bumped once per `viewAppeared`. A slow, now-stale fetch that resolves after a newer one has
  /// started must not clobber the newer route, mirroring `ArtistDashboardPageModel`'s guard.
  private var loadGeneration = 0
  var route: Route = .loading

  // MARK: - Properties

  var loadingText: String { "Loading…" }
  var failedTitle: String { "Something went wrong" }
  var failedMessage: String {
    "We couldn't load this station's dashboard. Please try again later."
  }

  // MARK: - User Actions

  func viewAppeared() async {
    // Bump first so an early-return (missing auth / not broadcasting) still invalidates any older
    // in-flight `fetchStation`; otherwise a stale fetch could pass the guard below and overwrite
    // the `.failed` route with `.active`/`.setup`, mounting the wrong child.
    loadGeneration += 1
    let generation = loadGeneration
    guard let token = auth.jwt, let stationId else {
      route = .failed
      return
    }
    route = .loading
    do {
      let station = try await api.fetchStation(token, stationId)
      guard generation == loadGeneration else { return }
      guard let station else {
        route = .failed
        await analytics.track(
          .apiError(endpoint: "fetchStation", error: "station not found"))
        return
      }
      if station.active == false {
        route = .setup(StationSetupPageModel(station: station))
      } else {
        route = .active(ArtistDashboardPageModel())
      }
    } catch {
      guard !isCancellation(error) else { return }
      guard generation == loadGeneration else { return }
      route = .failed
      await analytics.track(
        .apiError(endpoint: "fetchStation", error: error.localizedDescription))
    }
  }

  // MARK: - Private Helpers

  private var stationId: String? {
    if case .broadcasting(let stationId) = navigationCoordinator.appMode {
      return stationId
    }
    return nil
  }

  /// A cancelled `.task` auto-cancels the in-flight request (Alamofire surfaces
  /// `AFError.explicitlyCancelled`, so `Task.isCancelled` is already set). Treat that as a
  /// non-event: leave the route as-is for a navigation away.
  private func isCancellation(_ error: any Error) -> Bool {
    Task.isCancelled || error is CancellationError
  }
}
