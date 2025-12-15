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
  var isSearching: Bool = false
  var presentedAlert: PlayolaAlert?

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Shared(.auth) var auth

  @ObservationIgnored private var debounceTask: Task<Void, Never>?

  var onDismiss: (() -> Void)?
  var onSongSelected: ((AudioBlock) -> Void)?

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
      isSearching = false
      return
    }

    guard let jwt = auth.jwt else {
      presentedAlert = .notAuthenticated
      return
    }

    isSearching = true

    do {
      let results = try await api.searchSongs(jwt, trimmedQuery)
      guard !Task.isCancelled else { return }
      searchResults = results
    } catch {
      guard !Task.isCancelled else { return }
      presentedAlert = .searchError(error.localizedDescription)
    }

    isSearching = false
  }

  func onCancelTapped() {
    debounceTask?.cancel()
    onDismiss?()
  }

  func onSelectSong(_ audioBlock: AudioBlock) {
    onSongSelected?(audioBlock)
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
