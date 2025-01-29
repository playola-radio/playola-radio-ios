//
//  StationPlayerClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import ComposableArchitecture
import Foundation

struct StationPlayerClient {
    var subscribeToPlayerState: @Sendable () async -> AsyncStream<URLStreamPlayer.State>
    var subscribeToAlbumImageURL: @Sendable () async -> AsyncStream<URL?>
    var playStation: @Sendable (RadioStation) -> Void
}

private enum StationPlayerKey: DependencyKey {
    static let liveValue: StationPlayerClient = StationPlayerClient {
        AsyncStream<URLStreamPlayer.State> { continuation in
            let cancellable = URLStreamPlayer.shared.$state.sink { continuation.yield($0) }
            continuation.onTermination = { _ in cancellable.cancel() }
        }
    } subscribeToAlbumImageURL: {
        AsyncStream<URL?> { continuation in
            let cancellable = URLStreamPlayer.shared.$albumArtworkURL.sink { continuation.yield($0) }
            continuation.onTermination = { _ in cancellable.cancel() }
        }
    } playStation: { station in URLStreamPlayer.shared.set(station: station) }
}

extension DependencyValues {
    var stationPlayer: StationPlayerClient {
        get { self[StationPlayerKey.self] }
        set { self[StationPlayerKey.self] = newValue }
    }
}
