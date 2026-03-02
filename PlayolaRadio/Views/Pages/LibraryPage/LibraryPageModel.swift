//
//  LibraryPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Sharing
import SwiftUI

@MainActor
@Observable
class LibraryPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Initialization

  let stationId: String

  init(stationId: String) {
    self.stationId = stationId
    super.init()
  }

  // MARK: - Properties

  let navigationTitle = "Library"

  var librarySongs: [LibrarySong] = []
  var libraryRequests: [StationLibraryRequest] = []
  var isLoading = false
  var searchText = ""
  var presentedAlert: PlayolaAlert?
  var processingRemovalSongIds: Set<String> = []
  var songSearchPageModel: SongSearchPageModel?

  var filteredSongs: [LibrarySong] {
    guard !searchText.isEmpty else { return librarySongs }
    let lowercasedSearch = searchText.lowercased()
    return librarySongs.filter {
      $0.title.lowercased().contains(lowercasedSearch)
        || $0.artist.lowercased().contains(lowercasedSearch)
    }
  }

  var songsByArtist: [(artist: String, songs: [LibrarySong])] {
    let grouped = Dictionary(grouping: filteredSongs) { $0.artist }
    return
      grouped
      .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
      .map { (artist: $0.key, songs: $0.value.sorted { $0.title < $1.title }) }
  }

  var availableSectionLetters: [String] {
    let letters = Set(songsByArtist.compactMap { $0.artist.first?.uppercased() })
    return letters.sorted()
  }

  var activeRequests: [StationLibraryRequest] {
    libraryRequests.filter { $0.status != .dismissed }
  }

  var emptyStateMessage: String {
    "No songs in library"
  }

  var songsSectionHeader: String {
    "SONGS (\(filteredSongs.count))"
  }

  let requestsSectionHeader = "PENDING REQUESTS"
  let removeButtonText = "REMOVE"
  let dismissButtonText = "DISMISS"
  let cancelButtonText = "CANCEL"
  let pendingRemovalText = "Pending Removal"
  let waitingStatusText = "Waiting"
  let searchPrompt = "Search songs"

  // MARK: - User Actions

  func viewAppeared() async {
    await loadData()
  }

  func refreshPulledDown() async {
    await loadData()
  }

  func removeSongButtonTapped(_ song: LibrarySong) async {
    guard let jwt = auth.jwt else { return }

    processingRemovalSongIds.insert(song.id)
    defer { processingRemovalSongIds.remove(song.id) }

    do {
      let request = try await api.createRemoveLibraryRequest(jwt, stationId, song.id)
      libraryRequests.insert(request, at: 0)
    } catch {
      presentedAlert = .libraryError(error.localizedDescription)
    }
  }

  func addSongButtonTapped() {
    let model = SongSearchPageModel(searchMode: .seedsOnly, stationId: stationId)
    model.onDismiss = { [weak self] in
      self?.mainContainerNavigationCoordinator.presentedSheet = nil
    }
    model.onAddedToLibrary = { [weak self] request in
      self?.libraryRequests.insert(request, at: 0)
      self?.mainContainerNavigationCoordinator.presentedSheet = nil
    }
    songSearchPageModel = model
    mainContainerNavigationCoordinator.presentedSheet = .songSearchPage(model)
  }

  func dismissRequestButtonTapped(_ request: StationLibraryRequest) async {
    guard let jwt = auth.jwt else { return }

    do {
      let updatedRequest = try await api.dismissStationLibraryRequest(jwt, stationId, request.id)
      if let index = libraryRequests.firstIndex(where: { $0.id == request.id }) {
        libraryRequests[index] = updatedRequest
      }
    } catch {
      presentedAlert = .libraryError(error.localizedDescription)
    }
  }

  func cancelRequestButtonTapped(_ request: StationLibraryRequest) async {
    guard let jwt = auth.jwt else { return }

    do {
      try await api.cancelStationLibraryRequest(jwt, stationId, request.id)
      libraryRequests.removeAll { $0.id == request.id }
    } catch {
      presentedAlert = .libraryError(error.localizedDescription)
    }
  }

  // MARK: - View Helpers

  func hasPendingRequest(for song: LibrarySong) -> Bool {
    libraryRequests.contains { $0.audioBlockId == song.id && $0.status == .pending }
  }

  func isProcessingRemoval(for song: LibrarySong) -> Bool {
    processingRemovalSongIds.contains(song.id)
  }

  func pendingRequest(for song: LibrarySong) -> StationLibraryRequest? {
    libraryRequests.first { $0.audioBlockId == song.id && $0.status == .pending }
  }

  func requestTypeLabel(for request: StationLibraryRequest) -> String {
    request.type == .add ? "Add" : "Remove"
  }

  func requestTypeColor(for request: StationLibraryRequest) -> Color {
    request.type == .add ? .success : .warning
  }

  func requestStatusLabel(for request: StationLibraryRequest) -> String {
    request.status.rawValue.capitalized
  }

  func canDismissRequest(_ request: StationLibraryRequest) -> Bool {
    request.status == .completed
  }

  func canCancelRequest(_ request: StationLibraryRequest) -> Bool {
    request.status == .pending
  }

  func firstArtist(forLetter letter: String) -> String? {
    songsByArtist.first { $0.artist.uppercased().hasPrefix(letter.uppercased()) }?.artist
  }

  // MARK: - Private Helpers

  private func loadData() async {
    guard let jwt = auth.jwt else { return }

    isLoading = true

    do {
      async let songsTask = api.getStationLibrary(jwt, stationId)
      async let requestsTask = api.getStationLibraryRequests(jwt, stationId, nil)

      let (songs, requests) = try await (songsTask, requestsTask)
      librarySongs = songs
      libraryRequests = requests
    } catch {
      presentedAlert = .libraryError(error.localizedDescription)
    }

    isLoading = false
  }
}

// MARK: - Alerts

extension PlayolaAlert {
  static func libraryError(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }
}
