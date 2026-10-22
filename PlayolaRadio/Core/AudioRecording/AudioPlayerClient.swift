//
//  AudioPlayerClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import AVFoundation
import Dependencies

public struct PlaybackState: Equatable, Sendable {
  public let currentTime: TimeInterval
  public let duration: TimeInterval
  public let isPlaying: Bool
  /// True only on the final state the client emits when a track has played to its end.
  /// Lets a caller detect completion even when `duration` is 0/unknown (progress-based
  /// completion can never fire there).
  public let didFinish: Bool

  public init(
    currentTime: TimeInterval,
    duration: TimeInterval,
    isPlaying: Bool,
    didFinish: Bool = false
  ) {
    self.currentTime = currentTime
    self.duration = duration
    self.isPlaying = isPlaying
    self.didFinish = didFinish
  }

  public var progress: Double {
    guard duration > 0 else { return 0 }
    return currentTime / duration
  }

  /// Playback has reached the end of the track, whether reported explicitly by the
  /// client (`didFinish`) or inferred from near-end progress (the engine often halts a
  /// hair short of the exact duration).
  public var isComplete: Bool {
    didFinish || progress >= 0.97
  }

  public static let idle = PlaybackState(currentTime: 0, duration: 0, isPlaying: false)
}

// MARK: - Playback Math

/// Pure, deterministic playback decisions extracted for unit testing (the live actor wraps
/// AVFoundation, which can't run headlessly).
enum AudioPlaybackMath {
  /// End-of-track is reached only after we've actually observed playback and the engine has
  /// since stopped at (or past) the end. A mid-song buffering stall — and a user-initiated
  /// pause — also report not-playing, so neither is treated as the end (the `!isPlaying` gate
  /// alone can't fire mid-track because it also requires being at/past the duration).
  ///
  /// A zero/unknown duration has no reliable poll-based end signal: not-playing there is
  /// indistinguishable from a pause or a pre-roll buffering gap, so we do NOT infer completion
  /// (returning `true` here made the first pause/stall look like the end). Such a clip simply
  /// never auto-completes via polling — every real caller supplies a positive duration.
  ///
  /// Accepted edge: a stopped sample within the final 0.5s reads as end, so pausing a sub-second
  /// clip in its last half-second would complete it. No real clip (full songs, multi-second
  /// recorded answers) is that short, so this isn't worth a fractional-threshold heuristic.
  static func detectEnd(
    hasPlayed: Bool,
    isPlaying: Bool,
    currentTime: TimeInterval,
    duration: TimeInterval
  ) -> Bool {
    guard hasPlayed, !isPlaying else { return false }
    guard duration > 0 else { return false }
    return currentTime >= duration - 0.5
  }

  /// Clamps a seek target into a valid range. Rejects non-finite targets (an indeterminate
  /// stream can report `+inf`/`NaN`). Clamps to `[0, duration]` when the duration is known,
  /// otherwise just floors at zero so a negative target never seeks before the start.
  static func clampSeekTarget(_ target: TimeInterval, duration: TimeInterval) -> TimeInterval? {
    guard target.isFinite else { return nil }
    guard duration > 0 else { return max(0, target) }
    return min(duration, max(0, target))
  }
}

public struct AudioPlayerClient: Sendable {
  // Low-level methods (existing)
  public var loadFile: @Sendable (URL) async throws -> Void
  public var play: @Sendable () async -> Void
  public var pause: @Sendable () async -> Void
  public var stop: @Sendable () async -> Void
  public var seek: @Sendable (TimeInterval) async -> Void
  public var currentTime: @Sendable () async -> TimeInterval
  public var duration: @Sendable () async -> TimeInterval
  public var isPlaying: @Sendable () async -> Bool

  /// Starts playback with automatic state updates.
  /// The onStateChange callback is called every 100ms while playing.
  /// Returns a PlaybackSession that can be used to control playback.
  public var startPlayback:
    @Sendable (
      _ url: URL,
      _ onStateChange: @escaping @MainActor @Sendable (PlaybackState) -> Void
    ) async throws -> PlaybackSession
}

// MARK: - Playback Session

public final class PlaybackSession: Sendable {
  private let _play: @Sendable () async -> Void
  private let _pause: @Sendable () async -> Void
  private let _stop: @Sendable () async -> Void
  private let _seek: @Sendable (TimeInterval) async -> Void
  private let _cancel: @Sendable () -> Void

  init(
    play: @escaping @Sendable () async -> Void,
    pause: @escaping @Sendable () async -> Void,
    stop: @escaping @Sendable () async -> Void,
    seek: @escaping @Sendable (TimeInterval) async -> Void,
    cancel: @escaping @Sendable () -> Void
  ) {
    self._play = play
    self._pause = pause
    self._stop = stop
    self._seek = seek
    self._cancel = cancel
  }

  // Backstop: if a session is dropped without an explicit stop/cancel, tear down its polling
  // task so an orphaned session can't leave a 100ms poll loop running forever. Callers that stop
  // or cancel explicitly have already torn it down; _cancel is idempotent.
  deinit { _cancel() }

  public func play() async { await _play() }
  public func pause() async { await _pause() }
  public func stop() async { await _stop() }
  public func seek(_ time: TimeInterval) async { await _seek(time) }
  public func cancel() { _cancel() }
}

// MARK: - Live Implementation

