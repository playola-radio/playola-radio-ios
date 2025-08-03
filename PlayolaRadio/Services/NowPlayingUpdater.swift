//
//  NowPlayingUpdater.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/20/25.
//
import Combine
import Dependencies
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
  @ObservationIgnored @Dependency(\.continuousClock) var clock

  private var disposeBag = Set<AnyCancellable>()
  private var inactivityTask: Task<Void, Never>?
  private let inactivityTimeout: Duration = .seconds(15 * 60)  // 15 minutes
  private var lastPlayedStation: RadioStation?
  private func updateNowPlaying(with stationPlayerState: StationPlayer.State) {
    var nowPlayingInfo = [String: Any]()

    guard let currentStation = stationPlayer.currentStation else {
      MPNowPlayingInfoCenter.default().playbackState = .stopped
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      return
    }

    // Save the station for resume functionality
    lastPlayedStation = currentStation

    // Handle different playback states
    switch stationPlayerState.playbackStatus {
    case .playing:
      cancelInactivityTimer()
      MPNowPlayingInfoCenter.default().playbackState = .playing

      if let artistPlaying = stationPlayerState.artistPlaying {
        nowPlayingInfo[MPMediaItemPropertyArtist] = artistPlaying
      }

      if let titlePlaying = stationPlayerState.titlePlaying {
        nowPlayingInfo[MPMediaItemPropertyTitle] = titlePlaying
      }

    case let .loading(_, progress):
      MPNowPlayingInfoCenter.default().playbackState = .playing

      // Show loading status
      nowPlayingInfo[MPMediaItemPropertyTitle] = "Loading \(currentStation.name)..."
      nowPlayingInfo[MPMediaItemPropertyArtist] = currentStation.desc

      // Use progress bar to show loading progress
      if let progress = progress {
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(progress * 100)
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 100.0
      }

    case .stopped:
      startInactivityTimer()
      MPNowPlayingInfoCenter.default().playbackState = .stopped

      // Keep last playing info when stopped
      if let artistPlaying = stationPlayerState.artistPlaying {
        nowPlayingInfo[MPMediaItemPropertyArtist] = artistPlaying
      }

      if let titlePlaying = stationPlayerState.titlePlaying {
        nowPlayingInfo[MPMediaItemPropertyTitle] = titlePlaying
      }

    case .startingNewStation:
      MPNowPlayingInfoCenter.default().playbackState = .playing
      nowPlayingInfo[MPMediaItemPropertyTitle] = "Connecting to \(currentStation.name)..."
      nowPlayingInfo[MPMediaItemPropertyArtist] = currentStation.desc

    case .error:
      MPNowPlayingInfoCenter.default().playbackState = .stopped
      nowPlayingInfo[MPMediaItemPropertyTitle] = "Connection Error"
      nowPlayingInfo[MPMediaItemPropertyArtist] = currentStation.name
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

    // Set playback rate for all states except loading (where we use progress)
    if case .loading = stationPlayerState.playbackStatus {
      // Don't set playback rate during loading to show progress
    } else {
      // For live streams, set playback rate to indicate it's playing but no duration
      nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
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

    // Disable commands that don't make sense for live radio
    commandCenter.skipForwardCommand.isEnabled = false
    commandCenter.skipBackwardCommand.isEnabled = false
    commandCenter.nextTrackCommand.isEnabled = false
    commandCenter.previousTrackCommand.isEnabled = false
    commandCenter.changePlaybackRateCommand.isEnabled = false
    commandCenter.seekForwardCommand.isEnabled = false
    commandCenter.seekBackwardCommand.isEnabled = false
    commandCenter.changePlaybackPositionCommand.isEnabled = false

    // Enable play/pause toggle
    commandCenter.playCommand.isEnabled = true
    commandCenter.playCommand.addTarget { _ in
      // Try current station first, fall back to last played station
      if let currentStation = self.stationPlayer.currentStation {
        self.stationPlayer.play(station: currentStation)
      } else if let lastStation = self.lastPlayedStation {
        self.stationPlayer.play(station: lastStation)
      }
      return .success
    }

    commandCenter.pauseCommand.isEnabled = true
    commandCenter.pauseCommand.addTarget { _ in
      self.stationPlayer.stop()
      return .success
    }

    // Stop command
    commandCenter.stopCommand.isEnabled = true
    commandCenter.stopCommand.addTarget { _ in
      self.stationPlayer.stop()
      return .success
    }
  }

  // MARK: - Inactivity Timer

  private func startInactivityTimer() {
    cancelInactivityTimer()

    inactivityTask = Task { [weak self] in
      guard let self else { return }

      do {
        try await self.clock.sleep(for: self.inactivityTimeout)

        // Clear Now Playing info after inactivity timeout
        await MainActor.run {
          MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
          MPNowPlayingInfoCenter.default().playbackState = .stopped
          self.lastPlayedStation = nil  // Clear the last played station too
        }
      } catch {
        // Task was cancelled
      }
    }
  }

  private func cancelInactivityTimer() {
    inactivityTask?.cancel()
    inactivityTask = nil
  }
}
