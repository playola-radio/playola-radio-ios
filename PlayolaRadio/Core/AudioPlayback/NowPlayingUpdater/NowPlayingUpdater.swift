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

  /// Projects the authoritative `StationPlayer.State` into the app-wide shared
  /// now-playing value. `NowPlaying` is `State` plus `currentStation`, and
  /// `currentStation` is itself a projection of `playbackStatus`, so this is a
  /// total, lossless mapping — `StationPlayer` writes `state` and `nowPlaying`
  /// from the same value, which is what stops them drifting (Phase 3).
  init(from state: StationPlayer.State) {
    self.init(
      artistPlaying: state.artistPlaying,
      titlePlaying: state.titlePlaying,
      albumArtworkUrl: state.albumArtworkUrl,
      playolaSpinPlaying: state.playolaSpinPlaying,
      currentStation: state.playbackStatus.station,
      playbackStatus: state.playbackStatus
    )
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

  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.date.now) var now

  /// Durable snapshot of the last Playola station the user chose to play (written
  /// by `StationPlayer` on accepted play intent). Survives Stop and relaunch, and
  /// is the resume source for the lock-screen / car play command. The in-memory
  /// `lastPlayedStation` below is only an analytics cache for the current session.
  @ObservationIgnored @Shared(.lastPlayedStation) var persistedLastStation: LastPlayedStation?

  private var disposeBag = Set<AnyCancellable>()
  var lastPlayedStation: AnyStation?
  private var currentArtworkURL: String?

  // Local source of truth for the now-playing dictionary. We never read
  // MPNowPlayingInfoCenter.default().nowPlayingInfo: that getter performs a
  // synchronous cross-process wait that can block the main thread for seconds
  // (Sentry APPLE-IOS-1C). We are the only writer, so we keep our own copy and
  // read from it instead.
  private(set) var currentNowPlayingInfo: [String: Any] = [:]

  // Analytics tracking
  private var sessionStartTime: Date?
  private var lastPlaybackStatus: StationPlayer.PlaybackStatus = .stopped
  private func updateNowPlaying(with stationPlayerState: StationPlayer.State) {
    guard let displayStation = stationForDisplay(stationPlayerState) else {
      clearNowPlayingInfo()
      return
    }

    // Only refresh the analytics cache while a station is genuinely current; a
    // stopped-with-snapshot render must not resurrect it as "playing".
    if let currentStation = stationPlayer.currentStation {
      lastPlayedStation = currentStation
    }

    var nowPlayingInfo = buildNowPlayingInfo(
      for: stationPlayerState,
      station: displayStation
    )
    updatePlaybackState(for: stationPlayerState.playbackStatus)
    setPlaybackRate(for: stationPlayerState.playbackStatus, in: &nowPlayingInfo)

    // Handle artwork based on playback status
    switch stationPlayerState.playbackStatus {
    case .loading, .stopped:
      // For loading/stopped states, preserve existing artwork if available, otherwise load new
      if currentNowPlayingInfo[MPMediaItemPropertyArtwork] != nil {
        nowPlayingInfo = preservingExistingArtwork(in: nowPlayingInfo)
      } else if currentArtworkURL != displayStation.imageUrl?.absoluteString {
        // Only load if we don't already have this station's artwork
        loadStationArtwork(from: stationPlayerState, station: displayStation)
      }
    case .playing, .paused:
      // Preserve existing artwork
      nowPlayingInfo = preservingExistingArtwork(in: nowPlayingInfo)
    default:
      break
    }

    setNowPlayingInfo(nowPlayingInfo)
  }

  /// The station whose metadata the lock-screen / Now Playing entry should show.
  /// While a station is current, that station. Once stopped, the durably persisted
  /// last Playola station, so the entry — and its live play command — survive Stop
  /// and a cold-but-alive relaunch, which is what lets the car resume it. Any other
  /// stationless status (e.g. `.error` after a failed cold start) clears the entry.
  private func stationForDisplay(_ state: StationPlayer.State) -> AnyStation? {
    if let currentStation = stationPlayer.currentStation {
      return currentStation
    }
    if case .stopped = state.playbackStatus,
      let snapshotStation = persistedLastStation?.station,
      case .playola = snapshotStation
    {
      // Only ever surface a `.playola` snapshot after Stop. The persisted store is
      // written solely for `.playola` stations today, so this is defense-in-depth
      // (matching the guard in `stationToResume()`): the retired URL backend must
      // never drive a stopped Now Playing entry / live play button.
      return snapshotStation
    }
    return nil
  }

  private func clearNowPlayingInfo() {
    print("🧹 Clearing now playing info")
    MPNowPlayingInfoCenter.default().playbackState = .stopped
    currentNowPlayingInfo = [:]
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    currentArtworkURL = nil
  }

  // internal for testability
  /// Assigns the now-playing dictionary, keeping our local copy in sync with the
  /// system center. This is the only place that writes `nowPlayingInfo`.
  func setNowPlayingInfo(_ info: [String: Any]) {
    currentNowPlayingInfo = info
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  // internal for testability
  /// Carries the artwork from our local copy into `info`, if present. Reads from
  /// `currentNowPlayingInfo`, never from `MPNowPlayingInfoCenter`'s getter.
  func preservingExistingArtwork(in info: [String: Any]) -> [String: Any] {
    guard let existingArtwork = currentNowPlayingInfo[MPMediaItemPropertyArtwork] else {
      return info
    }
    var info = info
    info[MPMediaItemPropertyArtwork] = existingArtwork
    return info
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
    case .playing, .paused:
      populatePlayingInfo(&nowPlayingInfo, state: state, station: station)
    case .loading(_, let progress):
      populateLoadingInfo(&nowPlayingInfo, station: station, progress: progress)
    case .stopped:
      populateStoppedInfo(&nowPlayingInfo, state: state, station: station)
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
      setupRemoteControlCenter()
      MPNowPlayingInfoCenter.default().playbackState = .playing
    case .paused, .stopped:
      // Interruption pause OR a user Stop: keep the Now Playing entry and remote
      // controls alive so the lock-screen / car play button stays live and can
      // resume. Presented as `.paused` (never `.stopped`, which greys the button
      // out). No teardown — the audio session is already released on Stop, and
      // keeping the metadata + command handlers registered costs nothing. The
      // command center is (re)registered so a cold-but-alive launch is resumable.
      setupRemoteControlCenter()
      MPNowPlayingInfoCenter.default().playbackState = .paused
    case .error:
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
    } else if case .url = station {
      // URL stream with no ICY track metadata: fall back to the station's own
      // name/description so the lock screen isn't blank. Mirrors the
      // `UrlStation.trackName ?? name` / `artistName ?? description` fallback
      // URLStreamPlayer wrote directly before Phase 2.
      info[MPMediaItemPropertyTitle] = state.titlePlaying ?? station.name
      info[MPMediaItemPropertyArtist] = state.artistPlaying ?? station.description
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
    state: StationPlayer.State,
    station: AnyStation
  ) {
    // Fall back to the station's own name/curator so a cold-launch stopped entry
    // (persisted snapshot, no in-session track metadata) still shows the station
    // instead of a blank lock-screen control.
    info[MPMediaItemPropertyTitle] = state.titlePlaying ?? station.stationName
    info[MPMediaItemPropertyArtist] = state.artistPlaying ?? station.name
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
    // iOS infers the lock-screen play-vs-pause button from the audio session
    // state + this rate, NOT from `playbackState`. A stopped entry must report
    // rate 0.0 (like paused) or iOS shows a Pause button over stopped audio.
    switch status {
    case .paused, .stopped:
      info[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
    default:
      info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
    }
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
    Task {
      let image = await station.getImage()
      // Artwork loads asynchronously; a fast station switch can resolve a stale
      // image. Only apply it if this station is still the current one.
      guard self.isStillCurrent(station) else { return }
      self.updateNowPlayingImage(image)
      self.currentArtworkURL = station.imageUrl?.absoluteString
    }
  }

  // internal for testability
  /// Whether `station` is still the one being played. Used to drop artwork that
  /// finished loading after a fast station switch superseded the request.
  func isStillCurrent(_ station: AnyStation) -> Bool {
    (stationPlayer.currentStation ?? persistedLastStation?.station)?.id == station.id
  }

  private func updateNowPlayingImage(_ image: UIImage) {
    var nowPlayingInfo = currentNowPlayingInfo
    nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
      boundsSize: image.size,
      requestHandler: { _ in
        return image
      }
    )
    setNowPlayingInfo(nowPlayingInfo)
  }

  // The Combine subscriptions below capture `self` weakly so the cancellable
  // owned by this updater is the only thing keeping each subscription alive.
  // When the updater is deallocated, `disposeBag` releases the cancellables
  // and the subscriptions are torn down — without `[weak self]` the strong
  // self/closure/disposeBag cycle would keep replaced updaters alive forever.
  init(stationPlayer: StationPlayer? = nil) {
    @Dependency(\.stationPlayer) var injectedStationPlayer
    self.stationPlayer = stationPlayer ?? injectedStationPlayer
    self.stationPlayer.$state
      .sink { [weak self] state in
        self?.updateNowPlaying(with: state)
      }
      .store(in: &disposeBag)
    setupRemoteControlCenter()
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
        await self?.stationPlayer.seekNext()
      }
      return .success
    }

    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      Task { @MainActor in
        await self?.stationPlayer.seekPrevious()
      }
      return .success
    }

    // Stop command
    commandCenter.stopCommand.isEnabled = true
    commandCenter.stopCommand.addTarget { _ in
      self.stationPlayer.stop()
      return .success
    }

    // Play command - resume a station paused by an interruption, or restart the
    // durably persisted last station when stopped.
    commandCenter.playCommand.isEnabled = true
    commandCenter.playCommand.addTarget { [weak self] _ in
      self?.handlePlayCommand() ?? .commandFailed
    }
  }

  // internal for testability
  /// The single resume path for the lock-screen / car play command. Paused (by an
  /// interruption/route loss) → resume the live backend; this is the recovery path
  /// for an interruption that ended without `.shouldResume` (e.g. the user started
  /// another audio app). Stopped → restart the durably persisted last Playola
  /// station, which survives relaunch so the car's play command can resume it even
  /// after a cold-but-alive launch. `.commandFailed` only when there is genuinely
  /// nothing to resume.
  func handlePlayCommand() -> MPRemoteCommandHandlerStatus {
    if case .paused = stationPlayer.state.playbackStatus {
      Task { @MainActor in await stationPlayer.resume() }
      return .success
    }
    guard stationPlayer.currentStation == nil,
      let resumeStation = stationToResume()
    else { return .commandFailed }
    Task { @MainActor in
      await stationPlayer.play(station: resumeStation)
    }
    return .success
  }

  /// The station a stopped play command should resume: the durably persisted last
  /// Playola station, re-resolved against the loaded station lists for fresher
  /// metadata / an active check when it appears there, and otherwise the raw
  /// snapshot so a cold launch with no lists still resumes with zero network.
  /// Refuses (nil) only when the station IS present in the lists and provably
  /// inactive — never merely because lists haven't loaded.
  private func stationToResume() -> AnyStation? {
    guard let snapshotStation = persistedLastStation?.station,
      case .playola = snapshotStation
    else { return nil }
    if let resolved = stationPlayer.stationLists
      .flatMap({ $0.stations })
      .first(where: { $0.id == snapshotStation.id })
    {
      return resolved.active ? resolved : nil
    }
    return snapshotStation
  }

  func releaseRemoteControlCenter() {
    let commandCenter = MPRemoteCommandCenter.shared()

    // Remove all targets from commands
    commandCenter.playCommand.removeTarget(nil)
    commandCenter.stopCommand.removeTarget(nil)
    commandCenter.nextTrackCommand.removeTarget(nil)
    commandCenter.previousTrackCommand.removeTarget(nil)

    // Clear now playing info
    currentNowPlayingInfo = [:]
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    MPNowPlayingInfoCenter.default().playbackState = .stopped

    // Stop receiving remote control events
    UIApplication.shared.endReceivingRemoteControlEvents()
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
        sessionStartTime = now
        await analytics.track(
          .listeningSessionStarted(
            station: StationInfo(from: station),
            renderBackend: renderBackend(for: station)
          )
        )
      }

    // End session when stopping from playing or paused state. A `.paused`
    // interruption keeps the session open (resume continues it), so the session
    // must also be closed when a paused station is then stopped/errored —
    // otherwise sessionStartTime leaks and the next session length is wrong.
    // Also end it when the user starts a new station directly from paused (e.g.
    // CarPlay station selection, which can go .paused(A) → .startingNewStation(B)
    // without an intervening .stopped); otherwise A's session never ends and the
    // lingering sessionStartTime blocks B's session from starting.
    case (.playing(let station), .stopped),
      (.playing(let station), .error),
      (.paused(let station), .stopped),
      (.paused(let station), .error),
      (.paused(let station), .startingNewStation):
      if let startTime = sessionStartTime {
        let duration = now.timeIntervalSince(startTime)
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
            error: "Playback error occurred",
            renderBackend: renderBackend(for: lastStation)
          )
        )
      }

    default:
      break
    }
  }

  private func trackStationSwitch(from fromStation: AnyStation, to toStation: AnyStation) async {
    guard let startTime = sessionStartTime else { return }
    let duration = now.timeIntervalSince(startTime)

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
        station: StationInfo(from: toStation),
        renderBackend: renderBackend(for: toStation)
      )
    )

    sessionStartTime = now
  }

  /// The SDK renderer this process locked at its first Playola play — only
  /// meaningful for Playola stations; URL streams bypass the SDK entirely.
  private func renderBackend(for station: AnyStation) -> String? {
    guard case .playola = station else { return nil }
    return stationPlayer.lockedRenderBackend?.analyticsValue
  }
}

// MARK: - Dependency

extension NowPlayingUpdater: @preconcurrency DependencyKey {
  static let liveValue = NowPlayingUpdater()
  static var testValue: NowPlayingUpdater { NowPlayingUpdater() }
}

extension DependencyValues {
  var nowPlayingUpdater: NowPlayingUpdater {
    get { self[NowPlayingUpdater.self] }
    set { self[NowPlayingUpdater.self] = newValue }
  }
}
