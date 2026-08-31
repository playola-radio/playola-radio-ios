//
//  MusicCategoryDetailPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import PlayolaPlayer
import SwiftUI

@MainActor
@Observable
class MusicCategoryDetailPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer

  // MARK: - Initialization

  init(title: String, songs: [AudioBlock]) {
    self.title = title
    self.songs = songs
    super.init()
  }

  // MARK: - Sort

  enum SortMode: String, CaseIterable {
    case title
    case artist
  }

  // MARK: - Properties

  let title: String
  let songs: [AudioBlock]

  var sortMode: SortMode = .title
  var presentedAlert: PlayolaAlert?

  private var playingBlockId: String?
  private var playbackState: PlaybackState = .idle
  private var playbackSession: PlaybackSession?
  private var playbackGeneration = 0
  private var observedPlaying = false
  private let scrubberStep: TimeInterval = 5

  var navigationTitle: String { title }
  var sortLabel: String { "SORT BY" }
  var sortModes: [SortMode] { SortMode.allCases }

  var displayedSongs: [AudioBlock] {
    switch sortMode {
    case .title:
      return songs.sorted {
        $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
      }
    case .artist:
      return songs.sorted {
        let byArtist = $0.artist.localizedCaseInsensitiveCompare($1.artist)
        if byArtist == .orderedSame {
          return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        return byArtist == .orderedAscending
      }
    }
  }

  var availableSectionLetters: [String] {
    Set(displayedSongs.compactMap { sortKey(for: $0).first?.uppercased() }).sorted()
  }

  var emptyStateMessage: String { "No songs in this category yet." }
  var showsEmptyState: Bool { songs.isEmpty }
  var emptyStateOpacity: Double { showsEmptyState ? 1 : 0 }

  // MARK: - View Helpers

  func songTitle(for block: AudioBlock) -> String {
    block.title
  }

  func songSubtitle(for block: AudioBlock) -> String {
    block.artist
  }

  func sortSegmentTitle(for mode: SortMode) -> String {
    switch mode {
    case .title: return "Title"
    case .artist: return "Artist"
    }
  }

  func isSortSelected(_ mode: SortMode) -> Bool {
    sortMode == mode
  }

  func sortSegmentBackgroundColor(for mode: SortMode) -> Color {
    isSortSelected(mode) ? Color(hex: "#444444") : .clear
  }

  func sortSegmentTextColor(for mode: SortMode) -> Color {
    isSortSelected(mode) ? .white : .playolaGray
  }

  func firstSongId(forLetter letter: String) -> String? {
    displayedSongs.first { sortKey(for: $0).uppercased().hasPrefix(letter.uppercased()) }?.id
  }

  // The section-index letters are derived from displayedSongs, so a tapped letter always resolves
  // to a song. Returning a non-optional target keeps the view free of control flow — it can scroll
  // unconditionally, and the empty-string fallback is a harmless no-op if no row matches.
  func scrollTargetId(forLetter letter: String) -> String {
    firstSongId(forLetter: letter) ?? ""
  }

  func isActive(_ block: AudioBlock) -> Bool {
    playingBlockId == block.id
  }

  func isPlaying(_ block: AudioBlock) -> Bool {
    isActive(block) && playbackState.isPlaying
  }

  func playButtonIcon(for block: AudioBlock) -> String {
    // Mirror the tap toggle, which stops any active song (including during startup/buffering,
    // when isActive is true but isPlaying is briefly false). Deriving from isActive keeps the
    // icon and the button's behavior consistent.
    isActive(block) ? "pause.fill" : "play.fill"
  }

  func playButtonBackgroundColor(for block: AudioBlock) -> Color {
    isActive(block) ? .playolaRed : Color(hex: "#444444")
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

  // The active song reveals its scrubber below the title row; inactive songs show only the
  // trailing duration. Both are driven off `isActive` so the view stays free of control flow.
  func trailingDurationOpacity(for block: AudioBlock) -> Double {
    isActive(block) ? 0 : 1
  }

  func scrubberOpacity(for block: AudioBlock) -> Double {
    isActive(block) ? 1 : 0
  }

  func scrubberAreaHeight(for block: AudioBlock) -> CGFloat {
    isActive(block) ? 26 : 0
  }

  func scrubberAccessibilityLabel(for block: AudioBlock) -> String {
    "\(songTitle(for: block)) scrubber"
  }

  func scrubberAccessibilityValue(for block: AudioBlock) -> String {
    "\(elapsedText(for: block)) of \(durationText(for: block))"
  }

  // MARK: - User Actions

  func sortModeTapped(_ mode: SortMode) {
    sortMode = mode
  }

  func playButtonTapped(_ block: AudioBlock) async {
    guard let downloadUrl = block.downloadUrl else { return }

    let wasActive = isActive(block)

    playbackGeneration &+= 1
    let generation = playbackGeneration

    await teardownCurrentSession()
    guard playbackGeneration == generation else { return }
    if wasActive { return }

    playingBlockId = block.id
    observedPlaying = false

    do {
      let session = try await audioPlayer.startPlayback(downloadUrl) { [weak self] state in
        guard let self, self.playbackGeneration == generation else { return }
        self.playbackState = state
        if state.isPlaying {
          self.observedPlaying = true
        }
        // Complete only on a stopped, ended state. Requiring !isPlaying avoids cutting off a
        // still-playing song; `isComplete` is the client's end signal (explicit didFinish, or
        // near-end progress) so a mid-song buffering stall — which also reports not-playing —
        // is not treated as completion.
        guard self.observedPlaying, !state.isPlaying, state.isComplete else { return }
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

  private func sortKey(for block: AudioBlock) -> String {
    switch sortMode {
    case .title: return block.title
    case .artist: return block.artist
    }
  }

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
    observedPlaying = false
    await session?.stop()
  }

  // Called only for a stopped, ended state, so the client's per-session player has already
  // halted and its polling loop has self-completed. Dropping the session reference is enough;
  // no explicit async stop is needed.
  private func handlePlaybackCompletion() {
    playbackSession = nil
    playbackState = .idle
    playingBlockId = nil
    observedPlaying = false
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
