//
//  AudioPlayerClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import AVFoundation
import Dependencies

public struct AudioPlayerClient: Sendable {
  public var loadFile: @Sendable (URL) async throws -> Void
  public var play: @Sendable () async -> Void
  public var pause: @Sendable () async -> Void
  public var stop: @Sendable () async -> Void
  public var seek: @Sendable (TimeInterval) async -> Void
  public var currentTime: @Sendable () async -> TimeInterval
  public var duration: @Sendable () async -> TimeInterval
  public var isPlaying: @Sendable () async -> Bool
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
      isPlaying: { await player.isPlaying() }
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
      isPlaying: { false }
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
