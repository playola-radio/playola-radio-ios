//
//  NowPlayingUpdater.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/20/25.
//
import Combine
import Foundation
import MediaPlayer
import PlayolaPlayer
import Sharing

// MARK: - Now Playing Data Structure

struct NowPlaying: Equatable, Codable {
  let artistPlaying: String?
  let titlePlaying: String?
  let albumArtworkUrl: URL?
  let playolaSpinPlaying: Spin?
  let currentStation: RadioStation?
  let playbackStatus: StationPlayer.PlaybackStatus

  init(
    artistPlaying: String? = nil,
    titlePlaying: String? = nil,
    albumArtworkUrl: URL? = nil,
    playolaSpinPlaying: Spin? = nil,
    currentStation: RadioStation? = nil,
    playbackStatus: StationPlayer.PlaybackStatus = .stopped
  ) {
    self.artistPlaying = artistPlaying
    self.titlePlaying = titlePlaying
    self.albumArtworkUrl = albumArtworkUrl
    self.playolaSpinPlaying = playolaSpinPlaying
    self.currentStation = currentStation
    self.playbackStatus = playbackStatus
  }
}

// MARK: - Shared Storage Extension

@MainActor
class NowPlayingUpdater {
  var stationPlayer: StationPlayer

  static var shared = NowPlayingUpdater()

  @ObservationIgnored @Shared(.nowPlaying) var nowPlaying

  private var disposeBag = Set<AnyCancellable>()
  private func updateNowPlaying(with stationPlayerState: StationPlayer.State) {
    var nowPlayingInfo = [String: Any]()

    guard let currentStation = stationPlayer.currentStation else {
      MPNowPlayingInfoCenter.default().playbackState = .stopped
      return
    }
    MPNowPlayingInfoCenter.default().playbackState = .playing

    if let artistPlaying = stationPlayerState.artistPlaying {
      nowPlayingInfo[MPMediaItemPropertyArtist] = artistPlaying
    }

    if let titlePlaying = stationPlayerState.titlePlaying {
      nowPlayingInfo[MPMediaItemPropertyTitle] = titlePlaying
    }

    if let imageUrl = stationPlayerState.albumArtworkUrl
      ?? URL(string: currentStation.imageURL)
    {
      UIImage.image(from: imageUrl) { image in
        if let image {
          Task { await self.updateNowPlayingImage(image) }
        }
      }
    }

    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func updateNowPlayingImage(_ image: UIImage) {
    var nowPlayingInfo: [String: Any] =
      MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
    nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
      boundsSize: image.size,
      requestHandler: { _ in
        image
      })
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  init(stationPlayer: StationPlayer? = nil) {
    self.stationPlayer = stationPlayer ?? .shared
    self.stationPlayer.$state.sink { state in
      self.updateNowPlaying(with: state)
    }.store(in: &disposeBag)
    setupRemoteControlCenter()
    setupSharedStateObservation()
  }

  // MARK: - Shared State Management

  private func setupSharedStateObservation() {
    // Observe PlayolaStationPlayer state changes
    PlayolaStationPlayer.shared.$state
      .sink { [weak self] playolaState in
        self?.processPlayolaStationPlayerState(playolaState)
      }
      .store(in: &disposeBag)

    // Observe URLStreamPlayer state changes
    URLStreamPlayer.shared.$state
      .sink { [weak self] urlStreamState in
        self?.processUrlStreamStateChanged(urlStreamState)
      }
      .store(in: &disposeBag)
  }

  // MARK: - State Processing Methods (duplicated from StationPlayer)

  func processPlayolaStationPlayerState(_ playolaState: PlayolaStationPlayer.State?) {
    switch playolaState {
    case .idle:
      $nowPlaying.withLock {
        $0 = NowPlaying(
          artistPlaying: nil,
          titlePlaying: nil,
          albumArtworkUrl: nil,
          playolaSpinPlaying: nil,
          currentStation: nil,
          playbackStatus: .stopped
        )
      }
    case let .loading(progress):
      guard let currentStation = stationPlayer.currentStation else { return }
      $nowPlaying.withLock {
        $0 = NowPlaying(
          artistPlaying: nil,
          titlePlaying: nil,
          albumArtworkUrl: nil,
          playolaSpinPlaying: nil,
          currentStation: currentStation,
          playbackStatus: .loading(currentStation, progress)
        )
      }
    case let .playing(nowPlayingData):
      if let currentStation = stationPlayer.currentStation {
        $nowPlaying.withLock {
          $0 = NowPlaying(
            artistPlaying: nowPlayingData.audioBlock.artist,
            titlePlaying: nowPlayingData.audioBlock.title,
            albumArtworkUrl: nowPlayingData.audioBlock.imageUrl,
            playolaSpinPlaying: nowPlayingData,
            currentStation: currentStation,
            playbackStatus: .playing(currentStation)
          )
        }
      }
    case .none:
      $nowPlaying.withLock {
        $0 = NowPlaying(
          artistPlaying: nil,
          titlePlaying: nil,
          albumArtworkUrl: nil,
          playolaSpinPlaying: nil,
          currentStation: nil,
          playbackStatus: .error
        )
      }
    }
  }

  private func processUrlStreamStateChanged(_ urlStreamPlayerState: URLStreamPlayer.State) {
    switch urlStreamPlayerState.playerStatus {
    case .loading:
      guard let currentStation = stationPlayer.currentStation else { return }
      $nowPlaying.withLock {
        $0 = NowPlaying(
          artistPlaying: nil,
          titlePlaying: nil,
          albumArtworkUrl: nil,
          playolaSpinPlaying: nil,
          currentStation: currentStation,
          playbackStatus: .loading(currentStation)
        )
      }
    case .loadingFinished, .readyToPlay:
      guard let currentStation = stationPlayer.currentStation else { return }
      $nowPlaying.withLock {
        $0 = NowPlaying(
          artistPlaying: urlStreamPlayerState.nowPlaying?.artistName,
          titlePlaying: urlStreamPlayerState.nowPlaying?.trackName,
          albumArtworkUrl: nil,
          playolaSpinPlaying: nil,
          currentStation: currentStation,
          playbackStatus: .playing(currentStation)
        )
      }
    case .error:
      $nowPlaying.withLock {
        $0 = NowPlaying(
          artistPlaying: nil,
          titlePlaying: nil,
          albumArtworkUrl: nil,
          playolaSpinPlaying: nil,
          currentStation: nil,
          playbackStatus: .error
        )
      }
    case .urlNotSet, .none:
      $nowPlaying.withLock {
        $0 = NowPlaying(
          artistPlaying: nil,
          titlePlaying: nil,
          albumArtworkUrl: nil,
          playolaSpinPlaying: nil,
          currentStation: nil,
          playbackStatus: .stopped
        )
      }
    }
  }

  func setupRemoteControlCenter() {
    UIApplication.shared.beginReceivingRemoteControlEvents()
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.stopCommand.isEnabled = true
    commandCenter.stopCommand.addTarget { _ in
      self.stationPlayer.stop()
      return .success
    }
  }
}
