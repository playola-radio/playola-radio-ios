//
//  BreakerCategoryDetailPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import PlayolaPlayer
import SwiftUI

@MainActor
@Observable
class BreakerCategoryDetailPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer

  // MARK: - Initialization

  init(category: StationCategory) {
    self.category = category
    super.init()
  }

  // MARK: - Properties

  let category: StationCategory
  var presentedAlert: PlayolaAlert?

  private var playingBlockId: String?
  private var playbackState: PlaybackState = .idle
  private var playbackSession: PlaybackSession?
  private var playbackGeneration = 0
  private let scrubberStep: TimeInterval = 5

  var navigationTitle: String { category.name }
  var clips: [AudioBlock] { category.audioBlocks }

  var emptyStateMessage: String { "No clips in this category yet." }
  var showsEmptyState: Bool { clips.isEmpty }
  var emptyStateOpacity: Double { showsEmptyState ? 1 : 0 }

  // MARK: - View Helpers

  func clipTitle(for block: AudioBlock) -> String {
    block.title
  }

  func clipSubtitle(for block: AudioBlock) -> String {
    block.artist
  }

  func isActive(_ block: AudioBlock) -> Bool {
    playingBlockId == block.id
  }

  func isPlaying(_ block: AudioBlock) -> Bool {
    isActive(block) && playbackState.isPlaying
  }

  func playButtonIcon(for block: AudioBlock) -> String {
    isPlaying(block) ? "stop.fill" : "play.fill"
  }

  func playButtonBackgroundColor(for block: AudioBlock) -> Color {
    isActive(block) ? .playolaRed : Color(hex: "#2A2A2A")
  }

  func isPlayButtonEnabled(for block: AudioBlock) -> Bool {
    block.downloadUrl != nil
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

  func scrubberAccessibilityLabel(for block: AudioBlock) -> String {
    "\(clipTitle(for: block)) scrubber"
  }

  func scrubberAccessibilityValue(for block: AudioBlock) -> String {
    "\(elapsedText(for: block)) of \(durationText(for: block))"
  }

  // MARK: - User Actions

  func playButtonTapped(_ block: AudioBlock) async {
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
      }
      guard playbackGeneration == generation else {
        await session.stop()
        return
      }
      playbackSession = session
    } catch {
      guard playbackGeneration == generation else { return }
      playingBlockId = nil
      presentedAlert = .audioPlaybackError(error.localizedDescription)
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

  func viewDisappeared() async {
    playbackGeneration &+= 1
    await teardownCurrentSession()
  }

  // MARK: - Private Helpers

  private func duration(for block: AudioBlock) -> TimeInterval {
    if isActive(block), playbackState.duration > 0 {
      return playbackState.duration
    }
    return TimeInterval(block.durationMS) / 1000
  }

  private func teardownCurrentSession() async {
    let session = playbackSession
    playbackSession = nil
    playbackState = .idle
    playingBlockId = nil
    await session?.stop()
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
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
