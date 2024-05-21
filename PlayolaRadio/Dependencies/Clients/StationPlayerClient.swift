//
//  StationPlayerClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Foundation
import ComposableArchitecture

struct StationPlayerClient {
  var subscribeToPlayerState: @Sendable () async -> AsyncStream<StationPlayer.State>
  var subscribeToAlbumImageURL: @Sendable () async -> AsyncStream<URL?>
  var playStation: @Sendable (RadioStation) -> Void
}

private enum StationPlayerKey: DependencyKey {
  static let liveValue: StationPlayerClient = StationPlayerClient {
    return AsyncStream<StationPlayer.State> { continuation in
      let cancellable = StationPlayer.shared.$state.sink { continuation.yield($0) }
      continuation.onTermination = { _ in cancellable.cancel() }
    }
  } subscribeToAlbumImageURL: {
    return AsyncStream<URL?> { continuation in
      let cancellable = StationPlayer.shared.$albumArtworkURL.sink { continuation.yield($0) }
      continuation.onTermination = { _ in cancellable.cancel() }
    }
  } playStation: { station in StationPlayer.shared.set(station: station) }
}

extension DependencyValues {
  var stationPlayer: StationPlayerClient {
    get { self[StationPlayerKey.self] }
    set { self[StationPlayerKey.self] = newValue }
  }
}
