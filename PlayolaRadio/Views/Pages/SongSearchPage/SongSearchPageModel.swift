//
//  SongSearchPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import Dependencies
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class SongSearchPageModel: ViewModel {
  var searchText: String = "" {
    didSet {
      onSearchTextChanged()
    }
  }
  var searchResults: [AudioBlock] = []
  var songSeedResults: [SongSeed] = []
  var isSearching: Bool = false
  var presentedAlert: PlayolaAlert?

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Shared(.auth) var auth

  @ObservationIgnored private var debounceTask: Task<Void, Never>?

  var onDismiss: (() -> Void)?
  var onSongSelected: ((AudioBlock) -> Void)?
  var onSongSeedRequested: ((SongSeed) -> Void)?

  override init() {
    super.init()
  }

  private func onSearchTextChanged() {
    debounceTask?.cancel()

    debounceTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await clock.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await performSearch(searchText)
      } catch {
        // Task was cancelled
      }
    }
  }

  private func performSearch(_ query: String) async {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedQuery.isEmpty else {
      searchResults = []
      songSeedResults = []
      isSearching = false
      return
    }

    guard let jwt = auth.jwt else {
      presentedAlert = .notAuthenticated
      return
    }

    isSearching = true

    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.searchSongs(jwt: jwt, query: trimmedQuery) }
      group.addTask { await self.searchSongSeeds(jwt: jwt, query: trimmedQuery) }
    }

    isSearching = false
  }

  private func searchSongs(jwt: String, query: String) async {
    do {
      let results = try await api.searchSongs(jwt, query)
      guard !Task.isCancelled else { return }
      searchResults = results
    } catch {
      guard !Task.isCancelled else { return }
      presentedAlert = .searchError(error.localizedDescription)
    }
  }

  private func searchSongSeeds(jwt: String, query: String) async {
    do {
      let results = try await api.searchSongSeeds(jwt, query)
      guard !Task.isCancelled else { return }
      songSeedResults = results
    } catch {
      // Silently fail for song seeds - don't show error to user
      guard !Task.isCancelled else { return }
      songSeedResults = []
    }
  }

  func onCancelTapped() {
    debounceTask?.cancel()
    onDismiss?()
  }

  func onSelectSong(_ audioBlock: AudioBlock) {
    onSongSelected?(audioBlock)
  }

  func onRequestSongSeed(_ songSeed: SongSeed) {
    onSongSeedRequested?(songSeed)
  }
}

extension PlayolaAlert {
  static var notAuthenticated: PlayolaAlert {
    PlayolaAlert(
      title: "Not Signed In",
      message: "Please sign in to search for songs.",
      dismissButton: .cancel(Text("OK"))
    )
  }

  static func searchError(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Search Error",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }
}
