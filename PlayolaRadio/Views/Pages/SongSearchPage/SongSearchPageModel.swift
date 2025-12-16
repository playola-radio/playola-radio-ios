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
  var songRequestResults: [SongRequest] = []
  var isSearching: Bool = false
  var presentedAlert: PlayolaAlert?

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Shared(.auth) var auth

  @ObservationIgnored private var debounceTask: Task<Void, Never>?

  var onDismiss: (() -> Void)?
  var onSongSelected: ((AudioBlock) -> Void)?
  var onSongRequested: ((SongRequest) -> Void)?

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
      songRequestResults = []
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
      group.addTask { await self.searchSongRequests(jwt: jwt, query: trimmedQuery) }
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

  private func searchSongRequests(jwt: String, query: String) async {
    do {
      let results = try await api.searchSongRequests(jwt, query)
      guard !Task.isCancelled else { return }
      songRequestResults = results
    } catch {
      // Silently fail for song requests - don't show error to user
      guard !Task.isCancelled else { return }
      songRequestResults = []
    }
  }

  func onCancelTapped() {
    debounceTask?.cancel()
    onDismiss?()
  }

  func onSelectSong(_ audioBlock: AudioBlock) {
    onSongSelected?(audioBlock)
  }

  func onRequestSong(_ songRequest: SongRequest) async {
    guard let jwt = auth.jwt else {
      presentedAlert = .notAuthenticated
      return
    }

    do {
      try await api.requestSong(jwt, songRequest.spotifyId)
      updateSongRequestToRequested(songRequest)
      onSongRequested?(songRequest)
    } catch {
      presentedAlert = .songRequestError(error.localizedDescription)
    }
  }

  private func updateSongRequestToRequested(_ songRequest: SongRequest) {
    guard
      let index = songRequestResults.firstIndex(where: { $0.spotifyId == songRequest.spotifyId })
    else { return }

    let updatedSongRequest = SongRequest.mockWith(
      requestId: UUID().uuidString,
      title: songRequest.title,
      artist: songRequest.artist,
      album: songRequest.album,
      durationMS: songRequest.durationMS,
      popularity: songRequest.popularity,
      releaseDate: songRequest.releaseDate,
      isrc: songRequest.isrc,
      spotifyId: songRequest.spotifyId,
      imageUrl: songRequest.imageUrl,
      createdAt: now
    )
    songRequestResults[index] = updatedSongRequest
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

  static func songRequestError(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Request Failed",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }
}
