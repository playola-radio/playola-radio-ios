//
//  StationPlayer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import ComposableArchitecture
import Combine
import FRadioPlayer
import MediaPlayer
import Foundation
import UIKit

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

class StationPlayer: ObservableObject {
  struct State: Sendable, Equatable {
    static func == (lhs: StationPlayer.State, rhs: StationPlayer.State) -> Bool {
      return lhs.playerStatus == rhs.playerStatus &&
      lhs.playbackState == rhs.playbackState &&
      lhs.currentStation == rhs.currentStation &&
      lhs.nowPlaying == rhs.nowPlaying
    }

    var playbackState: FRadioPlayer.PlaybackState
    var playerStatus: FRadioPlayer.State?
    var currentStation: RadioStation?
    var nowPlaying: FRadioPlayer.Metadata?
  }

  @Published var state: StationPlayer.State = {
    State(playbackState: .stopped, playerStatus: nil, currentStation: nil, nowPlaying: nil)
  }()

  @Published var albumArtworkURL: URL?

  static let shared = StationPlayer()

//  private var trackingService: TrackingService = TrackingService.shared

  @Published private(set) var currentStation: RadioStation?

  var searchedStations: [RadioStation] = []

  private let player = FRadioPlayer.shared

  init() {
    player.addObserver(self)
  }

  func fetch(completion: (([StationList]) -> ())? = nil) {
    completion?([])
  }

  func set(station: RadioStation?) {
    guard let station = station else {
      reset()
      return
    }

    currentStation = station
    player.radioURL = URL(string: station.streamURL)
  }

  private func reset() {
    currentStation = nil
    player.radioURL = nil
  }
}


// MARK: - MPNowPlayingInfoCenter (Lock screen)

extension StationPlayer {

  private func resetArtwork(with station: RadioStation?) {

    guard let station = station else {
      updateLockScreen(with: nil)
      return
    }

    station.getImage { [weak self] image in
      self?.updateLockScreen(with: image)
    }
  }

  private func updateLockScreen(with artworkImage: UIImage?) {

    // Define Now Playing Info
    var nowPlayingInfo = [String : Any]()

    if let image = artworkImage {
      nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { size -> UIImage in
        return image
      })
    }

    if let artistName = currentStation?.artistName {
      nowPlayingInfo[MPMediaItemPropertyArtist] = artistName
    }

    if let trackName = currentStation?.trackName {
      nowPlayingInfo[MPMediaItemPropertyTitle] = trackName
    }

    // Set the metadata
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }
}

// MARK: - FRadioPlayerObserver

extension StationPlayer: FRadioPlayerObserver {

  func radioPlayer(_ player: FRadioPlayer, metadataDidChange metadata: FRadioPlayer.Metadata?) {
    self.state = State(playbackState: FRadioPlayer.shared.playbackState,
                       playerStatus: FRadioPlayer.shared.state,
                       currentStation: self.currentStation,
                       nowPlaying: self.player.currentMetadata)
    resetArtwork(with: currentStation)
  }

  func radioPlayer(_ player: FRadioPlayer, artworkDidChange artworkURL: URL?) {
    self.albumArtworkURL = artworkURL
    guard let artworkURL = artworkURL else {
      resetArtwork(with: currentStation)
      return
    }

    UIImage.image(from: artworkURL) { [weak self] image in
      guard let image = image else {
        self?.resetArtwork(with: self?.currentStation)
        return
      }

      self?.updateLockScreen(with: image)
    }
  }

  func radioPlayer(_ player: FRadioPlayer, playerStateDidChange state: FRadioPlayer.State) {
    self.state = State(playbackState: FRadioPlayer.shared.playbackState,
                       playerStatus: FRadioPlayer.shared.state,
                       currentStation: self.currentStation,
                       nowPlaying: self.player.currentMetadata)
  }

  func radioPlayer(_ player: FRadioPlayer, playbackStateDidChange state: FRadioPlayer.PlaybackState) {
    self.state = State(playbackState: FRadioPlayer.shared.playbackState,
                       playerStatus: FRadioPlayer.shared.state,
                       currentStation: self.currentStation,
                       nowPlaying: self.player.currentMetadata)
  }
}