extension AudioPlayerClient: DependencyKey {
  public static var liveValue: AudioPlayerClient {
    let player = LiveAudioPlayer()

    return AudioPlayerClient(
      loadFile: { url in try await player.loadFile(url) },
      play: { await player.play() },
      pause: { await player.pause() },
      stop: { await player.stop() },
      seek: { time in await player.seek(to: time) },
      currentTime: { await player.currentTime() },
      duration: { await player.duration() },
      isPlaying: { await player.isPlaying() },
      startPlayback: { url, onStateChange in
        // Each playback session gets its own isolated player. Every caller stops its previous
        // session before starting a new one, so nothing relies on a shared player to auto-stop —
        // and isolation means a stale session's load/play/stop can never hijack a newer song's
        // audio (the reentrancy race that a single shared actor allowed).
        let sessionPlayer = LiveAudioPlayer()
        try await sessionPlayer.loadFile(url)
        let duration = await sessionPlayer.duration()
        await sessionPlayer.play()

        let updateTask = Task {
          // Poll for the session's lifetime. A transient buffering stall OR a user pause both
          // report not-playing, and the loop must survive both so position updates resume when
          // playback continues — so it never gives up on a not-playing sample. It self-terminates
          // only at a real end of track (detectEnd); otherwise it is bounded by session teardown
          // (stop/cancel) and, as a backstop for an orphaned session, PlaybackSession.deinit.
          var hasPlayed = false
          while !Task.isCancelled {
            let playing = await sessionPlayer.isPlaying()
            let currentTime = await sessionPlayer.currentTime()
            if playing { hasPlayed = true }

            await onStateChange(
              PlaybackState(currentTime: currentTime, duration: duration, isPlaying: playing))

            if AudioPlaybackMath.detectEnd(
              hasPlayed: hasPlayed, isPlaying: playing, currentTime: currentTime,
              duration: duration)
            {
              await onStateChange(
                PlaybackState(
                  currentTime: currentTime, duration: duration, isPlaying: false, didFinish: true))
              return
            }
            try? await Task.sleep(for: .milliseconds(100))
          }
        }

        return PlaybackSession(
          play: { await sessionPlayer.play() },
          pause: { await sessionPlayer.pause() },
          stop: {
            await sessionPlayer.stop()
            updateTask.cancel()
          },
          seek: { time in
            guard let clamped = AudioPlaybackMath.clampSeekTarget(time, duration: duration)
            else { return }
            await sessionPlayer.seek(to: clamped)
          },
          cancel: { updateTask.cancel() }
        )
      }
    )
  }
}

// MARK: - Test Implementation

extension AudioPlayerClient: TestDependencyKey {
  public static var testValue: AudioPlayerClient {
    AudioPlayerClient(
      loadFile: { _ in },
      play: {},
      pause: {},
      stop: {},
      seek: { _ in },
      currentTime: { 0 },
      duration: { 0 },
      isPlaying: { false },
      startPlayback: { _, onStateChange in
        await onStateChange(.idle)
        return PlaybackSession(
          play: {},
          pause: {},
          stop: {},
          seek: { _ in },
          cancel: {}
        )
      }
    )
  }
}

// MARK: - Dependency Values

extension DependencyValues {
  public var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClient.self] }
    set { self[AudioPlayerClient.self] = newValue }
  }
}

// MARK: - Live Player

private actor LiveAudioPlayer {
  private var localPlayer: AVAudioPlayer?
  private var remotePlayer: AVPlayer?
  private var isRemote = false
  private var remoteDuration: TimeInterval = 0

  func loadFile(_ url: URL) async throws {
    localPlayer = nil
    remotePlayer = nil

    if url.isFileURL {
      let player = try AVAudioPlayer(contentsOf: url)
      player.prepareToPlay()
      self.localPlayer = player
      self.isRemote = false
    } else {
      let asset = AVURLAsset(url: url)
      let duration = try await asset.load(.duration)
      let playerItem = AVPlayerItem(asset: asset)
      let player = AVPlayer(playerItem: playerItem)
      self.remotePlayer = player
      self.remoteDuration = CMTimeGetSeconds(duration)
      self.isRemote = true
    }
  }

  func play() {
    if isRemote {
      remotePlayer?.play()
    } else {
      localPlayer?.play()
    }
  }

  func pause() {
    if isRemote {
      remotePlayer?.pause()
    } else {
      localPlayer?.pause()
    }
  }

  func stop() async {
    let player = remotePlayer
    let isRemotePlayer = isRemote
    localPlayer?.stop()
    localPlayer?.currentTime = 0

    if isRemotePlayer {
      player?.pause()
      await player?.seek(to: .zero)
    }
  }

  func seek(to time: TimeInterval) async {
    if isRemote {
      await remotePlayer?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    } else {
      localPlayer?.currentTime = time
    }
  }

  func currentTime() -> TimeInterval {
    if isRemote {
      return remotePlayer?.currentTime().seconds ?? 0
    }
    return localPlayer?.currentTime ?? 0
  }

  func duration() -> TimeInterval {
    if isRemote {
      return remoteDuration
    }
    return localPlayer?.duration ?? 0
  }

  func isPlaying() -> Bool {
    if isRemote {
      return remotePlayer?.rate ?? 0 > 0
    }
    return localPlayer?.isPlaying ?? false
  }
}
