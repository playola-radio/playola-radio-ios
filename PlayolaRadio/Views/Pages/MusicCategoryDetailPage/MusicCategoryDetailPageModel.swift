//
//  MusicCategoryDetailPageModel.swift
//  PlayolaRadio
//

import Foundation
import IdentifiedCollections
import PlayolaPlayer
import SwiftUI

@MainActor
@Observable
class MusicCategoryDetailPageModel: ViewModel {

  // MARK: - Initialization

  init(title: String, songs: [AudioBlock]) {
    self.title = title
    self.songs = IdentifiedArray(songs, uniquingIDsWith: { first, _ in first })
    let preview = SongPreviewPlayer()
    self.preview = preview
    super.init()
    preview.onPlaybackError = { [weak self] message in
      self?.presentedAlert = .audioPlaybackError(message)
    }
  }

  // MARK: - Sort

  enum SortMode: String, CaseIterable {
    case title
    case artist
  }

  // MARK: - Properties

  let title: String
  let songs: IdentifiedArrayOf<AudioBlock>
  let preview: SongPreviewPlayer

  var sortMode: SortMode = .title
  var searchText: String = ""
  var presentedAlert: PlayolaAlert?

  var navigationTitle: String { title }
  var sortLabel: String { "SORT BY" }
  var sortModes: [SortMode] { SortMode.allCases }
  var searchPrompt: String { "Search songs" }

  var isSearching: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var clearButtonOpacity: Double { isSearching ? 1 : 0 }

  var displayedSongs: IdentifiedArrayOf<AudioBlock> {
    switch sortMode {
    case .title:
      return IdentifiedArray(
        uniqueElements: filteredSongs.sorted {
          $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        })
    case .artist:
      return IdentifiedArray(
        uniqueElements: filteredSongs.sorted {
          let byArtist = $0.artist.localizedCaseInsensitiveCompare($1.artist)
          if byArtist == .orderedSame {
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
          }
          return byArtist == .orderedAscending
        })
    }
  }

  var availableSectionLetters: [String] {
    Set(displayedSongs.compactMap { sortKey(for: $0).first?.uppercased() }).sorted()
  }

  var showsEmptyState: Bool { displayedSongs.isEmpty }
  var emptyStateOpacity: Double { showsEmptyState ? 1 : 0 }

  var emptyStateMessage: String {
    isSearching ? "No songs match your search." : "No songs in this category yet."
  }

  var emptyStateSystemImage: String {
    isSearching ? "magnifyingglass" : "music.note"
  }

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

  func sortSegmentAccessibilityTraits(for mode: SortMode) -> AccessibilityTraits {
    isSortSelected(mode) ? .isSelected : []
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
    preview.isActive(block)
  }

  func isPlaying(_ block: AudioBlock) -> Bool {
    preview.isPlaying(block)
  }

  func isBuffering(_ block: AudioBlock) -> Bool {
    preview.isBuffering(block)
  }

  func playButtonIcon(for block: AudioBlock) -> String {
    preview.playButtonIcon(for: block)
  }

  func bufferingSpinnerOpacity(for block: AudioBlock) -> Double {
    preview.bufferingSpinnerOpacity(for: block)
  }

  func playIconOpacity(for block: AudioBlock) -> Double {
    preview.playIconOpacity(for: block)
  }

  func playButtonBackgroundColor(for block: AudioBlock) -> Color {
    isActive(block) ? .playolaRed : Color(hex: "#444444")
  }

  func isPlayButtonEnabled(for block: AudioBlock) -> Bool {
    preview.isPlayButtonEnabled(for: block)
  }

  func elapsedText(for block: AudioBlock) -> String {
    preview.elapsedText(for: block)
  }

  func durationText(for block: AudioBlock) -> String {
    preview.durationText(for: block)
  }

  func progress(for block: AudioBlock) -> Double {
    preview.progress(for: block)
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

  // During buffering isActive is already true and the icon shows pause.fill; keep the label
  // action-oriented ("Pause") to match the visible control and the stop-on-tap behavior, rather
  // than announcing passive "Loading" status on an actionable button.
  func playButtonAccessibilityLabel(for block: AudioBlock) -> String {
    isActive(block) ? "Pause \(songTitle(for: block))" : "Play \(songTitle(for: block))"
  }

  // The scrubber only exists (height/opacity > 0) for the active song; hide the collapsed,
  // zero-height copy under every inactive row from assistive tech.
  func scrubberAccessibilityHidden(for block: AudioBlock) -> Bool {
    !isActive(block)
  }

  var emptyStateAccessibilityHidden: Bool {
    !showsEmptyState
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

  func clearSearchTapped() {
    searchText = ""
  }

  func playButtonTapped(_ block: AudioBlock) async {
    await preview.toggle(block)
  }

  func scrubberDragged(_ block: AudioBlock, locationX: CGFloat, trackWidth: CGFloat) async {
    await preview.scrubberDragged(block, locationX: locationX, trackWidth: trackWidth)
  }

  func scrubberAdjusted(_ block: AudioBlock, increment: Bool) async {
    await preview.scrubberAdjusted(block, increment: increment)
  }

  func viewDisappeared() async {
    await preview.stop()
  }

  // MARK: - Private Helpers

  private var filteredSongs: IdentifiedArrayOf<AudioBlock> {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return songs }
    return IdentifiedArray(
      uniqueElements: songs.filter {
        $0.title.localizedCaseInsensitiveContains(query)
          || $0.artist.localizedCaseInsensitiveContains(query)
      })
  }

  private func sortKey(for block: AudioBlock) -> String {
    switch sortMode {
    case .title: return block.title
    case .artist: return block.artist
    }
  }
}
