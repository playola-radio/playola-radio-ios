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
  let currentStation: AnyStation?
  let playbackStatus: StationPlayer.PlaybackStatus

  init(
    artistPlaying: String? = nil,
    titlePlaying: String? = nil,
    albumArtworkUrl: URL? = nil,
    playolaSpinPlaying: Spin? = nil,
    currentStation: AnyStation? = nil,
    playbackStatus: StationPlayer.PlaybackStatus = .stopped
  ) {
    self.artistPlaying = artistPlaying
    self.titlePlaying = titlePlaying
    self.albumArtworkUrl = albumArtworkUrl
    self.playolaSpinPlaying = playolaSpinPlaying
    self.currentStation = currentStation
    self.playbackStatus = playbackStatus
  }

  static func mockWith(
    artistPlaying: String? = nil,
    titlePlaying: String? = nil,
    spin: Spin? = nil,
    station: AnyStation? = .mock,
    status: StationPlayer.PlaybackStatus? = nil
  ) -> NowPlaying {
    let resolvedStatus = status ?? (station.map { .playing($0) } ?? .stopped)
    return NowPlaying(
      artistPlaying: artistPlaying ?? "Rachel Loy",
      titlePlaying: titlePlaying ?? "Selfie",
      playolaSpinPlaying: spin,
      currentStation: station,
      playbackStatus: resolvedStatus
    )
  }
}

// MARK: - Shared Storage Extension

@MainActor
class NowPlayingUpdater {
  var stationPlayer: StationPlayer

  static var shared = NowPlayingUpdater()

  @ObservationIgnored @Shared(.nowPlaying) var nowPlaying
  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Dependency(\.analytics) var analytics

  private var disposeBag = Set<AnyCancellable>()
  private var inactivityTask: Task<Void, Never>?
  private let inactivityTimeout: Duration = .seconds(15 * 60)  // 15 minutes
  var lastPlayedStation: AnyStation?
  private var currentArtworkURL: String?

