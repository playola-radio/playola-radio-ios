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
  private var currentArtworkURL: String?
  private func updateNowPlaying(with stationPlayerState: StationPlayer.State) {
    print(
      "🎵 NowPlayingUpdater: updateNowPlaying called with status: \(stationPlayerState.playbackStatus)"
    )
    print("🎵 Current station: \(stationPlayer.currentStation?.name ?? "nil")")

    guard let currentStation = stationPlayer.currentStation else {
      print("🎵 No current station - clearing now playing info")
      clearNowPlayingInfo()
      return
    }

    lastPlayedStation = currentStation
    var nowPlayingInfo = buildNowPlayingInfo(for: stationPlayerState, station: currentStation)
    updatePlaybackState(for: stationPlayerState.playbackStatus)
    setPlaybackRate(for: stationPlayerState.playbackStatus, in: &nowPlayingInfo)

    // Handle artwork based on playback status
    switch stationPlayerState.playbackStatus {
    case .loading, .stopped:
      // For loading/stopped states, preserve existing artwork if available, otherwise load new
      if let existingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo,
        let existingArtwork = existingInfo[MPMediaItemPropertyArtwork]
      {
        nowPlayingInfo[MPMediaItemPropertyArtwork] = existingArtwork
      } else {
        // Only load if we don't already have this station's artwork
        if currentArtworkURL != currentStation.imageURL {
          loadStationArtwork(from: stationPlayerState, station: currentStation)
        }
      }
    case .playing:
      // Preserve existing artwork
      if let existingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo,
        let existingArtwork = existingInfo[MPMediaItemPropertyArtwork]
      {
        nowPlayingInfo[MPMediaItemPropertyArtwork] = existingArtwork
      }
    default:
      break
    }

    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
  }

  private func clearNowPlayingInfo() {
    print("🧹 Clearing now playing info")
    MPNowPlayingInfoCenter.default().playbackState = .stopped
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    currentArtworkURL = nil
  }

  private func buildNowPlayingInfo(for state: StationPlayer.State, station: RadioStation)
    -> [String: Any]
  {
    var nowPlayingInfo = [String: Any]()

    switch state.playbackStatus {
    case .playing:
      populatePlayingInfo(&nowPlayingInfo, state: state)
    case let .loading(_, progress):
      populateLoadingInfo(&nowPlayingInfo, station: station, progress: progress)
    case .stopped:
      populateStoppedInfo(&nowPlayingInfo, state: state)
    case .startingNewStation:
      populateConnectingInfo(&nowPlayingInfo, station: station)
    case .error:
      populateErrorInfo(&nowPlayingInfo, station: station)
    }

    return nowPlayingInfo
  }

  private func updatePlaybackState(for status: StationPlayer.PlaybackStatus) {
    switch status {
    case .playing, .loading, .startingNewStation:
      cancelInactivityTimer()
      MPNowPlayingInfoCenter.default().playbackState = .playing
    case .stopped, .error:
      if case .stopped = status { startInactivityTimer() }
      MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
  }

  private func populatePlayingInfo(_ info: inout [String: Any], state: StationPlayer.State) {
    if let artistPlaying = state.artistPlaying {
      info[MPMediaItemPropertyArtist] = artistPlaying
    }
    if let titlePlaying = state.titlePlaying {
      info[MPMediaItemPropertyTitle] = titlePlaying
    }
  }

  private func populateLoadingInfo(
    _ info: inout [String: Any], station: RadioStation, progress: Float?
  ) {
    info[MPMediaItemPropertyTitle] = "Loading \(station.name)..."
    info[MPMediaItemPropertyArtist] = station.desc

    if let progress = progress {
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(progress * 100)
      info[MPMediaItemPropertyPlaybackDuration] = 100.0
    }
  }

  private func populateStoppedInfo(_ info: inout [String: Any], state: StationPlayer.State) {
    if let artistPlaying = state.artistPlaying {
      info[MPMediaItemPropertyArtist] = artistPlaying
    }
    if let titlePlaying = state.titlePlaying {
      info[MPMediaItemPropertyTitle] = titlePlaying
    }
  }

  private func populateConnectingInfo(_ info: inout [String: Any], station: RadioStation) {
    info[MPMediaItemPropertyTitle] = "Connecting to \(station.name)..."
    info[MPMediaItemPropertyArtist] = station.desc
  }

  private func populateErrorInfo(_ info: inout [String: Any], station: RadioStation) {
    info[MPMediaItemPropertyTitle] = "Connection Error"
    info[MPMediaItemPropertyArtist] = station.name
  }

  private func setPlaybackRate(
    for status: StationPlayer.PlaybackStatus, in info: inout [String: Any]
  ) {
    guard !status.isLoading else { return }
    info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
  }

  private func loadStationArtwork(from state: StationPlayer.State, station: RadioStation) {
    // Skip if we're already displaying this station's artwork
    if currentArtworkURL == station.imageURL {
      return
    }

    // For CarPlay/Lock Screen: always use station image, ignore album artwork
    station.getImage { image in
      Task {
        self.updateNowPlayingImage(image)
        await MainActor.run {
          self.currentArtworkURL = station.imageURL
        }
      }
    }
  }

  private func updateNowPlayingImage(_ image: UIImage) {
    var nowPlayingInfo: [String: Any] =
      MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
    nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
      boundsSize: image.size,
      requestHandler: { size in
        return image
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

// MARK: - Extensions

extension StationPlayer.PlaybackStatus {
  var isLoading: Bool {
    if case .loading = self { return true }
    return false
  }
}
