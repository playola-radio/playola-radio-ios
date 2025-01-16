//
//  PlayolaStationPlayerClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/19/24.
//
//
import Foundation
import ComposableArchitecture
import PlayolaPlayer
//

struct PlayolaStationPlayerClient {
  var subscribeToPlayerState: @Sendable () async -> AsyncStream<PlayolaStationPlayer.State>
  var playStation: @Sendable (String) async -> Void
  //  var stopStation: @Sendable () -> Void
}

private enum PlayolaStationPlayerKey: DependencyKey {
  static let liveValue: PlayolaStationPlayerClient = PlayolaStationPlayerClient {
    return AsyncStream<PlayolaStationPlayer.State> { @MainActor continuation in
      let cancellable = PlayolaStationPlayer.shared.$state.sink { continuation.yield($0) }
      continuation.onTermination = { _ in cancellable.cancel() }
    }
  } playStation: { stationId async in
    try! await PlayolaStationPlayer.shared.play(stationId: stationId)
  }
}
