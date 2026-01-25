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

  public var progress: Double {
    guard duration > 0 else { return 0 }
    return currentTime / duration
  }

  public static let idle = PlaybackState(currentTime: 0, duration: 0, isPlaying: false)
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
        try await player.loadFile(url)
        let duration = player.duration()
        await player.play()

        let updateTask = Task {
          while !Task.isCancelled {
            let state = PlaybackState(
              currentTime: player.currentTime(),
              duration: duration,
              isPlaying: player.isPlaying()
            )
            await onStateChange(state)

            if !player.isPlaying() {
              break
            }
            try? await Task.sleep(for: .milliseconds(100))
          }
          // Send final state
          await onStateChange(
            PlaybackState(
              currentTime: player.currentTime(),
              duration: duration,
              isPlaying: false
            ))
        }

        return PlaybackSession(
          play: { await player.play() },
          pause: { await player.pause() },
          stop: {
            await player.stop()
            updateTask.cancel()
          },
          seek: { time in await player.seek(to: time) },
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

private final class LiveAudioPlayer: @unchecked Sendable {
  private var audioPlayer: AVAudioPlayer?
  private let lock = NSLock()

  func loadFile(_ url: URL) async throws {
    let player = try AVAudioPlayer(contentsOf: url)
    player.prepareToPlay()

    lock.lock()
    self.audioPlayer = player
    lock.unlock()
  }

  func play() async {
    lock.lock()
    audioPlayer?.play()
    lock.unlock()
  }

  func pause() async {
    lock.lock()
    audioPlayer?.pause()
    lock.unlock()
  }

  func stop() async {
    lock.lock()
    audioPlayer?.stop()
    audioPlayer?.currentTime = 0
    lock.unlock()
  }

  func seek(to time: TimeInterval) async {
    lock.lock()
    audioPlayer?.currentTime = time
    lock.unlock()
  }

  func currentTime() -> TimeInterval {
    lock.lock()
    defer { lock.unlock() }
    return audioPlayer?.currentTime ?? 0
  }

  func duration() -> TimeInterval {
    lock.lock()
    defer { lock.unlock() }
    return audioPlayer?.duration ?? 0
  }

  func isPlaying() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return audioPlayer?.isPlaying ?? false
  }
}