  // Analytics tracking
  private var sessionStartTime: Date?
  private var lastPlaybackStatus: StationPlayer.PlaybackStatus = .stopped
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
    var nowPlayingInfo = buildNowPlayingInfo(
      for: stationPlayerState,
      station: currentStation
    )
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
        if currentArtworkURL != currentStation.imageUrl?.absoluteString {
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

  private func buildNowPlayingInfo(
    for state: StationPlayer.State,
    station: AnyStation
  )
    -> [String: Any]
  {
    var nowPlayingInfo = [String: Any]()
    nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true

    switch state.playbackStatus {
    case .playing:
      populatePlayingInfo(&nowPlayingInfo, state: state, station: station)
    case .loading(_, let progress):
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
    // Track listening sessions based on state transitions
    Task {
      await trackListeningSession(
        currentStatus: status,
        previousStatus: lastPlaybackStatus
      )
    }
    lastPlaybackStatus = status

    switch status {
    case .playing, .loading, .startingNewStation:
      cancelInactivityTimer()
      setupRemoteControlCenter()
      MPNowPlayingInfoCenter.default().playbackState = .playing
    case .stopped, .error:
      if case .stopped = status { startInactivityTimer() }
      MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
  }

  private func populatePlayingInfo(
    _ info: inout [String: Any],
    state: StationPlayer.State,
    station: AnyStation
  ) {
    if let spin = state.playolaSpinPlaying {
      let (title, artist) = nowPlayingTitleAndArtist(spin: spin, station: station)
      info[MPMediaItemPropertyTitle] = title
      if !artist.isEmpty {
        info[MPMediaItemPropertyArtist] = artist
      }
    } else {
      if let artistPlaying = state.artistPlaying {
        info[MPMediaItemPropertyArtist] = artistPlaying
      }
      if let titlePlaying = state.titlePlaying {
        info[MPMediaItemPropertyTitle] = titlePlaying
      }
    }
  }

  func nowPlayingTitleAndArtist(spin: Spin, station: AnyStation) -> (title: String, artist: String)
  {
    let audioBlock = spin.audioBlock

    // Commercial → "Playola Pays" / Station name
    if audioBlock.type == "commercial" {
      return ("Playola Pays", station.stationName)
    }

    // Song → title / artist (even if part of an Airing)
    if audioBlock.type == "song" {
      return (audioBlock.title, audioBlock.artist)
    }

    // Non-song with Airing → Episode title / Station name
    if let episodeTitle = spin.airing?.episode?.title {
      return (episodeTitle, station.stationName)
    }

    // Non-song without Airing → Station name / empty
    return (station.stationName, "")
  }

  private func populateLoadingInfo(
    _ info: inout [String: Any],
    station: AnyStation,
    progress: Float?
  ) {
    info[MPMediaItemPropertyTitle] = "Loading \(station.name)..."
    info[MPMediaItemPropertyArtist] = station.name

    if let progress = progress {
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(progress * 100)
      info[MPMediaItemPropertyPlaybackDuration] = 100.0
    }
  }

  private func populateStoppedInfo(
    _ info: inout [String: Any],
    state: StationPlayer.State
  ) {
    if let artistPlaying = state.artistPlaying {
      info[MPMediaItemPropertyArtist] = artistPlaying
    }
    if let titlePlaying = state.titlePlaying {
      info[MPMediaItemPropertyTitle] = titlePlaying
    }
  }

  private func populateConnectingInfo(
    _ info: inout [String: Any],
    station: AnyStation
  ) {
    info[MPMediaItemPropertyTitle] = "Connecting to \(station.name)..."
    info[MPMediaItemPropertyArtist] = station.name
  }

  private func populateErrorInfo(
    _ info: inout [String: Any],
    station: AnyStation
  ) {
    info[MPMediaItemPropertyTitle] = "Connection Error"
    info[MPMediaItemPropertyArtist] = station.name
  }

  private func setPlaybackRate(
    for status: StationPlayer.PlaybackStatus,
    in info: inout [String: Any]
  ) {
    guard !status.isLoading else { return }
    info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
  }

  private func loadStationArtwork(
    from state: StationPlayer.State,
    station: AnyStation
  ) {
    // Skip if we're already displaying this station's artwork
    if currentArtworkURL == station.imageUrl?.absoluteString {
      return
    }

    // For CarPlay/Lock Screen: always use station image, ignore album artwork
    station.getImage { image in
      Task {
        self.updateNowPlayingImage(image)
        await MainActor.run {
          self.currentArtworkURL = station.imageUrl?.absoluteString
        }
      }
    }
  }

  private func updateNowPlayingImage(_ image: UIImage) {
    var nowPlayingInfo: [String: Any] =
      MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
    nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
      boundsSize: image.size,
      requestHandler: { _ in
        return image
      }
    )
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
    // Observe StreamingStationPlayer state changes
    stationPlayer.playolaStationPlayer.$state
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

  func processPlayolaStationPlayerState(
    _ playolaState: StreamingStationPlayer.State?
  ) {
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
    case .playing(let nowPlayingData):
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

  private func processUrlStreamStateChanged(
    _ urlStreamPlayerState: URLStreamPlayer.State
  ) {
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
    commandCenter.changePlaybackRateCommand.isEnabled = false
    commandCenter.seekForwardCommand.isEnabled = false
    commandCenter.seekBackwardCommand.isEnabled = false
    commandCenter.changePlaybackPositionCommand.isEnabled = false

    commandCenter.stopCommand.removeTarget(nil)
    commandCenter.playCommand.removeTarget(nil)
    commandCenter.nextTrackCommand.removeTarget(nil)
    commandCenter.previousTrackCommand.removeTarget(nil)

    // Next/previous track commands for station seeking
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      Task { @MainActor in
        self?.stationPlayer.seekNext()
      }
      return .success
    }

    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      Task { @MainActor in
        self?.stationPlayer.seekPrevious()
      }
      return .success
    }

    // Stop command
    commandCenter.stopCommand.isEnabled = true
    commandCenter.stopCommand.addTarget { _ in
      self.stationPlayer.stop()
      return .success
    }

    // Play command - restart last played station when stopped
    commandCenter.playCommand.isEnabled = true
    commandCenter.playCommand.addTarget { _ in
      if let lastStation = self.lastPlayedStation,
        self.stationPlayer.currentStation == nil
      {
        self.stationPlayer.play(station: lastStation)
        return .success
      }
      return .commandFailed
    }
  }

  func releaseRemoteControlCenter() {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Remove all targets from commands
    commandCenter.playCommand.removeTarget(nil)
    commandCenter.stopCommand.removeTarget(nil)
    commandCenter.nextTrackCommand.removeTarget(nil)
    commandCenter.previousTrackCommand.removeTarget(nil)

    // Clear now playing info
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    MPNowPlayingInfoCenter.default().playbackState = .stopped

    // Stop receiving remote control events
    UIApplication.shared.endReceivingRemoteControlEvents()
  }

  // MARK: - Inactivity Timer

  func startInactivityTimer() {
    cancelInactivityTimer()

    inactivityTask = Task { [weak self] in
      guard let self else { return }

      do {
        try await self.clock.sleep(for: self.inactivityTimeout)

        // Clear Now Playing info after inactivity timeout
        await MainActor.run {
          self.releaseRemoteControlCenter()
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

// MARK: - Analytics Tracking

extension NowPlayingUpdater {
  func trackListeningSession(
    currentStatus: StationPlayer.PlaybackStatus,
    previousStatus: StationPlayer.PlaybackStatus
  ) async {
    switch (previousStatus, currentStatus) {
    // Track station switches (must come before generic playing case)
    case (.playing(let fromStation), .playing(let toStation))
    where fromStation.id != toStation.id:
      await trackStationSwitch(from: fromStation, to: toStation)

    // Start session when transitioning to playing
    case (_, .playing(let station)):
      if sessionStartTime == nil {
        sessionStartTime = Date()
        await analytics.track(
          .listeningSessionStarted(
            station: StationInfo(from: station)
          )
        )
      }

    // End session when stopping from playing state
    case (.playing(let station), .stopped),
      (.playing(let station), .error):
      if let startTime = sessionStartTime {
        let duration = Date().timeIntervalSince(startTime)
        await analytics.track(
          .listeningSessionEnded(
            station: StationInfo(from: station),
            sessionLengthSec: Int(duration)
          )
        )
        sessionStartTime = nil
      }

    // Track errors
    case (_, .error):
      if let lastStation = lastPlayedStation {
        await analytics.track(
          .playbackError(
            station: StationInfo(from: lastStation),
            error: "Playback error occurred"
          )
        )
      }

    default:
      break
    }
  }

  private func trackStationSwitch(from fromStation: AnyStation, to toStation: AnyStation) async {
    guard let startTime = sessionStartTime else { return }
    let duration = Date().timeIntervalSince(startTime)

    // End current session
    await analytics.track(
      .listeningSessionEnded(
        station: StationInfo(from: fromStation),
        sessionLengthSec: Int(duration)
      )
    )

    // Track the switch
    await analytics.track(
      .switchedStation(
        from: StationInfo(from: fromStation),
        to: StationInfo(from: toStation),
        timeBeforeSwitchSec: Int(duration),
        reason: .userInitiated
      )
    )

    // Start new session
    await analytics.track(
      .listeningSessionStarted(
        station: StationInfo(from: toStation)
      )
    )

    sessionStartTime = Date()
  }
}
