//
//  SongPreviewPlayer.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import PlayolaPlayer
import SwiftUI

// Reusable single-song preview engine. Owns one audio session at a time and a monotonically
// increasing generation token so a stale async callback (from a session that has since been torn
// down) can never mutate state for the current song. Callers compose one instance and forward the
// per-block queries their rows need; consumer-specific styling (colors, layout, accessibility copy)
// stays in the owning page model.
@MainActor
@Observable
final class SongPreviewPlayer {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer

  // MARK: - Configuration

  var onPlaybackError: (@MainActor @Sendable (String) -> Void)?

  // MARK: - Initialization

  init() {}

  // MARK: - Properties

  private var playingBlockId: String?
  private var playbackState: PlaybackState = .idle
  private var playbackSession: PlaybackSession?
  private var playbackGeneration = 0
  private let scrubberStep: TimeInterval = 5

  // MARK: - Queries

  func isActive(_ block: AudioBlock) -> Bool {
    playingBlockId == block.id
  }

  func isPlaying(_ block: AudioBlock) -> Bool {
    isActive(block) && playbackState.isPlaying
  }

  // The active song is "buffering" from the tap until the first playing state arrives (and again
  // if playback stalls mid-song): it's the current song but not yet producing audio.
  func isBuffering(_ block: AudioBlock) -> Bool {
    isActive(block) && !playbackState.isPlaying
  }

  func isPlayButtonEnabled(for block: AudioBlock) -> Bool {
    block.downloadUrl != nil
  }

  // MARK: - Display

  // Mirror the tap toggle, which stops any active song (including during startup/buffering, when
  // isActive is true but isPlaying is briefly false). Deriving from isActive keeps the icon and the
  // button's behavior consistent.
  func playButtonIcon(for block: AudioBlock) -> String {
    isActive(block) ? "pause.fill" : "play.fill"
  }

  func bufferingSpinnerOpacity(for block: AudioBlock) -> Double {
    isBuffering(block) ? 1 : 0
  }

  func playIconOpacity(for block: AudioBlock) -> Double {
    isBuffering(block) ? 0 : 1
  }

  func elapsedText(for block: AudioBlock) -> String {
    guard isActive(block) else { return formatTime(0) }
    return formatTime(playbackState.currentTime)
  }

  func durationText(for block: AudioBlock) -> String {
    formatTime(duration(for: block))
  }

  func progress(for block: AudioBlock) -> Double {
    guard isActive(block) else { return 0 }
    let total = duration(for: block)
    guard total > 0 else { return 0 }
    return min(1, max(0, playbackState.currentTime / total))
  }

  // MARK: - Actions

  func toggle(_ block: AudioBlock) async {
    guard let downloadUrl = block.downloadUrl else { return }

    let wasActive = isActive(block)

    playbackGeneration &+= 1
    let generation = playbackGeneration

    await teardownCurrentSession()
    guard playbackGeneration == generation else { return }
    if wasActive { return }

    playingBlockId = block.id

    do {
      let session = try await audioPlayer.startPlayback(downloadUrl) { [weak self] state in
        guard let self, self.playbackGeneration == generation else { return }
        self.playbackState = state
        // The client emits didFinish only on the final state after a track has played to its end,
        // so it is the sole completion signal. A mid-song buffering stall (even in the last few
        // percent) reports not-playing without didFinish and must NOT be treated as the end.
        guard state.didFinish else { return }
        self.handlePlaybackCompletion()
      }
      guard playbackGeneration == generation, playingBlockId == block.id else {
        await session.stop()
        return
      }
      playbackSession = session
    } catch {
      guard playbackGeneration == generation else { return }
      playingBlockId = nil
      onPlaybackError?(error.localizedDescription)
    }
  }

  func scrubberDragged(_ block: AudioBlock, locationX: CGFloat, trackWidth: CGFloat) async {
    guard isActive(block), trackWidth > 0 else { return }
    let percent = min(1, max(0, locationX / trackWidth))
    let target = TimeInterval(percent) * duration(for: block)
    guard target.isFinite else { return }
    await playbackSession?.seek(target)
  }

  func scrubberAdjusted(_ block: AudioBlock, increment: Bool) async {
    guard isActive(block) else { return }
    let total = duration(for: block)
    let current = playbackState.currentTime
    let target = min(total, max(0, current + (increment ? scrubberStep : -scrubberStep)))
    guard target.isFinite else { return }
    await playbackSession?.seek(target)
  }

  func stop() async {
    playbackGeneration &+= 1
    await teardownCurrentSession()
  }

  // MARK: - Private Helpers

  private func duration(for block: AudioBlock) -> TimeInterval {
    if isActive(block), playbackState.duration > 0 {
      return playbackState.duration
    }
    return max(0, TimeInterval(block.durationMS) / 1000)
  }

  private func teardownCurrentSession() async {
    let session = playbackSession
    playbackSession = nil
    playbackState = .idle
    playingBlockId = nil
    await session?.stop()
  }

  // Called only for a stopped, ended state, so the client's per-session player has already halted
  // and its polling loop has self-completed. Dropping the session reference is enough; no explicit
  // async stop is needed.
  private func handlePlaybackCompletion() {
    playbackSession = nil
    playbackState = .idle
    playingBlockId = nil
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite else { return "0:00" }
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
  }
}
